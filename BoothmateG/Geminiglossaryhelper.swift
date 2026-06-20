//
//  GeminiGlossaryHelper.swift
//  BoothmateG
//
//  Version: 1.4.0
//  Changelog:
//    1.4.0 - 어설픈 생성 방어: (1) thinkingBudget=0으로 추론(THOUGHT) 출력 차단,
//            (2) 프롬프트 더 엄격(단어만), (3) parseCandidates 강화 — 20자 초과·4단어 초과·
//            메타 신호어(THOUGHT/user/번역 등)·문장부호 포함 항목 제거.
//    1.3.0 - 양방향 번역어 생성: 영→한(한국어 번역어)과 한→영(영어 번역어)을 모두 생성해 합침.
//    1.2.0 - 모델명 폴백: gemini-2.0-flash 종료(404) 대응. 여러 최신 모델을 순서대로
//            시도(2.5-flash → 3.5-flash → 2.5-flash-lite → flash-latest), 첫 성공 채택.
//    1.1.0 - 진단 로그 추가([BMG][GlossaryHelper]): HTTP 상태·응답·예외 출력.
//    1.0.0 - 용어집(새 방식) 번역어 후보 자동 생성기.
//            Gemini REST(generateContent)에 단발성 질문: "이 단어를 상대 언어로
//            통역할 때 흔히 쓰는 표현 후보?" → 콤마 구분 후보 문자열을 받아옴.
//            실시간 WebSocket(GeminiLiveClient)과 별개의 가벼운 1회 HTTP 호출.
//

import Foundation

enum GeminiGlossaryHelper {

    // 사용할 REST 모델 후보 (앞에서부터 시도, 404면 다음으로 폴백).
    // 모델명은 시간이 지나면 바뀌므로 여러 개를 순서대로 시도해 견고하게.
    static let models = ["gemini-2.5-flash", "gemini-3.5-flash", "gemini-2.5-flash-lite", "gemini-flash-latest"]

    // source(원문어)와 canonical(표준표기)을 주면,
    // "원문어를 (표준표기 언어로) 통역할 때 흔히 나오는 번역 표현 후보"를 콤마 구분으로 반환.
    // 표준표기 자신은 후보에서 제외(무의미 치환 방지).
    // 실패 시 빈 배열 반환(앱은 계속 동작).
    // source(원문어)와 canonical(표준표기)을 주면, 양방향 매칭에 쓸 번역어 후보를 반환.
    //  - 영→한 방향: 한국어 타겟에서 찾을 한국어 번역어들
    //  - 한→영 방향: 영어 타겟에서 찾을 영어 번역어들
    //  둘을 합쳐 반환(원문어/표준표기 자신은 제외).
    static func suggestTargets(source: String, canonical: String, apiKey: String) async -> [String] {
        let src = source.trimmingCharacters(in: .whitespaces)
        let canon = canonical.trimmingCharacters(in: .whitespaces)
        guard !src.isEmpty, !canon.isEmpty, !apiKey.isEmpty else { return [] }

        // 두 단어(원문어/표준표기) 각각의 언어 판별
        func isKorean(_ s: String) -> Bool {
            s.unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7A3 }
        }
        // 영어 단어, 한국어 단어를 가려냄(칸 고정이라 보통 src=영어, canon=한국어)
        let englishWord = isKorean(src) ? canon : src
        let koreanWord = isKorean(src) ? src : canon

        // 한국어 타겟에서 찾을 한국어 번역어 후보 (영→한 방향)
        let koCands = await fetchCandidates(
            for: englishWord, inLang: "한국어", exclude: koreanWord, apiKey: apiKey)
        // 영어 타겟에서 찾을 영어 번역어 후보 (한→영 방향)
        let enCands = await fetchCandidates(
            for: koreanWord, inLang: "영어", exclude: englishWord, apiKey: apiKey)

