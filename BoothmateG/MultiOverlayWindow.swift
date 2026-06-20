//
//  MultiOverlayWindow.swift
//  BoothmateG
//
//  Version: 6.10.0
//  Changelog:
//    6.10.0 - 배경색 옵션을 폰트 색상과 동일 구성으로(흰/노랑/초록/하늘/주황/검정).
//    6.1.0 - 상단 회색 제거
//    6.2.0 - 옵션 패널을 상단 끝에 붙여 톱니/X를 가리게. 옵션 패널에 자체 닫기(X).
//    6.3.0 - 글자 색에 검은색 추가. 어두운 패널과 구별되게 모든 색 동그라미에
//            테두리를 일관되게 강화.
//    6.4.0 - 자막 영역 상단 그라데이션 마스크(상단 흐림 효과) 제거.
//    6.5.0 - 창 어디든 더블클릭하면 화면 전체로 확대(다시 더블클릭하면 원래 크기 복원).
//    6.6.0 - (1) 옵션 패널 열어도 창 크기 안 변하게 잠금(sizingOptions=[]) + 패널 내부 스크롤.
//            (2) 옵션에 표시 언어 토글 추가 — 오버레이에 보일 언어 선택(청중/QR 영향 없음).
//            (3) 한국어 섹션을 단일 오버레이처럼 전체 텔레프롬프터 스크롤 + 카라오케 드립으로.
//    6.7.0 - 옵션 메뉴에 단일 오버레이의 모든 설정 추가: 배경 모드(OBS/화면공유)+배경색,
//            테두리, 원문 표시, 줄 간격, 내부 여백, 창 투명도, 자막 지우기. 전 섹션 공통 적용.
//    6.8.0 - 줄 간격을 실제 .lineSpacing()으로 적용(한 문단 내 줄 높이). 단락(세그먼트) 사이
//            간격 슬라이더 별도 추가. 한국어 섹션 현재 줄을 카라오케 단어나열 대신
//            일반 텍스트(줄바꿈 기준)로 변경.
//
//    6.9.0 - 설정(옵션) 패널 열렸을 때 패널 바깥을 클릭하면 설정이 닫히도록 추가.

import SwiftUI
import AppKit

final class MultiOverlayController {
    private var panel: NSPanel?
    private var savedFrame: NSRect? = nil   // 전체 보기 전 원래 크기
    private(set) var isVisible = false

    func toggle(store: MultiSubtitleStore) {
        if isVisible { hide() } else { show(store: store) }
    }

    // 화면 전체로 확대 ↔ 원래 크기 복원
    func toggleFullView() {
        guard let p = panel, let screen = p.screen ?? NSScreen.main else { return }
        if let saved = savedFrame {
            p.setFrame(saved, display: true, animate: true)
            savedFrame = nil
        } else {
            savedFrame = p.frame
            p.setFrame(screen.visibleFrame, display: true, animate: true)
        }
    }

