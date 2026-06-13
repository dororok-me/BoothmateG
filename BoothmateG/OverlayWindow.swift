//
//  OverlayWindow.swift
//  BoothmateG
//
//  Version: 1.5.0
//  Changelog:
//    1.0.0 - 최초 작성. 텔레프롬프터 오버레이 창
//    1.1.0 - 설정 패널 클릭 가능 hitTest, OBS 경계선, 스크롤 방향
//    1.2.0 - OBS 투명 모드 드래그 가능 (0.001 불투명 배경)
//    1.3.0 - 창 전체가 드래그 영역, 리사이즈 가장자리 20pt, 내부 여백 옵션
//    1.3.1 - 내부 여백을 상하에도 적용
//    1.3.2 - 자막이 마진/창 너비를 넘던 문제 1차 수정
//    1.4.0 - 실시간 자막이 창 하단을 침범하던 문제 근본 해결
//            (1) 실시간 자막을 확정 자막과 동일한 색/크기로 통일 (회색·축소 제거)
//            (2) 하단 고정 여백(bottomFixedMargin=28pt) 분리 — innerMargin과 무관하게
//                항상 유지되는 안전 여백
//            (3) ScrollView .clipped() — 콘텐츠가 영역 밖으로 그려지지 못하도록 명시 클리핑
//    1.5.0 - 글로서리(양방향 normalize)를 화면에 그리기 직전에 적용.
//            Gemini 번역에는 개입하지 않음(메인 콘솔/저장소는 원본 유지).
//            확정 자막·실시간 자막·인라인 수정 진입 시 모두 normalize() 통과.
//            - 번역 자막을 텔레프롬프터 형태로 표시
//            - 단어 탭 → 인라인 수정 (SubtitleStore에 즉시 반영)
//            - OBS 모드 (완전 투명) / 화면공유 모드 (배경색+투명도)
//            - 설정 패널: 글자 크기/색상/굵기/테두리, 원문 표시, 줄 간격, 배경
//            - 창 가장자리 드래그로 리사이즈, 중앙 드래그로 이동
//

import AppKit
import SwiftUI
import Combine

// MARK: - Overlay Window (borderless, floating, transparent)

class OverlayPanel: NSPanel {
    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .managed]
        minSize = NSSize(width: 300, height: 80)
        maxSize = NSSize(width: 4000, height: 2000)
        isRestorable = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
    }
    override var canBecomeKey: Bool { true }
}

// MARK: - Overlay Window Controller

// 핸들 뷰와 SwiftUI가 공유하는 UI 상태 (설정 패널 열림 여부)
@MainActor
final class OverlayUIState: ObservableObject {
    @Published var settingsOpen: Bool = false
}

@MainActor
final class OverlayWindowController {
    private var panel: OverlayPanel?
    private var hostingController: NSHostingController<OverlayContentView>?
    private let uiState = OverlayUIState()
    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle(store: SubtitleStore, glossary: GlossaryEngine, mainWindow: NSWindow?) {
        if isVisible { hide() } else { show(store: store, glossary: glossary, mainWindow: mainWindow) }
    }

