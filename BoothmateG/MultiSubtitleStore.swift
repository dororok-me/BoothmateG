//
//  MultiSubtitleStore.swift
//  BoothmateG
//
//  Version: 1.5.0
//  Changelog:
//    1.0.0 - 최초 작성. 화자 원문 + 여러 언어 번역을 함께 보관.
//    1.1.0 - 번역 진행 줄 맨 앞 공백 제거 (한 칸 들여쓰기처럼 보이는 현상 방지)
//    1.2.0 - updateTarget(id,lang,newText)/updateSource(id,newText)/commitCurrentForEditing() 추가
//            (다국어 메인 콘솔 단어 더블클릭 수정용)
//    1.3.0 - 원문 기준 문장 자동 확정(모든 언어 도착 조건) — 실시간 타이밍상 확정이 잘 안 돼 폐기.
//    1.5.0 - onSegmentCommitted 콜백 추가(문장 확정 시 언어별 번역 전달, Fish TTS용).
//    1.4.0 - 한국어 기준 문장 자동 확정으로 변경. 한국어(원문 또는 ko 번역)에 문장 끝(.?!)이 오면
//            그 시점의 원문+모든 언어를 한 세그먼트로 확정. sourceIsKorean으로 화자 한국어 여부 전달.
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
        flushIfKoreanSentenceEnded()   // v1.4.0: 한국어 문장 끝나면 자동 확정
    }

    func appendTarget(_ lang: String, _ text: String) {
        let prev = currentTargets[lang] ?? ""
        var joined = prev + (prev.isEmpty ? "" : " ") + text
        // 번역문 맨 앞 공백 제거 (한 칸 들여쓰기처럼 보이는 현상 방지)
        if joined.first == " " { joined = String(joined.drop { $0 == " " }) }
        currentTargets[lang] = joined
        flushIfKoreanSentenceEnded()   // v1.4.0: 한국어 번역 문장 끝나면 자동 확정
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

    // v1.2.0 추가: 특정 세그먼트의 특정 언어 번역 줄 수정
    func updateTarget(id: UUID, lang: String, newText: String) {
        guard let idx = segments.firstIndex(where: { $0.id == id }) else { return }
        segments[idx].targets[lang] = newText
    }

    // v1.2.0 추가: 화자 원문(source) 줄 수정
    func updateSource(id: UUID, newText: String) {
        guard let idx = segments.firstIndex(where: { $0.id == id }) else { return }
        segments[idx].source = newText
    }

    // v1.2.0 추가: 현재 진행 중인 자막(원문+모든 언어)을 즉시 확정하고 그 세그먼트 id를 반환.
    // (진행 중 자막을 단어 더블클릭으로 수정할 때 사용)
    // 반환값: 새로 만든 세그먼트의 id (확정할 내용이 없으면 nil)
    func commitCurrentForEditing() -> UUID? {
        let src = currentSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasTarget = currentTargets.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !src.isEmpty || hasTarget else { return nil }

        var cleaned: [String: String] = [:]
        for (k, v) in currentTargets {
            cleaned[k] = v.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let seg = MultiSegment(source: src, targets: cleaned)
        segments.append(seg)
        currentSource = ""
        currentTargets = [:]
        return seg.id
    }

    // v1.4.0: 한국어 기준으로 문장이 끝나면 그 시점의 원문+모든 언어를 한 세그먼트로 자동 확정.
    // 한국어가 가장 중요하므로 한국어 문장 단위로 끊는다(다른 언어는 그 시점까지 온 만큼 포함).
    // 한국어 위치: 화자가 한국어면 currentSource, 청중에 한국어("ko")가 있으면 그 번역.
    private let sentenceEnders: Set<Character> = [".", "!", "?", "。", "！", "？"]

    private func koreanText() -> String {
        // 화자(원문)가 한국어인 경우
        if sourceIsKorean { return currentSource }
        // 청중 언어 중 한국어 번역
        if let ko = currentTargets["ko"], !ko.isEmpty { return ko }
        // 한국어가 아예 없으면 원문으로 폴백
        return currentSource
    }

    // 화자 언어가 한국어인지 여부 (ContentView가 설정). 기본은 false.
    var sourceIsKorean: Bool = false

    private func flushIfKoreanSentenceEnded() {
        let ko = koreanText().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = ko.last, sentenceEnders.contains(last) else { return }
        // 원문이 비어 있으면(아직 화자 텍스트 없음) 확정하지 않음
        guard !currentSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        flushSentence()
    }

    private func flushSentence() {
        let src = currentSource.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !src.isEmpty else { return }
        var cleaned: [String: String] = [:]
        for (k, v) in currentTargets {
            cleaned[k] = v.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        segments.append(MultiSegment(source: src, targets: cleaned))
        currentSource = ""
        currentTargets = [:]
        if segments.count > 200 { segments.removeFirst(segments.count - 200) }
        // v1.5.0: 문장이 확정될 때마다 확정된 세그먼트(언어별 번역 묶음)를 콜백 (Fish TTS 송출용)
        onSegmentCommitted?(cleaned)
    }

    // v1.5.0: 새 문장(세그먼트)이 확정될 때 호출되는 콜백. 인자 = 언어별 번역 딕셔너리.
    var onSegmentCommitted: (([String: String]) -> Void)? = nil
}
