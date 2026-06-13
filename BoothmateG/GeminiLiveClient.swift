//
//  GeminiLiveClient.swift
//  BoothmateG
//
//  Version: 1.0.0
//  Changelog:
//    1.0.0 - 최초 작성. Gemini 3.5 Live Translate WebSocket 클라이언트
//            웹 버전에서 검증된 setup 키 계층 그대로 사용
//

import Foundation

// Gemini Live Translate 서버와 WebSocket으로 통신하는 클라이언트.
// 마이크 PCM을 보내고, 원문/번역 자막 텍스트를 받아서 콜백으로 전달함.
final class GeminiLiveClient: NSObject {

    // 콜백들 - ContentView에서 이걸 받아 화면에 표시
    var onInputTranscript: ((String) -> Void)?   // 원문 자막
    var onOutputTranscript: ((String) -> Void)?  // 번역 자막
    var onError: ((String) -> Void)?             // 오류 메시지
    var onConnected: (() -> Void)?               // 연결 완료
    var onClosed: (() -> Void)?                  // 연결 종료
    var onTurnComplete: (() -> Void)?            // 한 턴(문장) 완료

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession!

    private let model = "gemini-3.5-live-translate-preview"

    // 연결 시작
    func connect(apiKey: String, sourceLang: String, targetLang: String) {
        guard !apiKey.isEmpty else {
            onError?("API 키가 비어있습니다")
            return
        }

        // Gemini Live API WebSocket 엔드포인트
        let urlString = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            onError?("URL 생성 실패")
            return
        }

        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        // 수신 루프 시작
        receiveLoop()

        // setup 메시지 전송 (웹에서 검증된 키 계층 그대로)
        sendSetup(sourceLang: sourceLang, targetLang: targetLang)
    }

    // 연결 종료
    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        onClosed?()
    }

    // 마이크 PCM 데이터를 서버로 전송
    func sendAudio(_ data: Data) {
        guard let webSocket = webSocket else { return }
        let base64 = data.base64EncodedString()

        // realtimeInput.audio 형식 (웹 버전과 동일)
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
            if let error = error {
                self?.onError?("오디오 전송 실패: \(error.localizedDescription)")
            }
        }
    }

    // ───────────────────────────────────────────────
        // 내부: setup 메시지 전송 (v1.4.0)
        //   1.3.0 - 구조는 맞음. "invalid argument" 발생
        //   1.4.0 - 언어 코드를 ISO 639-1 짧은 형식으로 변환 (en-US → en),
        //           echoTargetLanguage 일단 제거하여 최소 필드로 테스트
        // ───────────────────────────────────────────────
        private func sendSetup(sourceLang: String, targetLang: String) {
            // "en-US" → "en", "ko-KR" → "ko" 처럼 짧은 코드만 추출
            let shortTarget = String(targetLang.prefix { $0 != "-" })

            let setup: [String: Any] = [
                "setup": [
                    "model": "models/\(model)",
                    "generationConfig": [
                        "responseModalities": ["AUDIO"],
                        "translationConfig": [
                            "targetLanguageCode": shortTarget
                        ]
                    ],
                    "inputAudioTranscription": [:],
                    "outputAudioTranscription": [:]
                ]
            ]

            print("[BMG] setup 전송: \(setup)")  // 디버깅용

            guard let json = try? JSONSerialization.data(withJSONObject: setup),
                  let text = String(data: json, encoding: .utf8) else {
                onError?("setup 메시지 생성 실패")
                return
            }

            webSocket?.send(.string(text)) { [weak self] error in
                if let error = error {
                    self?.onError?("setup 전송 실패: \(error.localizedDescription)")
                }
            }
        }
    
    // ───────────────────────────────────────────────
    // 내부: 메시지 수신 루프
    // ───────────────────────────────────────────────
    private func receiveLoop() {
            webSocket?.receive { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .failure(let error):
                    // 연결이 이미 종료된 경우 (정상 종료 후 수신 시도)는 오류로 보고하지 않음
                    let nsError = error as NSError
                    let isClosed = self.webSocket == nil
                                  || nsError.code == 57   // Socket is not connected
                                  || nsError.code == 53   // Software caused connection abort
                                  || nsError.code == 54   // Connection reset by peer
                                  || nsError.code == NSURLErrorCancelled
                    if !isClosed {
                        self.onError?("수신 오류: \(error.localizedDescription)")
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

                    // 다음 메시지 수신을 위해 재귀 호출
                    self.receiveLoop()
                }
            }
        }

    // 서버에서 받은 JSON 메시지를 파싱
        private func handleMessage(text: String) {
            print("[BMG] 서버 메시지 수신: \(text.prefix(800))")

            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        // setupComplete 신호
        if json["setupComplete"] != nil {
            onConnected?()
            return
        }

        // serverContent 안에 transcript들이 들어있음
        guard let serverContent = json["serverContent"] as? [String: Any] else { return }

        // 원문 자막
        if let inputT = serverContent["inputTranscription"] as? [String: Any],
           let textVal = inputT["text"] as? String, !textVal.isEmpty {
            onInputTranscript?(textVal)
        }

            // 번역 자막
                    if let outputT = serverContent["outputTranscription"] as? [String: Any],
                       let textVal = outputT["text"] as? String, !textVal.isEmpty {
                        onOutputTranscript?(textVal)
                    }

            // turnComplete 신호 (한 turn 완료)
                    if serverContent["turnComplete"] as? Bool == true {
                        print("[BMG] ✅ turnComplete 수신!")
                        onTurnComplete?()
                    }

                    // generationComplete도 있을 수 있음
                    if serverContent["generationComplete"] as? Bool == true {
                        print("[BMG] ℹ️ generationComplete 수신 (turn 아님)")
                    }

                    // interrupted (말 끊김)
                    if serverContent["interrupted"] as? Bool == true {
                        print("[BMG] ⚠️ interrupted")
                    }
                }
}

// URLSession 델리게이트 - 연결 이벤트 처리
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
            onClosed?()
        }
}
