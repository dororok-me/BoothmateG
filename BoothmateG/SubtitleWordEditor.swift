//
//  SubtitleWordEditor.swift
//  BoothmateG
//
//  Version: 1.5.0
//  Changelog:
//    1.0.0 - 최초 작성.
//            - FlowLayout: 단어를 줄바꿈하며 배치하는 흐름 레이아웃
//            - EditableSubtitleText: 단어 더블클릭 → 그 단어가 전체선택된 수정 팝오버
//            - AutoSelectTextField: 나타나는 즉시 텍스트가 블록 선택되는 NSTextField
//    1.1.0 - 단어 더블클릭 시 문장 전체를 띄우고, 더블클릭한 단어만 블록 선택된 상태로 시작.
//            (여러 단어를 한 번에 수정 가능. 확정 시 문장 전체를 새 라인으로 반영.)
//    1.2.0 - 수정창을 여러 줄(NSTextView)로 교체해 긴 문장도 줄바꿈되어 전체가 보이도록.
//            선택된 단어를 가능하면 세로 가운데로 스크롤.
//    1.2.1 - 컴파일 오류 수정: maxSize의 greatestFiniteMagnitude를 CGFloat로 명시.
//    1.3.0 - 수정창에 현재 입력(한/영) 배지 추가: 한글이면 "가", 영문이면 "A".
//    1.3.1 - Combine import 추가 (ObservableObject/@Published 컴파일 오류 수정).
//    1.5.0 - EditableSubtitleText에 wordSpacing 파라미터 추가(FlowLayout 단어 간격 조절).
//    1.4.0 - EditableSubtitleText에 onBeginEdit 콜백 추가(옵셔널). 단어 더블클릭으로 편집을
//            시작하는 순간 호출 → 진행 중 자막을 그 시점에 확정하는 용도. 기존 동작은 그대로.
//

import SwiftUI
import AppKit
import Combine  // ObservableObject / @Published
import Carbon   // 현재 키보드 입력 소스(한/영) 감지용

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
    var wordSpacing: CGFloat = 4   // 단어 사이 간격(FlowLayout spacing). 기본 4.

    // 편집 중 여부를 상위로 알려줌 (자동 스크롤 일시정지용)
    @Binding var isEditing: Bool

    // 수정 확정 시 "라인 전체 텍스트"를 새 값으로 콜백
    var onCommit: (String) -> Void

    // v1.4.0: 단어 더블클릭으로 편집을 시작하는 순간 호출(옵셔널).
    // 진행 중(인식 중) 자막에서 이 시점에 확정을 걸어 글자 늘어남을 멈추는 용도.
    var onBeginEdit: () -> Void = {}

    @State private var editingIndex: Int? = nil
    @State private var draft: String = ""
    @State private var selectRange: NSRange? = nil   // 처음 띄울 때 블록 선택할 범위

    // 공백 기준 단어 분리
    private var tokens: [String] {
        text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    }

    // 문장 전체에서 idx번째 단어가 차지하는 글자 범위(UTF-16)
    private func wordRange(_ idx: Int) -> NSRange {
        let t = tokens
        guard idx < t.count else { return NSRange(location: 0, length: 0) }
        let before = t[0..<idx].joined(separator: " ")
        let location = before.isEmpty ? 0 : (before.utf16.count + 1)  // +1 = 단어 앞 공백
        return NSRange(location: location, length: t[idx].utf16.count)
    }

    var body: some View {
        FlowLayout(spacing: wordSpacing, lineSpacing: 4) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { idx, word in
                Text(word)
                    .font(.system(size: fontSize, weight: bold ? .medium : .regular))
                    .foregroundStyle(color)
                    .padding(.horizontal, 1)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {     // 더블클릭 → 문장 전체 + 그 단어 블록 선택
                        onBeginEdit()              // v1.4.0: 편집 시작 순간 알림(진행 중 자막 확정용)
                        draft = tokens.joined(separator: " ")
                        selectRange = wordRange(idx)
                        editingIndex = idx
                    }
                    .popover(isPresented: Binding(
                        get: { editingIndex == idx },
                        set: { if !$0 { editingIndex = nil } }
                    )) {
                        VStack(alignment: .trailing, spacing: 6) {
                            InputLanguageBadge()
                            AutoSelectTextField(
                                text: $draft,
                                fontSize: fontSize,
                                bold: bold,
                                selectRange: selectRange,
                                onCommit: { commit() },
                                onCancel: { editingIndex = nil }
                            )
                            .frame(width: 420, height: 120)
                        }
                        .padding(10)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: editingIndex) { _, newValue in
            isEditing = (newValue != nil)
        }
    }

    // 문장 전체를 새 라인으로 반영
    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        onCommit(trimmed)
        editingIndex = nil
    }
}

