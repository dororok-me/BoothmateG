//
//  GlossaryEngine.swift
//  BoothmateG
//
//  Version: 1.2.0
//  Changelog:
//    1.0.0 - 최초 작성. 번역 텍스트에 용어집 항목을 치환
//    1.1.0 - normalize() 추가: 콤마 별칭 + 양방향. 각 칸 첫 단어를 대표 표기로 통일
//    1.2.0 - 영어 표현 단·복수(s/es) 자동 인식:
//            영어 별칭은 단어 경계 + 끝의 (s|es)를 선택적으로 매칭하므로
//            "Net Zero"만 등록해도 "Net Zeros"/"Net Zeroes"까지 "Net Zero"로 통일.
//            한국어 별칭은 조사 결합 특성상 기존 단순 치환 유지.
//

import Foundation

// 용어집 항목으로 번역 텍스트의 단어를 바꿔주는 엔진.
// "번역 후 치환" 방식이라 결과를 받은 직후(또는 화면 표시 직전)에 통과시킴.
final class GlossaryEngine {

    private var items: [GlossaryItem] = []

    // 용어집 항목 갱신
    func update(items: [GlossaryItem]) {
        self.items = items.sorted { $0.source.count > $1.source.count }
    }

    // (구버전) 단순 치환 — 호환용으로 남겨둠. 현재 표시 경로는 normalize() 사용.
    func apply(to text: String) -> String {
        var result = text
        for item in items {
            guard !item.source.isEmpty, !item.target.isEmpty else { continue }
            result = result.replacingOccurrences(of: item.source, with: item.target)
        }
        return result
    }

    // ── 양방향 정규화 (v1.2.0: 영어 단·복수 자동) ───────────
    // 각 칸은 콤마 별칭 목록, 각 칸 "첫 단어"가 대표 표기.
    // 번역문에 어느 칸의 별칭이 나오든 → 그 칸의 대표 표기로 통일.
    func normalize(_ text: String) -> String {
        var result = text

        // (별칭, 대표표기) 쌍 모으기
        var pairs: [(alias: String, canonical: String)] = []
        for item in items {
            let col1 = splitAliases(item.source)
            let col2 = splitAliases(item.target)
            if let c1 = col1.first { for a in col1 { pairs.append((a, c1)) } }
            if let c2 = col2.first { for a in col2 { pairs.append((a, c2)) } }
        }

        // 긴 별칭부터 (부분 일치 사고 방지)
        pairs.sort { $0.alias.count > $1.alias.count }

        for p in pairs where !p.alias.isEmpty {
            if isEnglish(p.alias) {
                // 영어: 단어 경계 + 끝의 (s|es) 선택적 → 단·복수 모두 통일
                result = replaceEnglish(in: result, alias: p.alias, canonical: p.canonical)
            } else {
                // 한국어 등: 기존 단순 치환 (대소문자 무시)
                result = result.replacingOccurrences(
                    of: p.alias, with: p.canonical, options: [.caseInsensitive])
            }
        }
        return result
    }

    // "넷제로, 제로배출, 무배출" → ["넷제로","제로배출","무배출"]
    private func splitAliases(_ s: String) -> [String] {
        s.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // 한글이 없고 영문자가 있으면 영어로 간주
    private func isEnglish(_ s: String) -> Bool {
        let hasHangul = s.unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7A3 }
        let hasLatin = s.unicodeScalars.contains {
            ($0.value >= 0x41 && $0.value <= 0x5A) || ($0.value >= 0x61 && $0.value <= 0x7A)
        }
        return !hasHangul && hasLatin
    }

    // 영어 별칭을 단어 경계 + 선택적 복수(s/es)까지 한 번에 치환
    private func replaceEnglish(in text: String, alias: String, canonical: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: alias)
        // 앞뒤가 영문자가 아닐 때만(단어 경계), 끝의 es/s는 있어도 됨
        let pattern = "(?<![A-Za-z])\(escaped)(?:es|s)?(?![A-Za-z])"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text.replacingOccurrences(of: alias, with: canonical, options: [.caseInsensitive])
        }
        let full = NSRange(text.startIndex..., in: text)
        let template = NSRegularExpression.escapedTemplate(for: canonical)
        return re.stringByReplacingMatches(in: text, options: [], range: full, withTemplate: template)
    }
}
