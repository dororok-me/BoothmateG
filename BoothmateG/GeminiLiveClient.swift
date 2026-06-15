//
//  GeminiLiveClient.swift
//  BoothmateG
//
//  Version: 1.4.0
//  Changelog:
//    1.0.0 - 최초 작성. Gemini 3.5 Live Translate WebSocket 클라이언트
//    1.1.0 - echoTargetLanguage:false + 입력 감지 언어(onInputLanguage)
//    1.2.0 - 번역 음성 지원: 언어코드 그대로 전송(BCP-47),
//            modelTurn 오디오(inlineData) 파싱 → onAudio 콜백
//    1.3.0 - 자동 재연결: 세션 끊김 시 사용자가 정지하지 않은 한 다시 연결
//    1.4.0 - 세션 수명 관리(잦은 1008 종료 해결):
//            · contextWindowCompression(슬라이딩 윈도우) → 긴 세션 유지
//            · sessionResumption → 끊겨도 핸들로 같은 세션 이어가기(맥락 유지)
//            · goAway 메시지 처리 → 서버가 끊기 전에 미리 새 연결로 교체(planned)
//            · 계획된 교체(goAway)는 실패 카운터에 포함하지 않음
//

import Foundation

final class GeminiLiveClient: NSObject {

    // 콜백들
    var onInputTranscript: ((String) -> Void)?
    var onInputLanguage: ((String) -> Void)?
    var onOutputTranscript: ((String) -> Void)?
    var onAudio: ((Data) -> Void)?              // 번역 음성 PCM (24kHz, 16-bit, mono)
    var onError: ((String) -> Void)?
    var onConnected: (() -> Void)?
    var onClosed: (() -> Void)?
    var onTurnComplete: (() -> Void)?

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession!

    private let model = "gemini-3.5-live-translate-preview"

    // ── 재연결 상태 ──
    private var connApiKey = ""
    private var connSourceLang = ""
    private var connTargetLang = ""
    private var isActive = false            // 연결 유지 의도(사용자가 stop하면 false)
    private var isReconnecting = false
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 8

    // ── 세션 수명 관리 (v1.4.0) ──
    private var resumeHandle: String?       // sessionResumptionUpdate.newHandle 저장

    func connect(apiKey: String, sourceLang: String, targetLang: String) {
        guard !apiKey.isEmpty else {
            onError?("API 키가 비어있습니다")
            return
        }
        // 재연결용 파라미터 저장
        connApiKey = apiKey
        connSourceLang = sourceLang
        connTargetLang = targetLang
        isActive = true
        isReconnecting = false
        reconnectAttempts = 0
        resumeHandle = nil                  // 새 시작 → 이전 세션 이어받지 않음
        openSocket()
    }

    // 실제 소켓 열기 (connect와 재연결이 공용으로 사용)
    private func openSocket() {
        let urlString = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(connApiKey)"
        guard let url = URL(string: urlString) else {
            onError?("URL 생성 실패")
            return
        }

        if session == nil {
            let config = URLSessionConfiguration.default
            session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        }
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        receiveLoop()
        sendSetup(sourceLang: connSourceLang, targetLang: connTargetLang)
    }

    func disconnect() {
        isActive = false          // 사용자가 명시적으로 정지 → 재연결 안 함
        isReconnecting = false
        reconnectAttempts = 0
        resumeHandle = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        onClosed?()
    }

