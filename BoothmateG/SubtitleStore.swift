//
//  SubtitleStore.swift
//  BoothmateG
//
//  Version: 1.8.0
//  Changelog:
//    1.8.0 - 약어 마침표에서 줄이 끊기던 문제 수정. "H.E."(His Excellency)·"U.S."·"Dr." 등
//            약어의 마침표를 문장 끝으로 오인해 줄바꿈하던 것을 보류(endsWithAbbreviation).
//    1.1.0 - turnComplete 기반 (Gemini가 turnComplete를 거의 안 보내서 실패)
//    1.2.0 - 번역 텍스트의 마침표(.?!) 도착 시 자동으로 segment 확정
//    1.3.0 - updateSource() 추가 (원문 줄도 수정 가능)
//    1.4.0 - 번역 진행 줄 맨 앞 공백 제거 (한 칸 들여쓰기처럼 보이는 현상 방지)
//    1.6.0 - onSegmentCommitted 콜백 추가(문장 확정 시 번역 텍스트 전달, Fish TTS용).
//    1.5.0 - commitCurrentForEditing(): 진행 중(회색) 자막을 즉시 확정하고 id 반환
//            (메인 콘솔에서 진행 중 자막 단어를 더블클릭해 수정할 때 사용)
//

import Foundation
import SwiftUI
import Combine

struct SubtitleSegment: Identifiable, Equatable {
    let id = UUID()
    var sourceText: String
    var targetText: String
    var createdAt: Date = Date()
}

@MainActor
final class SubtitleStore: ObservableObject {
    @Published var segments: [SubtitleSegment] = []
    @Published var currentSource: String = ""
    @Published var currentTarget: String = ""

    // 문장 종결 문자
    private let sentenceEnders: Set<Character> = [".", "!", "?", "。", "！", "？"]

    // v1.7.0: 수정 창이 떠 있는 동안 true. 이때는 문장 확정(flush)을 보류해
    //         수정 중이던 진행 자막이 segments로 넘어가 중복 표시되는 것을 막는다.
    //         백그라운드 인식·번역은 계속 current에 쌓이고, 수정 종료 시 정상 확정 재개.
    var editingHold: Bool = false

    func appendSource(_ chunk: String) {
        currentSource += chunk
    }

    func appendTarget(_ chunk: String) {
        currentTarget += chunk
        // 번역문 맨 앞 공백 제거 (한 칸 들여쓰기처럼 보이는 현상 방지)
        if currentTarget.first == " " {
            currentTarget = String(currentTarget.drop { $0 == " " })
        }
        // 번역 텍스트에 마침표가 들어왔으면 segment 확정 시도
        flushIfSentenceEnded()
    }

    // turnComplete 신호 받으면 강제 확정
    func finalizeTurn() {
        flush()
    }

    // 번역에 마침표가 있고, 원문도 어느 정도 있으면 확정
    private func flushIfSentenceEnded() {
        // v1.7.0: 수정 중이면 자동 확정 보류 (수정 자막 중복 방지). 백그라운드는 current에 계속 누적.
        guard !editingHold else { return }
        guard let last = currentTarget.last, sentenceEnders.contains(last) else { return }
        // v1.8.0: 마침표(.)로 끝나되 약어(H.E., U.S., Dr. 등)면 확정 보류 → 약어 마침표에서 줄이 안 끊김
        if last == "." && endsWithAbbreviation(currentTarget) { return }
        flush()
    }

    // v1.8.0: 마지막 토큰이 약어 마침표인지 판단 (문장 종결 오인 방지)
    private func endsWithAbbreviation(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        // 1) 끝이 단일 알파벳+마침표 반복 형태 (H. / H.E. / U.S. / e.g.)
        if t.range(of: "(?:\\b[A-Za-z]\\.)+$", options: .regularExpression) != nil { return true }
        // 2) 흔한 약어 목록 (소문자 비교)
        let abbrevs = ["mr.", "mrs.", "ms.", "dr.", "prof.", "st.", "ave.", "inc.", "ltd.",
                       "jr.", "sr.", "vs.", "etc.", "no.", "ph.d.", "m.d.", "rep.", "sen.", "gov."]
        let lower = t.lowercased()
        return abbrevs.contains { lower.hasSuffix($0) }
    }

    // 현재 진행 중인 자막을 segment로 확정
    private func flush() {
        let source = currentSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = currentTarget.trimmingCharacters(in: .whitespacesAndNewlines)

        // 둘 중 하나라도 비어있으면 아직 확정하지 않음 (한쪽만 도착한 경우)
        guard !source.isEmpty, !target.isEmpty else { return }

        segments.append(SubtitleSegment(
            sourceText: source,
            targetText: target
        ))
        currentSource = ""
        currentTarget = ""
        // v1.6.0: 문장이 확정될 때마다 확정된 번역 텍스트를 콜백 (Fish TTS 송출용)
        onSegmentCommitted?(target)
    }

    // v1.6.0: 새 문장(세그먼트)이 확정될 때 호출되는 콜백. 인자 = 확정된 번역 텍스트.
    var onSegmentCommitted: ((String) -> Void)? = nil

    // 번역(target) 줄 수정
    func updateTarget(id: UUID, newText: String) {
        guard let idx = segments.firstIndex(where: { $0.id == id }) else { return }
        segments[idx].targetText = newText
    }

    // 원문(source) 줄 수정  (v1.3.0 추가)
    func updateSource(id: UUID, newText: String) {
        guard let idx = segments.firstIndex(where: { $0.id == id }) else { return }
        segments[idx].sourceText = newText
    }

    func clear() {
        segments.removeAll()
        currentSource = ""
        currentTarget = ""
    }

    // v1.5.0 추가: 현재 진행 중인 자막을 즉시 확정하고 그 세그먼트 id를 반환.
    // (메인 콘솔에서 진행 중 자막을 더블클릭해 수정할 때 사용 — 한쪽만 있어도 확정)
    // 반환값: 새로 만든 세그먼트의 id (확정할 내용이 없으면 nil)
    func commitCurrentForEditing() -> UUID? {
        let source = currentSource.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = currentTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty || !target.isEmpty else { return nil }

        let seg = SubtitleSegment(sourceText: source, targetText: target)
        segments.append(seg)
        currentSource = ""
        currentTarget = ""
        return seg.id
    }
}