    func show(store: SubtitleStore, glossary: GlossaryEngine, mainWindow: NSWindow?) {
        if panel == nil {
            let frame = NSRect(x: 100, y: 100, width: 800, height: 220)
            panel = OverlayPanel(frame: frame)

            let view = OverlayContentView(store: store, glossary: glossary, uiState: uiState, onClose: { [weak self] in
                self?.hide()
            })
            let hosting = NSHostingController(rootView: view)
            hostingController = hosting

            let container = NSView()
            container.wantsLayer = true
            container.layer?.cornerRadius = 12
            container.layer?.masksToBounds = true
            panel?.contentView = container

            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(hosting.view)
            NSLayoutConstraint.activate([
                hosting.view.topAnchor.constraint(equalTo: container.topAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                hosting.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])

            // 리사이즈+드래그 핸들 (투명 레이어)
            let handle = OverlayResizeHandle()
            // 통과 영역: 우상단 버튼(80×50) + 설정 열렸을 때 우측 패널(약 340pt)
            handle.shouldPassThrough = { [weak self] p, bounds in
                // 우상단 버튼 영역
                let btnArea = NSRect(x: bounds.width - 80, y: bounds.height - 50, width: 80, height: 50)
                if btnArea.contains(p) { return true }
                // 설정 패널 (우측, 열렸을 때만)
                if self?.uiState.settingsOpen == true {
                    let panelArea = NSRect(x: bounds.width - 340, y: 0, width: 340, height: bounds.height)
                    if panelArea.contains(p) { return true }
                }
                return false
            }
            handle.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(handle, positioned: .above, relativeTo: hosting.view)
            NSLayoutConstraint.activate([
                handle.topAnchor.constraint(equalTo: container.topAnchor),
                handle.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                handle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                handle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
        }

        // 메인 창 위에 배치
        if let mf = mainWindow?.frame {
            panel?.setFrame(NSRect(x: mf.origin.x, y: mf.origin.y + mf.height + 8,
                                   width: mf.width, height: 220), display: true)
        }
        panel?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }
}

// MARK: - Resize / Drag Handle

class OverlayResizeHandle: NSView {
    private let edgeThreshold: CGFloat = 20
    // SwiftUI로 클릭을 통과시킬지 판정 (버튼/설정 패널 영역). 컨트롤러가 주입.
    var shouldPassThrough: ((NSPoint, NSRect) -> Bool)?
    private enum Edge { case none, left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight }
    private var currentEdge: Edge = .none
    private var initialMouse: NSPoint = .zero
    private var initialFrame: NSRect = .zero
    private var isDragging = false
    private var dragOffset: NSPoint = .zero

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for a in trackingAreas { removeTrackingArea(a) }
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self))
    }

    private func edge(at p: NSPoint) -> Edge {
        let t = edgeThreshold, w = bounds.width, h = bounds.height
        let l = p.x < t, r = p.x > w - t, b = p.y < t, tp = p.y > h - t
        if tp && l { return .topLeft }; if tp && r { return .topRight }
        if b && l { return .bottomLeft }; if b && r { return .bottomRight }
        if l { return .left }; if r { return .right }
        if tp { return .top }; if b { return .bottom }
        return .none
    }

    override func mouseMoved(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        switch edge(at: local) {
        case .left, .right: NSCursor.resizeLeftRight.set()
        case .top, .bottom: NSCursor.resizeUpDown.set()
        case .topLeft, .topRight, .bottomLeft, .bottomRight: NSCursor.crosshair.set()
        case .none: NSCursor.arrow.set()
        }
    }
    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }
    override func cursorUpdate(with event: NSEvent) { }

    override func mouseDown(with event: NSEvent) {
        guard let win = self.window else { return }
        let local = convert(event.locationInWindow, from: nil)
        let e = edge(at: local)
        if e != .none {
            currentEdge = e; initialMouse = NSEvent.mouseLocation; initialFrame = win.frame; isDragging = false
        } else {
            currentEdge = .none; isDragging = true
            let sm = NSEvent.mouseLocation
            dragOffset = NSPoint(x: sm.x - win.frame.origin.x, y: sm.y - win.frame.origin.y)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let win = self.window else { return }
        if isDragging {
            let s = NSEvent.mouseLocation
            win.setFrameOrigin(NSPoint(x: s.x - dragOffset.x, y: s.y - dragOffset.y)); return
        }
        guard currentEdge != .none else { return }
        let cur = NSEvent.mouseLocation
        let dx = cur.x - initialMouse.x, dy = cur.y - initialMouse.y
        var f = initialFrame
        let mn = win.minSize, mx = win.maxSize
        func cl(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { max(lo, min(hi, v)) }
        switch currentEdge {
        case .right: f.size.width = cl(f.width + dx, mn.width, mx.width)
        case .left: let nw = cl(f.width - dx, mn.width, mx.width); f.origin.x = f.maxX - nw; f.size.width = nw
        case .top: f.size.height = cl(f.height + dy, mn.height, mx.height)
        case .bottom: let nh = cl(f.height - dy, mn.height, mx.height); f.origin.y = f.maxY - nh; f.size.height = nh
        case .topRight: f.size.width = cl(f.width + dx, mn.width, mx.width); f.size.height = cl(f.height + dy, mn.height, mx.height)
        case .topLeft: let nw = cl(f.width - dx, mn.width, mx.width); f.origin.x = f.maxX - nw; f.size.width = nw; f.size.height = cl(f.height + dy, mn.height, mx.height)
        case .bottomRight: f.size.width = cl(f.width + dx, mn.width, mx.width); let nh = cl(f.height - dy, mn.height, mx.height); f.origin.y = f.maxY - nh; f.size.height = nh
        case .bottomLeft: let nw = cl(f.width - dx, mn.width, mx.width); f.origin.x = f.maxX - nw; f.size.width = nw; let nh = cl(f.height - dy, mn.height, mx.height); f.origin.y = f.maxY - nh; f.size.height = nh
        case .none: break
        }
        win.setFrame(f, display: true)
    }

    override func mouseUp(with event: NSEvent) { currentEdge = .none; isDragging = false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local) else { return nil }
        // 가장자리: 리사이즈 인터셉트 (최우선)
        if edge(at: local) != .none { return self }
        // 버튼/설정 패널 영역: SwiftUI로 통과 (클릭 가능)
        if shouldPassThrough?(local, bounds) == true { return nil }
        // 나머지 전체 영역: 창 드래그
        return self
    }
}

