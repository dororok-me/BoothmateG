//
//  FishAudioTTS.swift
//  BoothmateG
//
//  Version: 1.0.0
//  Fish Audio TTS(텍스트→음성) 모듈.
//  번역 문장 텍스트를 Fish Audio API로 보내 PCM16(24kHz·모노)을 돌려받는다.
//  - AudioBroadcaster와 동일한 24kHz PCM16 형식으로 받아 기존 업로드 파이프라인에 그대로 태움.
//  - 엔드포인트: POST https://api.fish.audio/v1/tts
//  - 인증: Authorization: Bearer <API키>, 헤더 model: s1 (또는 s2-pro)
//  - 본문(JSON): { text, reference_id?, format:"pcm", sample_rate:24000 }
//  - 응답: PCM16 raw 바이트
//

import Foundation

final class FishAudioTTS {

    struct Config {
        var apiKey: String
        var referenceId: String   // 빈 값이면 기본 음성
        var model: String         // "s1" / "s2-pro"
        var sampleRate: Int       // 24000 (AudioBroadcaster와 동일)
    }

    // 텍스트 → PCM16(24kHz, 모노) 변환. 실패 시 nil.
    // completion은 백그라운드 스레드에서 호출될 수 있음.
    static func synthesize(text: String, config: Config, completion: @escaping (Data?) -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !config.apiKey.isEmpty else { completion(nil); return }
        guard let url = URL(string: "https://api.fish.audio/v1/tts") else { completion(nil); return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(config.model.isEmpty ? "s1" : config.model, forHTTPHeaderField: "model")
        req.timeoutInterval = 20

        var body: [String: Any] = [
            "text": trimmed,
            "format": "pcm",
            "sample_rate": config.sampleRate
        ]
        if !config.referenceId.isEmpty {
            body["reference_id"] = config.referenceId
        }
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { completion(nil); return }
        req.httpBody = data

        URLSession.shared.dataTask(with: req) { respData, resp, err in
            if let err = err {
                print("[BMG][Fish] 요청 실패: \(err.localizedDescription)")
                completion(nil); return
            }
            guard let http = resp as? HTTPURLResponse else { completion(nil); return }
            guard (200..<300).contains(http.statusCode), let pcm = respData, !pcm.isEmpty else {
                let msg = respData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                print("[BMG][Fish] 응답 오류 \(http.statusCode): \(msg.prefix(200))")
                completion(nil); return
            }
            completion(pcm)
        }.resume()
    }
}
