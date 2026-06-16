//
//  SubtitleStore.swift
//  BoothmateG
//
//  Version: 1.5.0
//  Changelog:
//    1.1.0 - turnComplete 기반 (Gemini가 turnComplete를 거의 안 보내서 실패)
//    1.2.0 - 번역 텍스트의 마침표(.?!) 도착 시 자동으로 segment 확정
//    1.3.0 - updateSource() 추가 (원문 줄도 수정 가능)
//    1.4.0 - 번역 진행 줄 맨 앞 공백 제거 (한 칸 들여쓰기처럼 보이는 현상 방지)
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
        guard let last = currentTarget.last, sentenceEnders.contains(last) else { return }
        flush()
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
    }

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