// MARK: - Overlay Content View (SwiftUI)

struct OverlayContentView: View {
    @ObservedObject var store: SubtitleStore
    let glossary: GlossaryEngine            // v1.5.0: 표시 직전 글로서리 적용
    @ObservedObject var uiState: OverlayUIState
    var onClose: () -> Void

    // ── 설정 (AppStorage로 앱 종료 후에도 유지) ──
    @AppStorage("ov_bgMode")       private var bgMode: String = "obs"
    @AppStorage("ov_bgColorHex")   private var bgColorHex: String = "#0D1220"
    @AppStorage("ov_bgOpacity")    private var bgOpacity: Double = 0.7
    @AppStorage("ov_fontSize")     private var fontSize: Double = 34
    @AppStorage("ov_fontColorHex") private var fontColorHex: String = "#FBBF24"
    @AppStorage("ov_fontBold")     private var fontBold: Bool = true
    @AppStorage("ov_textStroke")   private var textStroke: Bool = true
    @AppStorage("ov_showSource")   private var showSource: Bool = false
    @AppStorage("ov_srcFontSize")  private var srcFontSize: Double = 18
    @AppStorage("ov_srcColorHex")  private var srcColorHex: String = "#CBD5E1"
    @AppStorage("ov_lineSpacing")  private var lineSpacing: Double = 8
    @AppStorage("ov_innerMargin")  private var innerMargin: Double = 20
    @AppStorage("ov_winOpacity")   private var winOpacity: Double = 1.0

    @State private var editingID: UUID? = nil
    @State private var editText: String = ""

    private var isOBS: Bool { bgMode == "obs" }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // ── 배경 ──
            Group {
                if isOBS {
                    // 완전 Color.clear면 SwiftUI가 클릭을 통과시켜 드래그 핸들이 못 받음.
                    // 0.001 불투명도면 화면상 투명하지만 클릭은 받음 → 드래그/리사이즈 가능.
                    Color.black.opacity(0.001)
                } else {
                    Color(hex: bgColorHex).opacity(bgOpacity)
                }
            }.ignoresSafeArea()