    // 재연결 예약. planned=true → goAway로 인한 계획된 교체(카운터 증가 안 함, 거의 즉시)
    private func scheduleReconnect(planned: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isActive, !self.isReconnecting else { return }
            self.isReconnecting = true
            self.webSocket?.cancel(with: .goingAway, reason: nil)
            self.webSocket = nil

            let delay: Double
            if planned {
                delay = 0.1
                print("[BMG] 세션 교체(goAway), \(delay)초 후 (handle 있음=\(self.resumeHandle != nil))")
            } else {
                self.reconnectAttempts += 1
                if self.reconnectAttempts > self.maxReconnectAttempts {
                    print("[BMG] 재연결 \(self.maxReconnectAttempts)회 실패 → 포기")
                    self.isActive = false
                    self.isReconnecting = false
                    self.onError?("연결이 계속 끊깁니다. 네트워크를 확인하고 다시 시작하세요.")
                    self.onClosed?()
                    return
                }
                delay = min(Double(self.reconnectAttempts) * 0.5, 5.0)
                print("[BMG] 재연결 시도 #\(self.reconnectAttempts), \(delay)초 후 (handle 있음=\(self.resumeHandle != nil))")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard self.isActive else { return }
                self.isReconnecting = false
                self.openSocket()
            }
        }
    }

    func sendAudio(_ data: Data) {
        // 소켓이 살아있을 때만 전송 (재연결 중엔 조용히 버림)
        guard let webSocket = webSocket, webSocket.state == .running else { return }
        let base64 = data.base64EncodedString()

        let payload: [String: Any] = [
            "realtimeInput": [
                "audio": [
                    "mimeType": "audio/pcm;rate=16000",
                    "data": base64
                ]
            ]
        ]

        guard let json = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: json, encoding: .utf8) else { return }

        webSocket.send(.string(text)) { [weak self] error in
            guard let self = self, let error = error else { return }
            print("[BMG] 오디오 전송 실패: \(error.localizedDescription)")
            if self.isActive { self.scheduleReconnect(planned: false) }
        }
    }

    // setup: 언어코드(BCP-47) + 긴 세션(압축) + 세션 재개(핸들)
    private func sendSetup(sourceLang: String, targetLang: String) {
        var setupInner: [String: Any] = [
            "model": "models/\(model)",
            "generationConfig": [
                "responseModalities": ["AUDIO"],
                "translationConfig": [
                    "targetLanguageCode": targetLang,
                    "echoTargetLanguage": false
                ]
            ],
            "inputAudioTranscription": [:],
            "outputAudioTranscription": [:],
            // 긴 세션 유지: 컨텍스트 한도로 인한 갑작스런 종료 방지(슬라이딩 윈도우)
            "contextWindowCompression": ["slidingWindow": [:]]
        ]
        // 세션 재개: 핸들이 있으면 같은 세션 이어가기, 없으면 빈 값으로 기능 활성화
        if let handle = resumeHandle, !handle.isEmpty {
            setupInner["sessionResumption"] = ["handle": handle]
        } else {
            setupInner["sessionResumption"] = [String: Any]()
        }

        let setup: [String: Any] = ["setup": setupInner]

        guard let json = try? JSONSerialization.data(withJSONObject: setup),
              let text = String(data: json, encoding: .utf8) else {
            onError?("setup 메시지 생성 실패")
            return
        }

        webSocket?.send(.string(text)) { [weak self] error in
            guard let self = self, let error = error else { return }
            print("[BMG] setup 전송 실패: \(error.localizedDescription)")
            if self.isActive { self.scheduleReconnect(planned: false) }
        }
    }

    private func receiveLoop() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                if self.isActive {
                    print("[BMG] 수신 끊김 → 재연결: \(error.localizedDescription)")
                    self.scheduleReconnect(planned: false)
                } else {
                    print("[BMG] 수신 루프 종료 (정상): \(error.localizedDescription)")
                }
                return

            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text: text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text: text)
                    }
                @unknown default: break
                }
                self.receiveLoop()
            }
        }
    }

    private func handleMessage(text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if json["setupComplete"] != nil {
            // 연결 성공 → 재연결 카운터 리셋
            DispatchQueue.main.async { [weak self] in
                self?.reconnectAttempts = 0
                self?.isReconnecting = false
            }
            onConnected?()
            return
        }

        // 세션 재개 핸들 저장 (다음 재연결 때 같은 세션 이어가기)
        if let sru = json["sessionResumptionUpdate"] as? [String: Any] {
            let resumable = (sru["resumable"] as? Bool) ?? false
            if resumable, let handle = sru["newHandle"] as? String, !handle.isEmpty {
                DispatchQueue.main.async { [weak self] in self?.resumeHandle = handle }
            }
            return
        }

        // 곧 끊김 예고 → 미리 새 연결로 교체 (1008 강제종료 방지)
        if let goAway = json["goAway"] {
            let timeLeft = (goAway as? [String: Any])?["timeLeft"] as? String ?? "?"
            print("[BMG] goAway 수신 (남은 시간 \(timeLeft)) → 세션 교체")
            scheduleReconnect(planned: true)
            return
        }

        guard let serverContent = json["serverContent"] as? [String: Any] else { return }

        // 원문 자막 + 감지 언어
        if let inputT = serverContent["inputTranscription"] as? [String: Any] {
            if let code = inputT["languageCode"] as? String, !code.isEmpty {
                onInputLanguage?(code)
            }
            if let textVal = inputT["text"] as? String, !textVal.isEmpty {
                onInputTranscript?(textVal)
            }
        }

        // 번역 자막
        if let outputT = serverContent["outputTranscription"] as? [String: Any],
           let textVal = outputT["text"] as? String, !textVal.isEmpty {
            onOutputTranscript?(textVal)
        }

        // 번역 음성 (modelTurn.parts[].inlineData.data, base64 PCM)
        if let modelTurn = serverContent["modelTurn"] as? [String: Any],
           let parts = modelTurn["parts"] as? [[String: Any]] {
            for part in parts {
                if let inline = part["inlineData"] as? [String: Any],
                   let b64 = inline["data"] as? String,
                   let audio = Data(base64Encoded: b64) {
                    onAudio?(audio)
                }
            }
        }

        if serverContent["turnComplete"] as? Bool == true {
            onTurnComplete?()
        }
    }
}

extension GeminiLiveClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {
        print("[BMG] WebSocket 연결됨")
    }

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        let reasonText = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "(없음)"
        print("[BMG] WebSocket 종료됨, code=\(closeCode.rawValue), reason=\(reasonText)")
        if isActive {
            scheduleReconnect(planned: false)
        }
    }
}
