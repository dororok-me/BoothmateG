//
//  MultiOverlayWindow.swift
//  BoothmateG
//
//  Version: 6.1.0
//  Changelog:
//    6.0.0 - 버튼식 굵기/색, 상단 닫기 버튼
//    6.1.0 - 상단 회색(제목표시줄 비침) 제거: 카드가 맨 위까지 채우고
//            기어/닫기는 카드 위에 떠있게. 제목표시줄 구분선 제거.
//

import SwiftUI
import AppKit

final class MultiOverlayController {
    private var panel: NSPanel?
    private(set) var isVisible = false

    func toggle(store: MultiSubtitleStore) {
        if isVisible { hide() } else { show(store: store) }
    }

    func show(store: MultiSubtitleStore) {
        hide()
        guard !store.langs.isEmpty else { return }

        let mainWidth = NSApp.mainWindow?.frame.width
            ?? NSApp.keyWindow?.frame.width
            ?? 820
        let w = max(760, mainWidth)
        let h: CGFloat = 620

        let root = MultiOverlayView(store: store, onClose: { [weak self] in self?.hide() })
        let hosting = NSHostingController(rootView: root)
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.titled, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.titlebarSeparatorStyle = .none
        p.standardWindowButton(.closeButton)?.isHidden = true
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true
        p.isMovableByWindowBackground = true
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentViewController = hosting
        p.setContentSize(NSSize(width: w, height: h))
        p.center()
        p.orderFront(nil)

        panel = p
        isVisible = true
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        isVisible = false
    }
}

struct MultiOverlayView: View {
    @ObservedObject var store: MultiSubtitleStore
    var onClose: () -> Void = {}

    @AppStorage("multi_ov_font")     private var fontSize: Double = 30
    @AppStorage("multi_ov_bgop")     private var bgOpacity: Double = 0.8
    @AppStorage("multi_ov_lines")    private var lineCount: Int = 3
    @AppStorage("multi_ov_weight")   private var weightIdx: Int = 2
    @AppStorage("multi_ov_coloridx") private var colorIdx: Int = 0

    @State private var showOptions = false

    private let palette: [Color] = [
        .white,
        Color(red: 1.00, green: 0.92, blue: 0.23),
        Color(red: 0.45, green: 1.00, blue: 0.45),
        Color(red: 0.35, green: 0.85, blue: 1.00),
        Color(red: 1.00, green: 0.55, blue: 0.20)
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 카드들이 맨 위까지 채움 (회색 띠 방지)
            VStack(spacing: 8) {
                ForEach(store.langs, id: \.self) { lang in
                    section(lang)
                }
            }
            .padding(8)

            // 카드 위에 떠 있는 기어 + 닫기
            HStack(spacing: 8) {
                Button { showOptions.toggle() } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.45)))
                }
                .buttonStyle(.plain)

                Button { onClose() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(Color.red.opacity(0.7)))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
            .padding(.trailing, 16)

            if showOptions { optionsPanel.padding(.top, 48).padding(.trailing, 12) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func section(_ lang: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(tag(lang)).font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.55))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            teleprompterBody(lang)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(bgOpacity)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func teleprompterBody(_ lang: String) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                let ls = lines(lang)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(ls.enumerated()), id: \.offset) { idx, line in
                        Text(line)
                            .font(.system(size: CGFloat(fontSize), weight: weightFor(weightIdx)))
                            .foregroundStyle(textColor.opacity(opacity(idx, total: ls.count)))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .onChange(of: store.currentTargets[lang]) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: store.segments.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
        .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: .bottom))
    }

    private var optionsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("오버레이 옵션").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)

            sliderRow("글자 크기", value: $fontSize, range: 16...56, percent: false)
            sliderRow("배경 투명도", value: $bgOpacity, range: 0.2...1.0, percent: true)

            Stepper("표시 줄 수: \(lineCount)", value: $lineCount, in: 1...10)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 5) {
                Text("폰트 굵기").font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { i in
                        Button { weightIdx = i } label: {
                            Text("가")
                                .font(.system(size: 17, weight: weightFor(i)))
                                .foregroundStyle(weightIdx == i ? Color.black : Color.white.opacity(0.85))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(
                                    RoundedRectangle(cornerRadius: 7)
                                        .fill(weightIdx == i ? Color.white : Color.white.opacity(0.14))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("글자 색").font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 12) {
                    ForEach(0..<palette.count, id: \.self) { i in
                        Button { colorIdx = i } label: {
                            Circle()
                                .fill(palette[i])
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                .overlay(Circle().stroke(Color.white, lineWidth: colorIdx == i ? 3 : 0))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }

            HStack {
                Spacer()
                Button("옵션 닫기") { showOptions = false }.buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.94)))
    }

    private func sliderRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, percent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(percent ? String(format: "%.0f%%", value.wrappedValue * 100) : "\(Int(value.wrappedValue))pt")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
            }
            Slider(value: value, in: range)
        }
    }

    private var textColor: Color {
        let i = min(max(colorIdx, 0), palette.count - 1)
        return palette[i]
    }

    private func weightFor(_ idx: Int) -> Font.Weight {
        switch idx {
        case 0: return .regular
        case 1: return .medium
        case 2: return .semibold
        case 3: return .bold
        default: return .heavy
        }
    }

    private func lines(_ lang: String) -> [String] {
        var arr = store.segments.compactMap { seg -> String? in
            let t = seg.targets[lang] ?? ""
            return t.isEmpty ? nil : t
        }
        let cur = store.currentTargets[lang] ?? ""
        if !cur.isEmpty { arr.append(cur) }
        return Array(arr.suffix(max(1, lineCount)))
    }

    private func opacity(_ idx: Int, total: Int) -> Double {
        let fromBottom = total - 1 - idx
        switch fromBottom {
        case 0: return 1.0
        case 1: return 0.6
        case 2: return 0.38
        case 3: return 0.24
        default: return 0.15
        }
    }

    private func tag(_ lang: String) -> String {
        switch lang {
        case "en": return "EN"
        case "ko": return "한국어"
        case "ja": return "日本語"
        case "zh-Hans": return "中文(简)"
        case "zh-Hant": return "中文(繁)"
        case "es": return "ES"
        case "fr": return "FR"
        case "de": return "DE"
        default: return lang.uppercased()
        }
    }
}