        // 합치고 중복 제거 (원문어/표준표기 자신 제외)
        var seen = Set<String>()
        var out: [String] = []
        for w in (koCands + enCands) where !w.isEmpty && w != src && w != canon && !seen.contains(w) {
            seen.insert(w)
            out.append(w)
        }
        return out
    }

    // 한 방향 후보 생성: word를 inLang으로 번역할 때 흔한 표현들 (exclude 제외)
    private static func fetchCandidates(for word: String, inLang: String, exclude: String, apiKey: String) async -> [String] {
        let prompt = """
        Task: '\(word)'에 해당하는 \(inLang) 단어를 최대 3개 출력.
        반드시 \(inLang) 단어/짧은 명사구만, 콤마로 구분해 한 줄로만 출력.
        설명·이유·생각·문장·번호·따옴표 절대 금지. 단어 외 다른 텍스트 출력 금지.
        '\(exclude)'는 제외.
        출력 예: 환자, 환자분, 병자
        """

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "temperature": 0.2,
                "maxOutputTokens": 60,
                "thinkingConfig": ["thinkingBudget": 0]   // 추론(THOUGHT) 출력 차단
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return [] }

        // 여러 모델을 순서대로 시도 — 404(모델 없음)면 다음 모델로 폴백.
        for model in models {
            guard let url = URL(string:
                "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")
            else { continue }

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = data
            req.timeoutInterval = 15

            do {
                let (respData, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                if code == 404 {
                    print("[BMG][GlossaryHelper] \(word): \(model) 없음(404) → 다음 모델 시도")
                    continue   // 다음 모델로
                }
                guard code == 200 else {
                    let bodyStr = String(data: respData, encoding: .utf8)?.prefix(200) ?? ""
                    print("[BMG][GlossaryHelper] \(word): \(model) HTTP \(code) — \(bodyStr)")
                    continue
                }
                guard let text = extractText(from: respData) else {
                    print("[BMG][GlossaryHelper] \(word): \(model) 응답 파싱 실패")
                    continue
                }
                let result = parseCandidates(text, exclude: exclude)
                print("[BMG][GlossaryHelper] \(word) [\(model)] → \(result)")
                return result
            } catch {
                print("[BMG][GlossaryHelper] \(word): \(model) 예외 — \(error.localizedDescription)")
                continue
            }
        }
        print("[BMG][GlossaryHelper] \(word): 모든 모델 실패")
        return []
    }

    // Gemini 응답 JSON에서 텍스트 추출
    private static func extractText(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = obj["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else { return nil }
        let texts = parts.compactMap { $0["text"] as? String }
        let joined = texts.joined()
        return joined.isEmpty ? nil : joined
    }

    // "환자, 환자분, 병자" → ["환자","환자분","병자"], 표준표기/중복/빈/쓰레기 제거
    //  방어: 일부 모델이 추론(THOUGHT)이나 설명문을 섞어 뱉어도 단어만 골라냄.
    private static func parseCandidates(_ text: String, exclude canonical: String) -> [String] {
        // 메타/설명 신호어 — 이게 들어간 항목은 단어가 아니라 설명문이므로 버림
        let banned = ["thought", "user", "wants", "translation", "common", "english",
                      "korean", "here", "are", "the", "following", "예시", "형식",
                      "번역", "표현", "단어", "다음", "입니다", "통역"]

        let raw = text
            .replacingOccurrences(of: "\n", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`·-•*0123456789. ()[]")) }
            .filter { cand -> Bool in
                let c = cand.trimmingCharacters(in: .whitespaces)
                if c.isEmpty || c == canonical { return false }
                // 너무 길면 설명문일 가능성 → 버림 (단어/짧은 구만 허용)
                if c.count > 20 { return false }
                // 공백으로 나눈 토큰이 4개 초과면 문장 → 버림
                if c.split(separator: " ").count > 4 { return false }
                // 메타 신호어가 포함되면 → 버림 (대소문자 무관)
                let lower = c.lowercased()
                if banned.contains(where: { lower.contains($0) }) { return false }
                // 마침표/물음표 등 문장부호가 있으면 → 문장일 가능성, 버림
                if c.contains(".") || c.contains("?") || c.contains(":") { return false }
                return true
            }
        // 중복 제거(순서 유지)
        var seen = Set<String>()
        var out: [String] = []
        for w in raw where !seen.contains(w) {
            seen.insert(w)
            out.append(w)
        }
        return Array(out.prefix(4))
    }
}