// MARK: - 문장 전체를 보여주고, 더블클릭한 단어를 블록 선택한 채로 띄우는 편집기
// (여러 줄로 줄바꿈되어 문장 전체가 보이고, 선택된 단어가 가능한 한 세로 가운데로 옴)

struct AutoSelectTextField: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var bold: Bool
    var selectRange: NSRange? = nil      // 처음 띄울 때 블록 선택할 범위 (없으면 전체 선택)
    var onCommit: () -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = false

        let tv = NSTextView()
        tv.delegate = context.coordinator
        tv.font = .systemFont(ofSize: fontSize, weight: bold ? .medium : .regular)
        tv.isRichText = false
        tv.isEditable = true
        tv.isSelectable = true
        tv.allowsUndo = true
        tv.drawsBackground = false
        tv.textContainerInset = NSSize(width: 6, height: 8)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.textContainer?.widthTracksTextView = true   // 뷰 폭에 맞춰 자동 줄바꿈
        tv.string = text

        scroll.documentView = tv
        context.coordinator.textView = tv
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tv = context.coordinator.textView else { return }
        if tv.string != text { tv.string = text }

        // 창에 올라온 직후 한 번만: 첫 응답자 지정 + 지정 범위(또는 전체) 블록 선택 + 가운데로 스크롤
        if !context.coordinator.didFocus, tv.window != nil {
            context.coordinator.didFocus = true
            let wanted = selectRange
            DispatchQueue.main.async {
                tv.window?.makeFirstResponder(tv)
                let len = (tv.string as NSString).length
                if let r = wanted {
                    let loc = min(max(0, r.location), len)
                    let length = min(r.length, max(0, len - loc))
                    let safe = NSRange(location: loc, length: length)
                    tv.setSelectedRange(safe)
                    tv.scrollRangeToVisible(safe)
                    context.coordinator.center(safe, in: tv)
                } else {
                    tv.setSelectedRange(NSRange(location: 0, length: len))
                }
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: AutoSelectTextField
        weak var textView: NSTextView?
        var didFocus = false
        init(_ p: AutoSelectTextField) { parent = p }

        func textDidChange(_ notification: Notification) {
            if let tv = notification.object as? NSTextView { parent.text = tv.string }
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                parent.onCommit(); return true       // Enter → 확정
            }
            if selector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel(); return true       // Esc → 취소
            }
            return false
        }

        // 선택 범위가 가능하면 세로 가운데에 오도록 스크롤
        func center(_ range: NSRange, in tv: NSTextView) {
            guard let lm = tv.layoutManager, let tc = tv.textContainer,
                  let clip = tv.enclosingScrollView?.contentView else { return }
            let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var rect = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
            rect.origin.y += tv.textContainerInset.height

            let visibleH = clip.bounds.height
            let docH = tv.bounds.height
            var targetY = rect.midY - visibleH / 2
            targetY = max(0, min(targetY, max(0, docH - visibleH)))
            clip.scroll(to: NSPoint(x: 0, y: targetY))
            tv.enclosingScrollView?.reflectScrolledClipView(clip)
        }
    }
}

// MARK: - 현재 입력(한/영) 표시 배지

// 현재 키보드 입력 소스의 주 언어가 한국어면 "가", 아니면 "A"를 보여준다.
// 입력 소스가 바뀌면(한/영 전환) 알림을 받아 즉시 갱신.
final class InputLanguageWatcher: ObservableObject {
    @Published var isKorean: Bool = false
    private var token: NSObjectProtocol?

    func start() {
        update()
        guard token == nil else { return }
        token = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main) { [weak self] _ in self?.update() }
    }

    func update() {
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return }
        var korean = false
        if let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceLanguages) {
            let langs = Unmanaged<CFArray>.fromOpaque(ptr).takeUnretainedValue() as NSArray
            if let first = langs.firstObject as? String { korean = first.hasPrefix("ko") }
        }
        if isKorean != korean { isKorean = korean }
    }

    deinit {
        if let t = token { DistributedNotificationCenter.default().removeObserver(t) }
    }
}

struct InputLanguageBadge: View {
    @StateObject private var watcher = InputLanguageWatcher()

    var body: some View {
        Text(watcher.isKorean ? "가" : "A")
            .font(.system(size: 13, weight: .bold))
            .frame(width: 26, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill((watcher.isKorean ? Color.blue : Color.gray).opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
            )
            .onAppear { watcher.start() }
            .help(watcher.isKorean ? "한글 입력" : "영문 입력")
    }
}
