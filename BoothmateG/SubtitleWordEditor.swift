//
//  SubtitleWordEditor.swift
//  BoothmateG
//
//  Version: 1.0.0
//  Changelog:
//    1.0.0 - 최초 작성.
//            - FlowLayout: 단어를 줄바꿈하며 배치하는 흐름 레이아웃
//            - EditableSubtitleText: 단어 더블클릭 → 그 단어가 전체선택된 수정 팝오버
//            - AutoSelectTextField: 나타나는 즉시 텍스트가 블록 선택되는 NSTextField
//

import SwiftUI
import AppKit

// MARK: - 단어 흐름 레이아웃 (자동 줄바꿈)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, total: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > maxWidth, x > 0 {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
            total = max(total, x)
        }
        return CGSize(width: maxWidth == .infinity ? total : maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
    }
}

// MARK: - 단어 더블클릭 편집 텍스트

struct EditableSubtitleText: View {
    let text: String
    var fontSize: CGFloat
    var bold: Bool
    var color: Color

    // 편집 중 여부를 상위로 알려줌 (자동 스크롤 일시정지용)
    @Binding var isEditing: Bool

    // 수정 확정 시 "라인 전체 텍스트"를 새 값으로 콜백
    var onCommit: (String) -> Void

    @State private var editingIndex: Int? = nil
    @State private var draft: String = ""

    // 공백 기준 단어 분리
    private var tokens: [String] {
        text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    }

    var body: some View {
        FlowLayout(spacing: 4, lineSpacing: 4) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { idx, word in
                Text(word)
                    .font(.system(size: fontSize, weight: bold ? .medium : .regular))
                    .foregroundStyle(color)
                    .padding(.horizontal, 1)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {     // 더블클릭 → 그 단어 수정
                        draft = word
                        editingIndex = idx
                    }
                    .popover(isPresented: Binding(
                        get: { editingIndex == idx },
                        set: { if !$0 { editingIndex = nil } }
                    )) {
                        AutoSelectTextField(
                            text: $draft,
                            fontSize: fontSize,
                            bold: bold,
                            onCommit: { commit(idx) },
                            onCancel: { editingIndex = nil }
                        )
                        .frame(minWidth: 160)
                        .padding(10)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: editingIndex) { _, newValue in
            isEditing = (newValue != nil)
        }
    }

    // 단어 교체 후 라인 전체를 다시 합쳐 콜백
    private func commit(_ idx: Int) {
        var t = tokens
        guard idx < t.count else { editingIndex = nil; return }
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            t.remove(at: idx)            // 비우면 그 단어 삭제
        } else {
            t[idx] = trimmed             // "두 단어"처럼 공백 포함 입력도 그대로 반영
        }
        onCommit(t.joined(separator: " "))
        editingIndex = nil
    }
}

// MARK: - 나타나는 즉시 전체 선택되는 NSTextField

struct AutoSelectTextField: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var bold: Bool
    var onCommit: () -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField(string: text)
        tf.delegate = context.coordinator
        tf.font = .systemFont(ofSize: fontSize, weight: bold ? .medium : .regular)
        tf.isBezeled = true
        tf.bezelStyle = .roundedBezel
        tf.lineBreakMode = .byClipping
        tf.usesSingleLineMode = true
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
        // 창에 올라온 직후 한 번만: 첫 응답자 지정 + 전체 선택(블록)
        if !context.coordinator.didFocus, nsView.window != nil {
            context.coordinator.didFocus = true
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                nsView.currentEditor()?.selectAll(nil)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: AutoSelectTextField
        var didFocus = false
        init(_ p: AutoSelectTextField) { parent = p }

        func controlTextDidChange(_ obj: Notification) {
            if let tf = obj.object as? NSTextField { parent.text = tf.stringValue }
        }

        func control(_ control: NSControl, textView: NSTextView,
                     doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit(); return true       // Enter → 확정
            }
            if selector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel(); return true       // Esc → 취소
            }
            return false
        }
    }
}
