//
//  GlossaryInstructionBuilder.swift
//  BoothmateG
//
//  Version: 1.0.0
//  Changelog:
//    1.0.0 - 용어집(새 방식)을 Gemini Live systemInstruction 문자열로 변환.
//            등록된 영어↔한국어 쌍을 "반드시 이 용어로 번역" 지시문으로 만들어
//            번역 단계에서 용어를 강제(후처리 치환 불필요). 양방향 지원.
//

import Foundation

enum GlossaryInstructionBuilder {

    // 용어집 쌍들을 systemInstruction 문자열로 변환.
    //  - 영어↔한국어 쌍을 양방향으로 명시(영→한, 한→영 모두 강제).
    //  - 등록이 없으면 빈 문자열 반환(주입 안 함 → 기본 번역).
    static func build(from pairs: [GlossaryPair]) -> String {
        // 유효한 쌍만(양쪽 다 있어야)
        let valid = pairs.compactMap { p -> (en: String, ko: String)? in
            let a = p.source.trimmingCharacters(in: .whitespaces)
            let b = p.canonical.trimmingCharacters(in: .whitespaces)
            guard !a.isEmpty, !b.isEmpty else { return nil }
            // 칸 고정상 a=영어, b=한국어지만, 혹시 섞여도 한글 유무로 정렬
            let aIsKo = a.unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7A3 }
            let en = aIsKo ? b : a
            let ko = aIsKo ? a : b
            return (en, ko)
        }
        guard !valid.isEmpty else { return "" }

        // 용어 목록 라인
        let termLines = valid.map { "- \"\($0.en)\" ⇄ \"\($0.ko)\"" }.joined(separator: "\n")

        // 지시문: 용어 강제 + 완전한 번역(영어 잔존 방지)
        return """
        You are a professional simultaneous interpreter translating between English and Korean.

        GLOSSARY — You MUST use these exact term translations in BOTH directions, in every context:
        \(termLines)

        Rules:
        - When the source contains an English term above, the Korean translation MUST use its paired Korean term exactly.
        - When the source contains a Korean term above, the English translation MUST use its paired English term exactly.
        - Apply these terms even if the sentence is short, incomplete, or grammatically imperfect.
        - Translate the ENTIRE sentence fully into the target language. Never leave source-language words untranslated.
        - Keep the interpretation natural and concise.
        """
    }
}
