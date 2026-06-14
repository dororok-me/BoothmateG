//
//  MultiSubtitleStore.swift
//  BoothmateG
//
//  Version: 1.1.0
//  Changelog:
//    1.0.0 - 최초 작성. 화자 원문 + 여러 언어 번역을 함께 보관.
//    1.1.0 - 번역 진행 줄 맨 앞 공백 제거 (한 칸 들여쓰기처럼 보이는 현상 방지)
//

import SwiftUI
import Combine

struct MultiSegment: Identifiable {
    let id = UUID()
    var source: String
    var targets: [String: String]   // 언어코드 → 번역문
}

@MainActor
final class MultiSubtitleStore: ObservableObject {
    @Published var segments: [MultiSegment] = []
    @Published var currentSource: String = ""
    @Published var currentTargets: [String: String] = [:]
    @Published var langs: [String] = []          // 표시 순서(청중 언어들)

    func setLanguages(_ l: [String]) {
        langs = l
        clear()
    }

    func appendSource(_ text: String) {
        currentSource += (currentSource.isEmpty ? "" : " ") + text
    }

    func appendTarget(_ lang: String, _ text: String) {
        let prev = currentTargets[lang] ?? ""
        var joined = prev + (prev.isEmpty ? "" : " ") + text
        // 번역문 맨 앞 공백 제거 (한 칸 들여쓰기처럼 보이는 현상 방지)
        if joined.first == " " { joined = String(joined.drop { $0 == " " }) }
        currentTargets[lang] = joined
    }

    func finalizeTurn() {
        guard !currentSource.isEmpty || !currentTargets.isEmpty else { return }
        segments.append(MultiSegment(source: currentSource, targets: currentTargets))
        currentSource = ""
        currentTargets = [:]
        if segments.count > 200 { segments.removeFirst(segments.count - 200) }
    }

    func clear() {
        segments = []
        currentSource = ""
        currentTargets = [:]
    }
}
