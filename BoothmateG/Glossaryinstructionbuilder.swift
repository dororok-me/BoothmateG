//
//  GlossaryInstructionBuilder.swift
//  BoothmateG
//
//  Version: 2.2.0
//  Changelog:
//    2.2.0 - 통역 지침을 최우선 표준 지침으로(맨 앞 배치, PRIMARY). 블랙리스트는 등록 표현만
//            정확히 생략(유사어 확대 금지). 민감 표현 처리는 통역 지침이 담당.
//    2.1.0 - 필러 섹션에 '단어 일부는 보호'(마음의 음 등) 지시 추가.
//    2.0.0 - 통역 지침(자유 서술)·단어 블랙리스트(필러 생략)를 함께 systemInstruction에 합침.
//            build(pairs:guide:blacklist:)로 셋을 하나의 지시문으로 생성. 셋 다 비면 빈 문자열.
//    1.0.0 - 용어집(새 방식)을 Gemini Live systemInstruction 문자열로 변환.
//            등록된 영어↔한국어 쌍을 "반드시 이 용어로 번역" 지시문으로 만들어
//            번역 단계에서 용어를 강제(후처리 치환 불필요). 양방향 지원.
//

import Foundation

enum GlossaryInstructionBuilder {

    // 용어집만으로 만드는 기존 진입점(호환 유지).
    static func build(from pairs: [GlossaryPair]) -> String {
        build(pairs: pairs, guide: "", blacklist: "")
    }

    // 용어집 + 통역 지침 + 블랙리스트를 합쳐 하나의 systemInstruction으로.
    //  셋 다 비어있으면 빈 문자열(주입 안 함 → 기본 번역).
    static func build(pairs: [GlossaryPair], guide: String, blacklist: String) -> String {
        var sections: [String] = []

        // 1) 통역 지침(자유 서술) — 가장 우선하는 표준 지침. 톤·격식·호칭·민감 표현 처리 등.
        let g = guide.trimmingCharacters(in: .whitespacesAndNewlines)
        if !g.isEmpty {
            sections.append("""
            PRIMARY INTERPRETATION GUIDELINES — These are the highest-priority standing instructions. Follow them faithfully throughout, for tone, register, how to address people, and how to handle sensitive or inappropriate content:
            \(g)
            """)
        }

        // 2) 용어집 섹션
        let valid = pairs.compactMap { p -> (en: String, ko: String)? in
            let a = p.source.trimmingCharacters(in: .whitespaces)
            let b = p.canonical.trimmingCharacters(in: .whitespaces)
            guard !a.isEmpty, !b.isEmpty else { return nil }
            let aIsKo = a.unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7A3 }
            let en = aIsKo ? b : a
            let ko = aIsKo ? a : b
            return (en, ko)
        }
        if !valid.isEmpty {
            let termLines = valid.map { "- \"\($0.en)\" ⇄ \"\($0.ko)\"" }.joined(separator: "\n")
            sections.append("""
            GLOSSARY — You MUST use these exact term translations in BOTH directions, in every context:
            \(termLines)
            - When the source contains a listed term, the translation MUST use its paired term exactly.
            - Apply even if the sentence is short, incomplete, or grammatically imperfect.
            """)
        }

        // 3) 블랙리스트 — 정확히 등록된 표현만 생략(확대 해석·유사어 생략 금지).
        let words = blacklist.split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if !words.isEmpty {
            let list = words.map { "\"\($0)\"" }.joined(separator: ", ")
            sections.append("""
            WORD OMISSION LIST — Omit ONLY these exact expressions from the translation; do not translate or echo them:
            \(list)
            - Omit ONLY the exact expressions listed above. Do not extend this to synonyms or similar phrases.
            - Do NOT remove them when they appear as part of a larger real word (e.g. keep "음" inside "마음", "식음").
            - Everything else must be translated faithfully.
            """)
        }

        guard !sections.isEmpty else { return "" }

        // 공통 헤더 + 섹션들 + 공통 규칙
        return """
        You are a professional simultaneous interpreter translating between English and Korean.

        \(sections.joined(separator: "\n\n"))

        General rules:
        - Translate the ENTIRE sentence fully into the target language. Never leave source-language words untranslated.
        - Keep the interpretation natural and concise.
        """
    }
}