            // ── 텔레프롬프터 자막 (최신이 하단, 위로 밀려남) ──
            GeometryReader { geo in
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            LazyVStack(alignment: .leading, spacing: lineSpacing) {
                                ForEach(store.segments) { seg in
                                    overlayRow(seg).id(seg.id)
                                }
                                // 현재 진행 중 — 확정 자막과 동일한 색/크기 (글로서리 적용)
                                if !store.currentTarget.isEmpty {
                                    Text(glossary.normalize(store.currentTarget))
                                        .font(.system(size: fontSize, weight: fontBold ? .bold : .regular))
                                        .foregroundColor(Color(hex: fontColorHex))
                                        .modifier(StrokeModifier(enabled: textStroke))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, innerMargin)
                                        .id("ov_current")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, innerMargin)
                            .padding(.bottom, OverlayContentView.bottomFixedMargin)
                            .padding(.horizontal, 4)
                        }
                        .frame(width: geo.size.width, alignment: .leading)
                        .frame(minHeight: geo.size.height)
                    }
                    .clipped()
                    .onChange(of: store.segments.count) { _, _ in
                        withAnimation { proxy.scrollTo("ov_current", anchor: .bottom) }
                    }
                    .onChange(of: store.currentTarget) { _, _ in
                        proxy.scrollTo("ov_current", anchor: .bottom)
                    }
                }
            }

            // ── 드래그 핸들 표시 (상단 중앙) ──
            VStack {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 40, height: 4)
                    .padding(.top, 6)
                Spacer()
            }
            .allowsHitTesting(false)

            // ── 컨트롤 버튼 (우상단) ──
            HStack(spacing: 6) {
                Button { uiState.settingsOpen.toggle() } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.35)))
                }.buttonStyle(.plain)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.35)))
                }.buttonStyle(.plain)
            }
            .padding(10)

            // ── 설정 패널 ──
            if uiState.settingsOpen {
                settingsPanel
                    .frame(width: 320)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .padding(10)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: uiState.settingsOpen)
            }
        }
        .opacity(winOpacity)
        // OBS 모드(투명)일 때 경계선 표시 — 창 크기 조절 편의
        .overlay(
            Group {
                if isOBS {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
        )
    }

    // ── 자막 한 줄 ──
    @ViewBuilder
    private func overlayRow(_ seg: SubtitleSegment) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // 원문 (옵션)
            if showSource && !seg.sourceText.isEmpty {
                Text(seg.sourceText)
                    .font(.system(size: srcFontSize))
                    .foregroundColor(Color(hex: srcColorHex).opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, innerMargin)
            }

            // 번역 — 탭하면 수정 모드
            if editingID == seg.id {
                TextField("", text: $editText, onCommit: {
                    store.updateTarget(id: seg.id, newText: editText)
                    editingID = nil
                })
                .font(.system(size: fontSize, weight: fontBold ? .bold : .regular))
                .foregroundColor(Color(hex: fontColorHex))
                .textFieldStyle(.plain)
                .padding(.horizontal, innerMargin)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
                .onExitCommand { editingID = nil }
            } else {
                // 글로서리 적용된 텍스트를 표시 (저장소 원본은 그대로 유지)
                Text(glossary.normalize(seg.targetText))
                    .font(.system(size: fontSize, weight: fontBold ? .bold : .regular))
                    .foregroundColor(Color(hex: fontColorHex))
                    .modifier(StrokeModifier(enabled: textStroke))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, innerMargin)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        editingID = seg.id
                        // 수정 진입 시에도 글로서리 교정본을 보여줌
                        editText = glossary.normalize(seg.targetText)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ── 설정 패널 ──
    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("오버레이 설정").font(.headline)
                Spacer()
                Button { uiState.settingsOpen = false } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }

            Divider()

            // 배경
            Text("배경").font(.subheadline.weight(.semibold))
            Picker("용도", selection: $bgMode) {
                Text("OBS (완전 투명)").tag("obs")
                Text("화면공유 (배경색)").tag("share")
            }.pickerStyle(.segmented).labelsHidden()

            if !isOBS {
                sRow("배경색") { hexPicker(OverlayContentView.bgColors, selected: bgColorHex) { bgColorHex = $0 } }
                sRow("투명도") {
                    Slider(value: $bgOpacity, in: 0.1...1.0).frame(width: 120)
                    Text("\(Int(bgOpacity * 100))%").frame(width: 34).font(.caption)
                }
            }

            Divider()

            // 번역 자막
            Text("번역 자막").font(.subheadline.weight(.semibold))
            sRow("크기") {
                Slider(value: $fontSize, in: 16...80, step: 1).frame(width: 120)
                Text("\(Int(fontSize))pt").frame(width: 34).font(.caption)
            }
            sRow("색상") { hexPicker(OverlayContentView.fontColors, selected: fontColorHex) { fontColorHex = $0 } }
            sRow("굵게") { Toggle("", isOn: $fontBold).toggleStyle(.switch).controlSize(.small) }
            sRow("테두리") { Toggle("", isOn: $textStroke).toggleStyle(.switch).controlSize(.small) }

            Divider()

            // 원문
            Text("원문").font(.subheadline.weight(.semibold))
            sRow("표시") { Toggle("", isOn: $showSource).toggleStyle(.switch).controlSize(.small) }
            if showSource {
                sRow("크기") {
                    Slider(value: $srcFontSize, in: 10...40, step: 1).frame(width: 120)
                    Text("\(Int(srcFontSize))pt").frame(width: 34).font(.caption)
                }
            }

            Divider()

            // 레이아웃
            sRow("줄 간격") {
                Slider(value: $lineSpacing, in: 0...30, step: 1).frame(width: 120)
                Text("\(Int(lineSpacing))pt").frame(width: 34).font(.caption)
            }
            sRow("내부 여백") {
                Slider(value: $innerMargin, in: 0...80, step: 2).frame(width: 120)
                Text("\(Int(innerMargin))pt").frame(width: 34).font(.caption)
            }
            sRow("창 투명도") {
                Slider(value: $winOpacity, in: 0.3...1.0).frame(width: 120)
                Text("\(Int(winOpacity * 100))%").frame(width: 34).font(.caption)
            }

            Divider()

            Button { store.clear() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash").font(.caption)
                    Text("자막 지우기").font(.caption.weight(.medium))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity).padding(.vertical, 4)
            }.buttonStyle(.plain)
        }
        .padding(14)
    }

    // ── 설정 행 헬퍼 ──
    @ViewBuilder
    private func sRow<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).frame(width: 60, alignment: .leading).foregroundColor(.secondary)
            content()
        }
    }

    // ── 색상 피커 ──
    @ViewBuilder
    private func hexPicker(_ options: [(String, String)], selected: String,
                           onSelect: @escaping (String) -> Void) -> some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.1) { name, hex in
                Button { onSelect(hex) } label: {
                    ZStack {
                        Circle().fill(Color(hex: hex)).frame(width: 18, height: 18)
                            .overlay(Circle().stroke(Color.primary, lineWidth: selected == hex ? 2 : 0))
                            .shadow(radius: 1)
                        if selected == hex {
                            Image(systemName: "checkmark")
                                .font(.system(size: 6, weight: .bold))
                                .foregroundColor(hex == "#FFFFFF" ? .black : .white)
                        }
                    }
                }.buttonStyle(.plain).help(name)
            }
        }
    }

    // ── 색상 옵션 ──
    // 하단 고정 여백 — innerMargin과 별개로 항상 유지되는 안전 여백.
    // 실시간 자막이 마지막 줄에서 창 밖으로 넘쳐 보이는 현상 방지.
    static let bottomFixedMargin: CGFloat = 28

    static let fontColors: [(String, String)] = [
        ("노란색", "#FBBF24"), ("흰색", "#FFFFFF"), ("초록색", "#4ADE80"),
        ("하늘색", "#38BDF8"), ("빨간색", "#F87171"), ("분홍색", "#F472B6"),
    ]
    static let bgColors: [(String, String)] = [
        ("검정", "#000000"), ("짙은회색", "#1E293B"), ("남색", "#0D1220"),
        ("짙은파랑", "#1E3A5F"), ("짙은초록", "#064E3B"),
    ]
}

// MARK: - Text Stroke Modifier

struct StrokeModifier: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content
                .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
                .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 0)
        } else {
            content
        }
    }
}

// MARK: - Color from Hex String

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var n: UInt64 = 0
        Scanner(string: h).scanHexInt64(&n)
        self.init(
            red: Double((n >> 16) & 0xFF) / 255,
            green: Double((n >> 8) & 0xFF) / 255,
            blue: Double(n & 0xFF) / 255
        )
    }
}
