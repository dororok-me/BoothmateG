//
//  GlossaryEngine.swift
//  BoothmateG
//
//  Version: 1.1.0
//  Changelog:
//    1.0.0 - 최초 작성. 번역 텍스트에 용어집 항목을 치환
//    1.1.0 - normalize() 추가: 콤마 별칭 + 양방향.
//            각 칸은 콤마로 구분된 별칭 목록, 각 칸의 "첫 단어"가 그 언어의 대표(정규) 표기.
//            번역문에 어느 칸의 별칭이 나오든 그 칸의 대표 표기로 통일.
//            언어가 섞이지 않으므로 방향(KO→EN / EN→KO) 자동 대응.
//

import Foundation

// 용어집 항목으로 번역 텍스트의 단어를 바꿔주는 엔진.
// "번역 후 치환" 방식이라 Gemini 결과를 받은 직후(또는 오버레이 표시 직전)에 통과시킴.
final class GlossaryEngine {

    private var items: [GlossaryItem] = []

    // 용어집 항목 갱신 (설정 화면에서 항목 바뀔 때마다 호출)
    func update(items: [GlossaryItem]) {
        // 긴 단어부터 먼저 치환해야 부분 일치 사고를 막을 수 있음.
        // 예: "탄소중립" 항목이 있는데 "탄소"가 먼저 치환되면 안 됨.
        self.items = items.sorted { $0.source.count > $1.source.count }
    }

    // (구버전) 단순 치환 — source 그대로를 target으로 1:1 교체.
    // 호환성을 위해 남겨둠. 현재 표시 경로는 normalize()를 사용.
    func apply(to text: String) -> String {
        var result = text
        for item in items {
            guard !item.source.isEmpty, !item.target.isEmpty else { continue }
            result = result.replacingOccurrences(of: item.source, with: item.target)
        }
        return result
    }

    // ── v1.1.0 양방향 정규화 ───────────────────────────────
    // 각 항목의 source/target 칸은 콤마로 구분된 별칭 목록.
    // 각 칸의 "첫 단어"가 그 언어의 대표(정규) 표기.
    // 번역문에 어느 칸의 별칭이 나오든 → 그 칸의 대표 표기로 교체.
    func normalize(_ text: String) -> String {
        var result = text

        // (별칭, 대표표기) 쌍 모으기
        var pairs: [(alias: String, canonical: String)] = []
        for item in items {
            let col1 = splitAliases(item.source)
            let col2 = splitAliases(item.target)
            if let canon1 = col1.first { for a in col1 { pairs.append((a, canon1)) } }
            if let canon2 = col2.first { for a in col2 { pairs.append((a, canon2)) } }
        }

        // 긴 별칭부터 교체 (부분 일치 사고 방지)
        pairs.sort { $0.alias.count > $1.alias.count }

        for p in pairs {
            guard !p.alias.isEmpty else { continue }
            result = result.replacingOccurrences(
                of: p.alias, with: p.canonical,
                options: [.caseInsensitive], range: nil)
        }
        return result
    }

    // "넷제로, 제로배출, 무배출" → ["넷제로","제로배출","무배출"]
    private func splitAliases(_ s: String) -> [String] {
        s.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
