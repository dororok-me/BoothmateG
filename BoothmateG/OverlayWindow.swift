//
//  OverlayWindow.swift
//  BoothmateG
//
//  Version: 1.16.0
//  Changelog:
//    1.16.0 - 가장자리/코너 리사이즈 커서가 잘 안 바뀌던 문제 수정: tracking area에 .cursorUpdate 추가,
//             커서 설정을 applyCursor()로 통합해 mouseMoved/cursorUpdate 양쪽에서 적용
//             (비활성 창에서 mouseMoved가 잘 안 오던 문제 해결).
//    1.15.0 - 진행 중(인식 중) 자막도 단어를 더블클릭하면 그 단어가 블록 선택된 채 바로 수정.
//             (확정 자막과 동일한 EditableSubtitleText 방식. 더블클릭 순간 내부 확정 → 글자 튐 없음)
//             편집 중에는 자동 스크롤 일시정지(isCurrentEditing).
//    1.13.0 - 가장자리 리사이즈 영역 35→6pt로 축소(상단 버튼 침범 방지), 코너만 14pt 고정.
//    1.12.0 - 코너 리사이즈 커서를 진짜 대각선(↖↘ / ↗↙)으로 표시(시스템 커서 사용, 폴백 포함).
//             코너 감지 영역을 가장자리 두께의 1.6배로 넓혀 꺾인 곳에서 잘 잡히게 함.
//    1.11.0 - 가장자리 리사이즈 감지 영역 20→35pt 확대, 코너 커서 좌우/상하로 구분.
//    1.10.0 - 설정 패널 스크롤 막대 항상 표시(.scrollIndicators(.visible)).
//             설정 열렸을 때 hitTest 통과를 가장자리 리사이즈보다 우선 → 창 어디든
//             패널 바깥 클릭 시 설정이 확실히 닫히도록 수정.
//    1.9.0 - 줄 간격을 실제 .lineSpacing()으로 적용(한 문단 내 줄 높이, 카라오케 줄 포함).
//            기존 "줄 간격"(세그먼트 사이)은 "단락 간격"으로 명칭 변경 + 별도 유지.
//    1.6.0 - 설정 패널이 열려 있을 때 패널 바깥을 클릭하면 닫히고
//            전체 자막 화면으로 돌아가도록 처리 (바깥 클릭 닫기 레이어 추가).
//    1.8.2 - 설정 패널을 열어도 창 높이가 패널 높이만큼 늘어나던 문제 수정:\n//            호스팅 뷰 sizingOptions=[]로 창 크기 잠금 + 설정 패널 내부 스크롤.\n//    1.8.1 - 카라오케 드립: 등장 방향 왼쪽→오른쪽으로 변경, 완료 시 간격 변화 제거
//            (단어 사이/줄 간격을 확정 자막과 동일하게 맞춤).
//    1.8.0 - 단일 언어 진행 자막을 카라오케(드립) 방식으로: 새 단어가 하나씩 등장.
//            (KaraokeCurrentLine + FlowLayout 추가)
//    1.7.0 - 창 어디든 더블클릭하면 화면 전체로 확대(다시 더블클릭하면 원래 크기 복원).
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
            // 콘텐츠의 고유 크기가 창 크기를 바꾸지 못하게 잠금
            // (설정 패널을 열어도 창이 패널 높이만큼 늘어나던 문제 방지)
            hosting.sizingOptions = []
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
                // 설정 패널이 열려 있으면 창 전체를 SwiftUI로 통과시킨다.
                // (패널 바깥 아무 곳이나 클릭하면 SwiftUI의 '닫기 레이어'가 받아 패널을 닫음)
                if self?.uiState.settingsOpen == true { return true }
                // 우상단 버튼 영역
                let btnArea = NSRect(x: bounds.width - 80, y: bounds.height - 50, width: 80, height: 50)
                if btnArea.contains(p) { return true }
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
    private let edgeThreshold: CGFloat = 6
    // SwiftUI로 클릭을 통과시킬지 판정 (버튼/설정 패널 영역). 컨트롤러가 주입.
    var shouldPassThrough: ((NSPoint, NSRect) -> Bool)?
    private enum Edge { case none, left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight }
    private var currentEdge: Edge = .none
    private var initialMouse: NSPoint = .zero
    private var initialFrame: NSRect = .zero
    private var isDragging = false
    private var dragOffset: NSPoint = .zero
    private var savedFrame: NSRect? = nil   // 전체 보기 전 원래 크기

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for a in trackingAreas { removeTrackingArea(a) }
        // v1.16.0: .cursorUpdate 추가 — 비활성 창에서도 가장자리 커서가 안정적으로 바뀌게.
        addTrackingArea(NSTrackingArea(rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect],
            owner: self))
    }

    private func edge(at p: NSPoint) -> Edge {
        let t = edgeThreshold, w = bounds.width, h = bounds.height
        // 코너는 가장자리보다 약간 넓게(14pt) → 꺾인 곳에서 대각선 커서가 잡히되, 버튼 영역은 침범 안 함
        let ct: CGFloat = 14
        let l = p.x < t, r = p.x > w - t, b = p.y < t, tp = p.y > h - t
        let cl = p.x < ct, cr = p.x > w - ct, cb = p.y < ct, ctp = p.y > h - ct
        if ctp && cl { return .topLeft }; if ctp && cr { return .topRight }
        if cb && cl { return .bottomLeft }; if cb && cr { return .bottomRight }
        if l { return .left }; if r { return .right }
        if tp { return .top }; if b { return .bottom }
        return .none
    }

    override func mouseMoved(with event: NSEvent) {
        applyCursor(at: convert(event.locationInWindow, from: nil))
    }

    // v1.16.0: 커서 설정을 공통 메서드로. mouseMoved와 cursorUpdate 양쪽에서 호출.
    private func applyCursor(at local: NSPoint) {
        switch edge(at: local) {
        case .left, .right:
            NSCursor.resizeLeftRight.set()
        case .top, .bottom:
            NSCursor.resizeUpDown.set()
        case .topLeft, .bottomRight:
            // ↖↘ 대각선 (없으면 좌우 커서로 폴백)
            OverlayResizeHandle.diagonalNWSE.set()
        case .topRight, .bottomLeft:
            // ↗↙ 대각선 (없으면 상하 커서로 폴백)
            OverlayResizeHandle.diagonalNESW.set()
        case .none:
            NSCursor.arrow.set()
        }
    }

    // ── 대각선 리사이즈 커서 (macOS 시스템 커서 사용; 실패 시 폴백) ──
    // 공개 API에는 대각선 커서가 없어 시스템 프레임워크의 비공개 셀렉터를 안전하게 시도한다.
    // 다국어 오버레이(.resizable 기본 창)는 OS가 자동으로 이 커서를 보여주므로, 단일 창도 동일하게 맞춤.
    static let diagonalNWSE: NSCursor = makeDiagonalCursor(
        selector: "_windowResizeNorthWestSouthEastCursor",
        fallback: NSCursor.resizeLeftRight)
    static let diagonalNESW: NSCursor = makeDiagonalCursor(
        selector: "_windowResizeNorthEastSouthWestCursor",
        fallback: NSCursor.resizeUpDown)

    private static func makeDiagonalCursor(selector name: String, fallback: NSCursor) -> NSCursor {
        let sel = NSSelectorFromString(name)
        if NSCursor.responds(to: sel),
           let obj = NSCursor.perform(sel)?.takeUnretainedValue() as? NSCursor {
            return obj
        }
        return fallback
    }
    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }
    // v1.16.0: 시스템이 커서 갱신을 요청할 때(비활성 창에서도 호출됨)도 동일하게 적용.
    override func cursorUpdate(with event: NSEvent) {
        applyCursor(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseDown(with event: NSEvent) {
        guard let win = self.window else { return }
        // 더블클릭(어디든) → 전체 보기 토글
        if event.clickCount == 2 {
            toggleFullView()
            currentEdge = .none; isDragging = false
            return
        }
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

    // 화면 전체로 확대 ↔ 원래 크기 복원
    private func toggleFullView() {
        guard let win = self.window,
              let screen = win.screen ?? NSScreen.main else { return }
        if let saved = savedFrame {
            win.setFrame(saved, display: true, animate: true)
            savedFrame = nil
        } else {
            savedFrame = win.frame
            win.setFrame(screen.visibleFrame, display: true, animate: true)
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
        // 통과 영역(설정 열림/우상단 버튼)은 최우선으로 SwiftUI에 넘긴다.
        // (가장자리 리사이즈보다 먼저 판정 → 설정 열렸을 때 창 어디를 클릭해도 '바깥 클릭 닫기'가 동작)
        if shouldPassThrough?(local, bounds) == true { return nil }
        // 가장자리: 리사이즈 인터셉트
        if edge(at: local) != .none { return self }
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
    @AppStorage("ov_lineSpacing")  private var lineSpacing: Double = 8        // 단락(세그먼트) 사이 간격
    @AppStorage("ov_textLineSpacing") private var textLineSpacing: Double = 2 // 줄 간격(한 문단 내 줄 높이)
    @AppStorage("ov_innerMargin")  private var innerMargin: Double = 20
    @AppStorage("ov_winOpacity")   private var winOpacity: Double = 1.0

    @State private var editingID: UUID? = nil
    @State private var editText: String = ""
    @State private var isCurrentEditing: Bool = false   // v1.15.0: 진행 중 자막 편집 중 여부
    @State private var committedEditID: UUID? = nil      // v1.15.0: 더블클릭 순간 확정된 세그먼트 id

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
                                // 현재 진행 중 자막 (글로서리 적용)
                                // v1.15.0: 진행 중 자막도 단어를 더블클릭하면 그 단어가 블록 선택된 채
                                //          바로 수정 가능(확정 자막과 동일). 더블클릭 순간 내부적으로 확정시켜
                                //          이후 글자 늘어남이 수정창에 영향 없게 함.
                                if !store.currentTarget.isEmpty {
                                    EditableSubtitleText(
                                        text: glossary.normalize(store.currentTarget),
                                        fontSize: fontSize,
                                        bold: fontBold,
                                        color: Color(hex: fontColorHex),
                                        isEditing: $isCurrentEditing,
                                        onCommit: { newText in
                                            // 더블클릭 순간 확정해 둔 세그먼트에 수정 내용 반영
                                            if let id = committedEditID {
                                                store.updateTarget(id: id, newText: newText)
                                            }
                                            committedEditID = nil
                                        },
                                        onBeginEdit: {
                                            // 더블클릭하는 순간 진행 중 자막을 확정 → 글자 늘어남 멈춤.
                                            // 팝오버가 먼저 뜨도록 다음 런루프에서 확정(뷰 사라짐으로 인한 팝오버 닫힘 방지).
                                            DispatchQueue.main.async {
                                                committedEditID = store.commitCurrentForEditing()
                                            }
                                        }
                                    )
                                    .modifier(StrokeModifier(enabled: textStroke))
                                    .lineSpacing(textLineSpacing)
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
                        if !isCurrentEditing { withAnimation { proxy.scrollTo("ov_current", anchor: .bottom) } }
                    }
                    .onChange(of: store.currentTarget) { _, _ in
                        if !isCurrentEditing { proxy.scrollTo("ov_current", anchor: .bottom) }
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

            // ── 설정 열렸을 때: 패널 바깥 클릭 → 패널 닫고 전체 자막 화면으로 ──
            if uiState.settingsOpen {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { uiState.settingsOpen = false }
            }

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

            // ── 설정 패널 (창 높이를 넘으면 내부 스크롤; 창 크기는 그대로 유지) ──
            if uiState.settingsOpen {
                ScrollView {
                    settingsPanel
                }
                .scrollIndicators(.visible)   // 스크롤 막대 항상 표시
                .frame(width: 320)
                .frame(maxHeight: .infinity)
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
                    .lineSpacing(textLineSpacing)
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
                Slider(value: $textLineSpacing, in: 0...20, step: 1).frame(width: 120)
                Text("\(Int(textLineSpacing))pt").frame(width: 34).font(.caption)
            }
            sRow("단락 간격") {
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

// MARK: - 카라오케(드립) 현재 줄  [v1.8.0]
// 진행 중 번역(currentTarget)을 단어 단위로 쪼개, 새로 들어온 단어가
// 하나씩 왼쪽→오른쪽으로 슬라이드+페이드되며 등장한다. 줄바꿈은 KaraokeFlowLayout이 처리.
// 단어 사이 공백/줄간격은 확정 자막(평범한 Text)과 동일하게 맞춰, 완료 시 간격이 변하지 않음.
struct KaraokeCurrentLine: View {
    let text: String
    let fontSize: Double
    let bold: Bool
    let color: Color
    let stroke: Bool
    var lineSpacing: CGFloat = 0

    private var words: [String] {
        text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    }

    var body: some View {
        // spacing은 0으로 두고 각 단어에 실제 공백을 붙여 일반 Text와 동일한 간격 재현. 줄 높이만 lineSpacing 반영.
        KaraokeFlowLayout(spacing: 0, lineSpacing: lineSpacing) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                Text(word + " ")
                    .font(.system(size: fontSize, weight: bold ? .bold : .regular))
                    .foregroundColor(color)
                    .modifier(StrokeModifier(enabled: stroke))
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(x: -fontSize * 0.5)),
                        removal: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.22), value: words.count)
    }
}

// MARK: - 단어 흐름 레이아웃 (자동 줄바꿈)  [v1.8.0]
// 단어 뷰들을 가로로 배치하다 폭을 넘으면 다음 줄로 내린다.
// (프로젝트에 이미 있는 FlowLayout과 충돌을 피하려 별도 이름 사용)
struct KaraokeFlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x + sz.width > maxWidth && x > 0 {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += sz.width + spacing
            lineHeight = max(lineHeight, sz.height)
            widest = max(widest, x - spacing)
        }
        let totalH = y + lineHeight
        return CGSize(width: maxWidth == .infinity ? widest : maxWidth, height: totalH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, lineHeight: CGFloat = 0
        for sv in subviews {
            let sz = sv.sizeThatFits(.unspecified)
            if x - bounds.minX + sz.width > maxWidth && x > bounds.minX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            lineHeight = max(lineHeight, sz.height)
        }
    }
}
