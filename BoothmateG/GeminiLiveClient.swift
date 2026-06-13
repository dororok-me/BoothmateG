//
//  GeminiLiveClient.swift
//  BoothmateG
//
//  Version: 1.1.0
//  Changelog:
//    1.0.0 - 최초 작성. Gemini 3.5 Live Translate WebSocket 클라이언트
//    1.1.0 - 양방향 듀얼 세션 지원용:
//            · setup에 echoTargetLanguage: false 추가 (입력이 타겟 언어면 출력 침묵)
//            · 입력 자막의 감지 언어코드(languageCode)를 onInputLanguage로 전달
//

import Foundation

// Gemini Live Translate 서버와 WebSocket으로 통신하는 클라이언트.
final class GeminiLiveClient: NSObject {

    // 콜백들
    var onInputTranscript: ((String) -> Void)?    // 원문 자막
    var onInputLanguage: ((String) -> Void)?      // 감지된 입력 언어코드 (예: "ko","en")
    var onOutputTranscript: ((String) -> Void)?   // 번역 자막
    var onError: ((String) -> Void)?
    var onConnected: (() -> Void)?
    var onClosed: (() -> Void)?
    var onTurnComplete: (() -> Void)?

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession!

    private let model = "gemini-3.5-live-translate-preview"

    func connect(apiKey: String, sourceLang: String, targetLang: String) {
        guard !apiKey.isEmpty else {
            onError?("API 키가 비어있습니다")
            return
        }

        let urlString = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            onError?("URL 생성 실패")
            return
        }

        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        webSocket = session.webSocketTask(with: url)
        webSocket?.resume()

        receiveLoop()
        sendSetup(sourceLang: sourceLang, targetLang: targetLang)
    }

    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        onClosed?()
    }

    func sendAudio(_ data: Data) {
        guard let webSocket = webSocket else { return }
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
            if let error = error {
                self?.onError?("오디오 전송 실패: \(error.localizedDescription)")
            }
        }
    }

    // ───────────────────────────────────────────────
    // setup 메시지 (v1.1.0: echoTargetLanguage: false)
    //   - targetLanguageCode: 짧은 코드(en-US → en)
    //   - echoTargetLanguage:false → 입력이 이미 타겟 언어면 출력 침묵
    // ───────────────────────────────────────────────
    private func sendSetup(sourceLang: String, targetLang: String) {
        let shortTarget = String(targetLang.prefix { $0 != "-" })

        let setup: [String: Any] = [
            "setup": [
                "model": "models/\(model)",
                "generationConfig": [
                    "responseModalities": ["AUDIO"],
                    "translationConfig": [
                        "targetLanguageCode": shortTarget,
                        "echoTargetLanguage": false
                    ]
                ],
                "inputAudioTranscription": [:],
                "outputAudioTranscription": [:]
            ]
        ]

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
    // 수신 루프
    // ───────────────────────────────────────────────
    private func receiveLoop() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                let nsError = error as NSError
                let isClosed = self.webSocket == nil
                              || nsError.code == 57
                              || nsError.code == 53
                              || nsError.code == 54
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
                self.receiveLoop()
            }
        }
    }

    private func handleMessage(text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if json["setupComplete"] != nil {
            onConnected?()
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

        if serverContent["turnComplete"] as? Bool == true {
            onTurnComplete?()
        }
    }
}

// URLSession 델리게이트
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