    func show(store: MultiSubtitleStore) {
        hide()
        guard !store.langs.isEmpty else { return }

        let mainWidth = NSApp.mainWindow?.frame.width
            ?? NSApp.keyWindow?.frame.width
            ?? 820
        let w = max(760, mainWidth)
        let h: CGFloat = 620

        let root = MultiOverlayView(
            store: store,
            onClose: { [weak self] in self?.hide() },
            onToggleFull: { [weak self] in self?.toggleFullView() }
        )
        let hosting = NSHostingController(rootView: root)
        // 콘텐츠 크기가 창 크기를 바꾸지 못하게 잠금 (옵션 패널 열어도 창 안 커짐)
        hosting.sizingOptions = []
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
    var onToggleFull: () -> Void = {}

    @AppStorage("multi_ov_font")     private var fontSize: Double = 30
    @AppStorage("multi_ov_bgop")     private var bgOpacity: Double = 0.8
    @AppStorage("multi_ov_lines")    private var lineCount: Int = 3
    @AppStorage("multi_ov_weight")   private var weightIdx: Int = 2
    @AppStorage("multi_ov_coloridx") private var colorIdx: Int = 0
    @AppStorage("multi_ov_hiddenLangs") private var hiddenLangsCSV: String = ""   // 오버레이에서 숨길 언어(쉼표) — 청중/QR엔 영향 없음
    // 단일 오버레이와 동일한 설정들 (멀티 전용 키)
    @AppStorage("multi_ov_bgMode")     private var bgMode: String = "color"   // "obs"=완전투명, "color"=배경색
    @AppStorage("multi_ov_bgColorHex") private var bgColorHex: String = "#000000"
    @AppStorage("multi_ov_stroke")     private var textStroke: Bool = false
    @AppStorage("multi_ov_showSource") private var showSourceOpt: Bool = false
    @AppStorage("multi_ov_linespace")  private var lineSpace: Double = 6        // 단락(세그먼트) 사이 간격
    @AppStorage("multi_ov_textlinespace") private var lineSpacingVal: Double = 2 // 줄 간격(한 문단 내 줄 높이)
    @AppStorage("multi_ov_inmargin")   private var innerMargin: Double = 14
    @AppStorage("multi_ov_winop")      private var winOpacity: Double = 1.0

    @State private var showOptions = false

    private let palette: [Color] = [
        .white,
        Color(red: 1.00, green: 0.92, blue: 0.23),
        Color(red: 0.45, green: 1.00, blue: 0.45),
        Color(red: 0.35, green: 0.85, blue: 1.00),
        Color(red: 1.00, green: 0.55, blue: 0.20),
        .black
    ]

    // ── 표시 언어 선택 상태 (표시만 거름; store/relay/QR엔 영향 없음) ──
    private var hiddenSet: Set<String> {
        Set(hiddenLangsCSV.split(separator: ",").map(String.init))
    }
    private var displayedLangs: [String] {
        store.langs.filter { !hiddenSet.contains($0) }
    }
    private func toggleLang(_ lang: String) {
        var s = hiddenSet
        if s.contains(lang) { s.remove(lang) } else { s.insert(lang) }
        hiddenLangsCSV = s.sorted().joined(separator: ",")
    }

    // ── 배경 ──
    private var isOBS: Bool { bgMode == "obs" }
    // 배경색: 폰트 palette(흰/노랑/초록/하늘/주황/검정)와 동일 구성
    private let bgPalette: [(String, String)] = [
        ("흰색", "#FFFFFF"), ("노랑", "#FFEB3B"), ("초록", "#72FF72"),
        ("하늘", "#59D9FF"), ("주황", "#FF8C33"), ("검정", "#000000")
    ]
    @ViewBuilder private func bgFillShape() -> some View {
        if isOBS {
            Color.clear
        } else {
            RoundedRectangle(cornerRadius: 12).fill(Color(hex: bgColorHex).opacity(bgOpacity))
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                ForEach(displayedLangs, id: \.self) { lang in
                    if lang == "ko" {
                        koreanSection(lang)   // 한국어: 단일 오버레이처럼 텔레프롬프터 스크롤 + 카라오케
                    } else {
                        section(lang)         // 그 외 언어: 기존 방식
                    }
                }
            }
            .padding(8)

            // 톱니 + 닫기 (옵션 열리면 패널이 이 위를 덮음)
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

            // 설정 열렸을 때: 패널 바깥(자막 영역) 클릭 → 설정 닫기
            if showOptions {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { showOptions = false }
            }

            // 옵션 패널: 상단 끝에 붙여 톱니/X를 가림 (패널 위 클릭은 닫히지 않음)
            if showOptions {
                optionsPanel
                    .padding(.top, 8)
                    .padding(.trailing, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opacity(winOpacity)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onToggleFull() }   // 어디든 더블클릭 → 전체 보기 토글
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
        .background(bgFillShape())
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // 한국어 섹션: 단일 오버레이처럼 전체 텔레프롬프터 스크롤(최신 하단).
    // 현재 줄은 한 문장(줄바꿈) 기준의 일반 텍스트로 표시.
    private func koreanSection(_ lang: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(tag(lang)).font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.55))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            GeometryReader { geo in
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)   // 최신이 하단에 오도록 위로 밀기
                            VStack(alignment: .leading, spacing: lineSpace) {
                                ForEach(store.segments) { seg in
                                    let t = seg.targets[lang] ?? ""
                                    if !t.isEmpty {
                                        VStack(alignment: .leading, spacing: 2) {
                                            if showSourceOpt && !seg.source.isEmpty {
                                                Text(seg.source)
                                                    .font(.system(size: CGFloat(fontSize) * 0.62))
                                                    .foregroundStyle(.white.opacity(0.5))
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            Text(t)
                                                .font(.system(size: CGFloat(fontSize), weight: weightFor(weightIdx)))
                                                .foregroundStyle(textColor)
                                                .modifier(StrokeModifier(enabled: textStroke))
                                                .lineSpacing(lineSpacingVal)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .id(seg.id)
                                    }
                                }
                                let cur = store.currentTargets[lang] ?? ""
                                if !cur.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        if showSourceOpt && !store.currentSource.isEmpty {
                                            Text(store.currentSource)
                                                .font(.system(size: CGFloat(fontSize) * 0.62))
                                                .foregroundStyle(.white.opacity(0.5))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        // 한 줄(문장) 기준으로 자연스럽게 줄바꿈 — 단어 나열 X
                                        Text(cur)
                                            .font(.system(size: CGFloat(fontSize), weight: weightFor(weightIdx)))
                                            .foregroundStyle(textColor)
                                            .modifier(StrokeModifier(enabled: textStroke))
                                            .lineSpacing(lineSpacingVal)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Color.clear.frame(height: 1).id("ko_bottom")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, innerMargin)
                            .padding(.bottom, 12)
                        }
                        .frame(minHeight: geo.size.height)
                    }
                    .onChange(of: store.currentTargets[lang]) { _, _ in
                        proxy.scrollTo("ko_bottom", anchor: .bottom)
                    }
                    .onChange(of: store.segments.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("ko_bottom", anchor: .bottom) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bgFillShape())
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func teleprompterBody(_ lang: String) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                let items = recentItems(lang)
                VStack(alignment: .leading, spacing: lineSpace) {
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                        VStack(alignment: .leading, spacing: 2) {
                            if showSourceOpt && !item.src.isEmpty {
                                Text(item.src)
                                    .font(.system(size: CGFloat(fontSize) * 0.62))
                                    .foregroundStyle(.white.opacity(0.5 * opacity(idx, total: items.count)))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text(item.tgt)
                                .font(.system(size: CGFloat(fontSize), weight: weightFor(weightIdx)))
                                .foregroundStyle(textColor.opacity(opacity(idx, total: items.count)))
                                .modifier(StrokeModifier(enabled: textStroke))
                                .lineSpacing(lineSpacingVal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, innerMargin)
                .padding(.bottom, 12)
            }
            .onChange(of: store.currentTargets[lang]) { _, _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: store.segments.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private var optionsPanel: some View {
        ScrollView(showsIndicators: true) {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("오버레이 옵션").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                Spacer()
                Button { showOptions = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(5)
                        .background(Circle().fill(Color.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
            }

            Group {
            // ── 배경 ──
            Text("배경").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 8) {
                ForEach([("OBS (완전 투명)", "obs"), ("화면공유 (배경색)", "color")], id: \.1) { item in
                    Button { bgMode = item.1 } label: {
                        Text(item.0)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(bgMode == item.1 ? Color.black : Color.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(bgMode == item.1 ? Color.white : Color.white.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("배경색").font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 12) {
                    ForEach(bgPalette, id: \.1) { item in
                        Button { bgColorHex = item.1 } label: {
                            Circle()
                                .fill(Color(hex: item.1))
                                .frame(width: 26, height: 26)
                                .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 1.5))
                                .overlay(Circle().stroke(Color.white, lineWidth: bgColorHex == item.1 ? 3 : 0))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
            .opacity(isOBS ? 0.35 : 1.0)
            sliderRow("투명도", value: $bgOpacity, range: 0.2...1.0, percent: true)
                .opacity(isOBS ? 0.35 : 1.0)

            optDivider

            // ── 번역 자막 ──
            Text("번역 자막").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
            sliderRow("크기", value: $fontSize, range: 16...56, percent: false)
            VStack(alignment: .leading, spacing: 5) {
                Text("색상").font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 12) {
                    ForEach(0..<palette.count, id: \.self) { i in
                        Button { colorIdx = i } label: {
                            Circle()
                                .fill(palette[i])
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 1.5))
                                .overlay(Circle().stroke(Color.white, lineWidth: colorIdx == i ? 3 : 0))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("굵기").font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
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
            }
            Group {
            Toggle(isOn: $textStroke) {
                Text("테두리").font(.system(size: 13)).foregroundStyle(.white)
            }
            .tint(.blue)

            optDivider

            // ── 원문 ──
            Text("원문").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
            Toggle(isOn: $showSourceOpt) {
                Text("표시").font(.system(size: 13)).foregroundStyle(.white)
            }
            .tint(.blue)

            optDivider

            // ── 레이아웃 ──
            sliderRow("줄 간격", value: $lineSpacingVal, range: 0...20, percent: false)
            sliderRow("단락 간격", value: $lineSpace, range: 0...40, percent: false)
            sliderRow("내부 여백", value: $innerMargin, range: 0...60, percent: false)
            sliderRow("창 투명도", value: $winOpacity, range: 0.2...1.0, percent: true)
            Stepper("표시 줄 수: \(lineCount)", value: $lineCount, in: 1...10)
                .foregroundStyle(.white)
            }
            Group {
            optDivider

            // 표시 언어 선택 — 청중 송출/QR/링크엔 영향 없음
            VStack(alignment: .leading, spacing: 5) {
                Text("표시 언어").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
                ForEach(store.langs, id: \.self) { lang in
                    Button { toggleLang(lang) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: hiddenSet.contains(lang) ? "square" : "checkmark.square.fill")
                                .foregroundStyle(.white.opacity(0.9))
                            Text(tag(lang)).font(.system(size: 13)).foregroundStyle(.white)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            optDivider

            // 자막 지우기 (현재 표시 + 다음 송출 비움)
            Button { store.clear() } label: {
                HStack {
                    Spacer()
                    Image(systemName: "trash")
                    Text("자막 지우기").font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(Color.red.opacity(0.9))
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            }
        }
        .padding(16)
        }
        .frame(width: 300)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.96)))
    }

    private var optDivider: some View {
        Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1).padding(.vertical, 2)
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

    // 원문(source) + 번역(target) 쌍을 최신 lineCount개만큼 (현재 진행 줄 포함)
    private func recentItems(_ lang: String) -> [(src: String, tgt: String)] {
        var arr: [(src: String, tgt: String)] = []
        for seg in store.segments {
            let t = seg.targets[lang] ?? ""
            if !t.isEmpty { arr.append((src: seg.source, tgt: t)) }
        }
        let cur = store.currentTargets[lang] ?? ""
        if !cur.isEmpty { arr.append((src: store.currentSource, tgt: cur)) }
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
