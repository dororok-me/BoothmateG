//
//  OverlayWindow.swift
//  BoothmateG
//
//  Version: 1.29.0
//  Changelog:
//    1.29.0 - 글자 테두리(그림자) 세부 조절 추가: 테두리색·굵기·그림자 흐림(설정 패널, 테두리 켜짐 시).
//             모든 창(OBS·일반·단일·다국어)에 동일 적용. StrokeModifier 확장.
//    1.28.0 - 다국어 분리 창 겹침 방지: 처음 뜰 때 cascadeIndex만큼 계단식 배치(저장 위치 있으면 그대로).
//    1.27.0 - OverlayWindowController에 langKey 추가: 빈 문자열이면 단일 언어(기존 키 그대로),
//             "en"/"ja" 등이면 위치·크기 저장 키에 접두사가 붙어 언어별 독립 저장.
//             다국어 분리 오버레이(MultiSeparateOverlayController)가 언어별 인스턴스로 사용.
//             (static 저장 키 → 인스턴스 계산 속성으로 변경. 단일 언어 동작은 100% 보존)
//    1.26.0 - 컨트롤 버튼(설정·X)을 마우스 호버 시에만 표시(설정 열림 중엔 항상). 평소엔 자막만 깔끔히.
//             상단 중앙 드래그 핸들(가로 바) 제거.
//    1.25.0 - 상단 페이드 폭 확대: 완전 불투명 도달 지점 0.18→0.32, 중간 단계 촘촘히.
//             살짝 보이며 끊기던 잔상 제거. 맨 끝단은 완전 투명.
//    1.24.0 - 상단 페이드 마스크 최초 추가.
//             세그먼트가 수백 개로 누적될 때 오버레이 렌더링 과부하로 앱이 다운되던 문제 대응.
//             (전사문에는 전체가 저장되므로 통역 기록은 온전)
//    1.22.0 - 표시용 후처리 클로저(displayPolish) 추가: ContentView가 polish(용어집+단위+환율)를
//             넘기면 오버레이 확정/진행 자막에도 환산이 붙음(화면·청중과 통일). 편집 진입은 미적용.
//             show/toggle에 displayPolish 파라미터(기본 nil → 기존 동작 보존).
//    1.21.0 - 외부 디스플레이 복원 견고화: 디스플레이 고유 ID(CGDirectDisplayID)+모니터 내 상대 위치 저장.
//             같은 모니터를 찾아 복원, 없으면 절대좌표→메인화면 폴백. 이동/리사이즈마다 저장(크래시 대비).
//    1.20.0 - 오버레이 창 위치·크기 기억(setFrameAutosaveName): 이동/리사이즈 시 자동 저장,
//             앱 재시작·복구 시 마지막 위치 복원. 최초만 메인 창 위 배치. 화면 밖이면 안전망으로 복귀.
//    1.19.1 - 단어 간격을 진행 중 자막에도 적용(EditableSubtitleText wordSpacing 전달) → 확정/진행 일관.
//    1.19.0 - 단어 사이 간격(공백 폭) 조절 추가: 설정에 "단어 간격" 슬라이더(공백에만 kern 적용, 자간 불변). 확정 자막에 적용.
//    1.18.0 - 배경색 옵션을 폰트 색상과 동일 구성으로(노랑/흰/검정/초록/하늘/빨강/분홍).
//    1.17.0 - 폰트 색상에 검정(#000000) 추가(밝은 배경/화면 공유용).
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

    // v1.27.0: 언어 식별자. 빈 문자열="" → 단일 언어(기존 키 그대로). "en"/"ja" 등 → 다국어 분리 창.
    //  이 값에 따라 위치 저장 키에 접두사가 붙어, 언어별로 창 위치·크기를 독립 저장한다.
    var langKey: String = ""

    // v1.28.0: 다국어 분리 창이 처음 뜰 때 겹치지 않도록 순번만큼 어긋나게 배치(계단식).
    //  저장된 위치가 있으면 무시되고 그 위치로 복원됨. 단일 언어(0)는 영향 없음.
    var cascadeIndex: Int = 0

    init(langKey: String = "") {
        self.langKey = langKey
    }

    func toggle(store: SubtitleStore, glossary: GlossaryEngine, mainWindow: NSWindow?, displayPolish: ((String) -> String)? = nil) {
        if isVisible { hide() } else { show(store: store, glossary: glossary, mainWindow: mainWindow, displayPolish: displayPolish) }
    }

    func show(store: SubtitleStore, glossary: GlossaryEngine, mainWindow: NSWindow?, displayPolish: ((String) -> String)? = nil) {
        var didCreate = false
        var restoredFrame = false
        if panel == nil {
            didCreate = true
            let frame = NSRect(x: 100, y: 100, width: 800, height: 220)
            panel = OverlayPanel(frame: frame)

            let view = OverlayContentView(store: store, glossary: glossary, uiState: uiState, onClose: { [weak self] in
                self?.hide()
            }, displayPolish: displayPolish, langKey: langKey)
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

            // 마지막 위치·크기 복원: ① 디스플레이 ID 기반(외부 출력 견고) → ② 절대좌표 폴백.
            restoredFrame = restoreFrameByDisplay()              // 같은 모니터 찾아 복원
            if !restoredFrame {
                restoredFrame = panel?.setFrameUsingName(frameAutosaveName) ?? false  // 폴백: 절대좌표
            }
            panel?.setFrameAutosaveName(frameAutosaveName)  // 이후 이동/리사이즈 자동 저장(절대좌표)

            // 크래시 대비: 닫기를 못 거치고 앱이 다운돼도 마지막 모니터·위치가 남도록
            // 이동/리사이즈가 일어날 때마다 디스플레이 정보 저장.
            if let p = panel {
                NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: p, queue: .main) { [weak self] _ in
                    self?.saveFrameByDisplay()
                }
                NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: p, queue: .main) { [weak self] _ in
                    self?.saveFrameByDisplay()
                }
            }
        }

        // 창을 처음 만들 때만 위치 배치: 저장된 위치가 있으면 그대로, 없으면 메인 창 위.
        // v1.28.0: 다국어 분리 창이 여러 개면 cascadeIndex만큼 계단식으로 어긋나게(겹침 방지).
        if didCreate, !restoredFrame, let mf = mainWindow?.frame {
            let step: CGFloat = 240   // 창 사이 가로/세로 어긋남 간격
            let dx = CGFloat(cascadeIndex) * step
            let dy = CGFloat(cascadeIndex) * 60
            panel?.setFrame(NSRect(x: mf.origin.x + dx,
                                   y: mf.origin.y + mf.height + 8 - dy,
                                   width: mf.width, height: 220), display: true)
        }

        // 안전망: 복원된 위치가 모든 화면 밖이면(모니터 분리 등) 보이는 화면으로 끌어옴.
        if didCreate, let p = panel,
           !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(p.frame) }) {
            let target = mainWindow?.frame ?? (NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 800, height: 220))
            panel?.setFrame(NSRect(x: target.origin.x, y: target.origin.y,
                                   width: min(800, target.width), height: 220), display: true)
        }

        panel?.makeKeyAndOrderFront(nil)
    }

    // 창 위치·크기 자동 저장 이름 (UserDefaults에 "NSWindow Frame {이름}"으로 저장됨)
    // v1.27.0: langKey가 있으면 언어별로 분리("..._en" 등). 단일 언어(빈 키)는 기존 이름 그대로.
    private var suffix: String { langKey.isEmpty ? "" : "_\(langKey)" }
    private var frameAutosaveName: String { "BoothmateGOverlayFrame\(suffix)" }
    // 디스플레이 ID 기반 저장 키
    private var dispKey: String { "ov_overlayDisplayID\(suffix)" }   // 마지막으로 있던 모니터 고유 ID
    private var relKey: String  { "ov_overlayRelFrame\(suffix)" }    // 그 모니터 안에서의 상대 위치/크기 "x,y,w,h"

    // 현재 창이 놓인 화면의 디스플레이 ID + 모니터 내 상대 프레임을 저장.
    //  창을 닫을 때 호출 → 재시작/다운 후에도 "그 모니터"에 그대로 복원.
    private func saveFrameByDisplay() {
        guard let p = panel, let scr = p.screen ?? screenContaining(p.frame) else { return }
        guard let sid = displayID(of: scr) else { return }
        let sf = scr.frame
        // 모니터 원점 기준 상대 좌표(모니터가 어디 붙든 동일하게 복원되도록)
        let rx = p.frame.origin.x - sf.origin.x
        let ry = p.frame.origin.y - sf.origin.y
        let rel = "\(rx),\(ry),\(p.frame.width),\(p.frame.height)"
        UserDefaults.standard.set(Int(sid), forKey: dispKey)
        UserDefaults.standard.set(rel, forKey: relKey)
    }

    // 저장된 디스플레이 ID와 같은 모니터를 찾아, 그 안의 상대 위치로 복원. 성공 시 true.
    private func restoreFrameByDisplay() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: dispKey) != nil,
              let rel = defaults.string(forKey: relKey) else { return false }
        let savedID = UInt32(defaults.integer(forKey: dispKey))
        // 같은 ID의 모니터가 현재 연결돼 있는지
        guard let scr = NSScreen.screens.first(where: { displayID(of: $0) == savedID }) else {
            return false   // 그 모니터 없음 → 폴백
        }
        let parts = rel.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4 else { return false }
        let sf = scr.frame
        let f = NSRect(x: sf.origin.x + parts[0], y: sf.origin.y + parts[1],
                       width: parts[2], height: parts[3])
        panel?.setFrame(f, display: true)
        return true
    }

    // NSScreen → CGDirectDisplayID (모니터 고유 식별자)
    private func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }

    // 프레임 중심이 포함된 화면(없으면 nil)
    private func screenContaining(_ frame: NSRect) -> NSScreen? {
        let c = NSPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { $0.frame.contains(c) }
    }

    func hide() {
        saveFrameByDisplay()   // 닫기 직전 "어느 모니터에 있었는지" 저장
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
    // v1.22.0: 표시용 후처리(단위·환율 변환 등). 기본값은 변환 없음(빈 클로저면 입력 그대로).
    //          ContentView가 polish를 넘기면 화면·청중과 동일하게 환산이 붙음. 편집 진입에는 미적용.
    var displayPolish: ((String) -> String)? = nil
    // v1.28.0: 언어 식별자. 다국어 분리 창이면 "en"/"ja" 등 → 호버 시 우상단에 언어 라벨 표시.
    //          단일 언어 창은 빈 문자열 → 라벨 미표시.
    var langKey: String = ""

    // ── 설정 (AppStorage로 앱 종료 후에도 유지) ──
    @AppStorage("ov_bgMode")       private var bgMode: String = "obs"
    @AppStorage("ov_bgColorHex")   private var bgColorHex: String = "#0D1220"
    @AppStorage("ov_bgOpacity")    private var bgOpacity: Double = 0.7
    @AppStorage("ov_fontSize")     private var fontSize: Double = 34
    @AppStorage("ov_fontColorHex") private var fontColorHex: String = "#FBBF24"
    @AppStorage("ov_fontBold")     private var fontBold: Bool = true
    @AppStorage("ov_textStroke")   private var textStroke: Bool = true
    // v1.29.0: 글자 테두리(그림자) 세부 설정 — 어떤 창에서도 조절 가능
    @AppStorage("ov_strokeColorHex") private var strokeColorHex: String = "#000000"  // 테두리 색
    @AppStorage("ov_strokeWidth")    private var strokeWidth: Double = 1.0           // 굵기(번짐 크기)
    @AppStorage("ov_strokeBlur")     private var strokeBlur: Double = 3.0            // 그림자 흐림(부드러운 번짐)
    @AppStorage("ov_showSource")   private var showSource: Bool = false
    @AppStorage("ov_srcFontSize")  private var srcFontSize: Double = 18
    @AppStorage("ov_srcColorHex")  private var srcColorHex: String = "#CBD5E1"
    @AppStorage("ov_lineSpacing")  private var lineSpacing: Double = 8        // 단락(세그먼트) 사이 간격
    @AppStorage("ov_textLineSpacing") private var textLineSpacing: Double = 2 // 줄 간격(한 문단 내 줄 높이)
    @AppStorage("ov_wordSpacing")  private var wordSpacing: Double = 3        // 단어 사이 간격(공백 폭)
    @AppStorage("ov_innerMargin")  private var innerMargin: Double = 20
    @AppStorage("ov_winOpacity")   private var winOpacity: Double = 1.0

    @State private var editingID: UUID? = nil
    @State private var editText: String = ""
    @State private var isCurrentEditing: Bool = false   // v1.15.0: 진행 중 자막 편집 중 여부
    @State private var committedEditID: UUID? = nil      // v1.15.0: 더블클릭 순간 확정된 세그먼트 id
    @State private var isHovering: Bool = false          // v1.26.0: 마우스 호버 시에만 컨트롤 버튼 표시

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
                                // v1.23.0: 긴 세션에서 세그먼트가 수백 개로 쌓이면 렌더링 과부하로
                                //          다운될 수 있어, 화면에는 최근 80개만 표시(기록 전사문은 전체 저장).
                                ForEach(store.segments.suffix(80)) { seg in
                                    overlayRow(seg).id(seg.id)
                                }
                                // 현재 진행 중 자막 (글로서리 적용)
                                // v1.15.0: 진행 중 자막도 단어를 더블클릭하면 그 단어가 블록 선택된 채
                                //          바로 수정 가능(확정 자막과 동일). 더블클릭 순간 내부적으로 확정시켜
                                //          이후 글자 늘어남이 수정창에 영향 없게 함.
                                if !store.currentTarget.isEmpty {
                                    EditableSubtitleText(
                                        text: (displayPolish ?? glossary.normalize)(store.currentTarget),
                                        fontSize: fontSize,
                                        bold: fontBold,
                                        color: Color(hex: fontColorHex),
                                        wordSpacing: CGFloat(4 + wordSpacing),   // 확정 자막 단어 간격과 비슷하게
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
                                    .modifier(StrokeModifier(enabled: textStroke, colorHex: strokeColorHex, width: strokeWidth, blur: strokeBlur))
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
                    // v1.25.0: 상단 페이드 마스크. 페이드 구간을 넓혀(완전 불투명 도달 0.18→0.32)
                    //          위로 갈수록 더 길게 서서히 사라지게 → 끊겨 보이던 잔상 제거.
                    //          맨 끝단(0.0)은 완전 투명(.clear)으로 확실히 사라짐.
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear,                location: 0.0),
                                .init(color: .black.opacity(0.05),  location: 0.08),
                                .init(color: .black.opacity(0.25),  location: 0.16),
                                .init(color: .black.opacity(0.6),   location: 0.24),
                                .init(color: .black,                location: 0.32),
                                .init(color: .black,                location: 1.0)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .onChange(of: store.segments.count) { _, _ in
                        if !isCurrentEditing { withAnimation { proxy.scrollTo("ov_current", anchor: .bottom) } }
                    }
                    .onChange(of: store.currentTarget) { _, _ in
                        if !isCurrentEditing { proxy.scrollTo("ov_current", anchor: .bottom) }
                    }
                }
            }

            // ── 설정 열렸을 때: 패널 바깥 클릭 → 패널 닫고 전체 자막 화면으로 ──
            if uiState.settingsOpen {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { uiState.settingsOpen = false }
            }

            // ── 컨트롤 버튼 (우상단) — v1.26.0: 마우스 호버 시에만 표시 ──
            HStack(spacing: 6) {
                // v1.28.0: 다국어 분리 창이면 언어 라벨 표시(어느 언어 창인지 식별). 단일 창은 미표시.
                if !langKey.isEmpty {
                    Text(Self.langDisplay(langKey))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.black.opacity(0.45)))
                }

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
            // v1.26.0: 호버 또는 설정 열림일 때만 보이게(평소엔 자막만 깔끔히)
            .opacity((isHovering || uiState.settingsOpen) ? 1 : 0)
            .animation(.easeInOut(duration: 0.18), value: isHovering)
            .animation(.easeInOut(duration: 0.18), value: uiState.settingsOpen)

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
        // v1.26.0: 마우스가 창 위에 있는 동안만 컨트롤 버튼 표시
        .onHover { hovering in
            isHovering = hovering
        }
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
                Text(spacedAttr((displayPolish ?? glossary.normalize)(seg.targetText)))
                    .font(.system(size: fontSize, weight: fontBold ? .bold : .regular))
                    .foregroundColor(Color(hex: fontColorHex))
                    .modifier(StrokeModifier(enabled: textStroke, colorHex: strokeColorHex, width: strokeWidth, blur: strokeBlur))
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

    // 단어 사이(공백)에만 간격을 적용한 AttributedString 생성.
    //  공백 문자에 kern을 줘서 단어 사이만 넓힘(자간은 그대로). wordSpacing<=0이면 원본.
    private func spacedAttr(_ s: String) -> AttributedString {
        guard wordSpacing > 0 else { return AttributedString(s) }
        var result = AttributedString("")
        for ch in s {
            var piece = AttributedString(String(ch))
            if ch == " " { piece.kern = CGFloat(wordSpacing) }   // 공백 뒤 간격 추가
            result.append(piece)
        }
        return result
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
            // v1.29.0: 테두리(그림자) 세부 조절 — 켜져 있을 때만 표시
            if textStroke {
                sRow("테두리색") { hexPicker(OverlayContentView.fontColors, selected: strokeColorHex) { strokeColorHex = $0 } }
                sRow("테두리 굵기") {
                    Slider(value: $strokeWidth, in: 0.5...6, step: 0.5).frame(width: 120)
                    Text(String(format: "%.1f", strokeWidth)).frame(width: 34).font(.caption)
                }
                sRow("그림자") {
                    Slider(value: $strokeBlur, in: 0...12, step: 0.5).frame(width: 120)
                    Text(String(format: "%.1f", strokeBlur)).frame(width: 34).font(.caption)
                }
            }

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
            sRow("단어 간격") {
                Slider(value: $wordSpacing, in: 0...20, step: 1).frame(width: 120)
                Text("\(Int(wordSpacing))pt").frame(width: 34).font(.caption)
            }
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

    // v1.28.0: 언어 코드 → 라벨 표시명 (다국어 분리 창의 우상단 라벨용)
    static func langDisplay(_ code: String) -> String {
        let map: [String: String] = [
            "ko": "한국어", "en": "English", "ja": "日本語",
            "zh-Hans": "简体中文", "zh-Hant": "繁體中文",
            "es": "Español", "fr": "Français", "de": "Deutsch", "it": "Italiano",
            "pt-BR": "Português", "pt-PT": "Português", "ru": "Русский",
            "vi": "Tiếng Việt", "th": "ไทย", "id": "Indonesia", "ar": "العربية"
        ]
        return map[code] ?? code.uppercased()
    }

    static let fontColors: [(String, String)] = [
        ("노란색", "#FBBF24"), ("흰색", "#FFFFFF"), ("검정", "#000000"),
        ("초록색", "#4ADE80"), ("하늘색", "#38BDF8"), ("빨간색", "#F87171"),
        ("분홍색", "#F472B6"),
    ]
    // 배경색: 폰트 색상과 동일한 구성(밝은 배경+검정 글자 등 자유 조합 가능)
    static let bgColors: [(String, String)] = [
        ("노란색", "#FBBF24"), ("흰색", "#FFFFFF"), ("검정", "#000000"),
        ("초록색", "#4ADE80"), ("하늘색", "#38BDF8"), ("빨간색", "#F87171"),
        ("분홍색", "#F472B6"),
    ]
}

// MARK: - Text Stroke Modifier

struct StrokeModifier: ViewModifier {
    let enabled: Bool
    // v1.29.0: 색·굵기·흐림 조절. 기본값은 기존 동작(검정, 가는 그림자)과 유사.
    var colorHex: String = "#000000"
    var width: Double = 1.0     // 굵기: 사방으로 퍼지는 정도
    var blur: Double = 3.0      // 흐림: 그림자 번짐 반경

    func body(content: Content) -> some View {
        if enabled {
            let c = Color(hex: colorHex)
            let w = CGFloat(width)
            let b = CGFloat(blur)
            // 사방 그림자로 두께감(굵기)을 만들고, blur로 번짐의 부드러움을 조절.
            content
                .shadow(color: c.opacity(0.9), radius: b * 0.4, x:  w, y:  w)
                .shadow(color: c.opacity(0.9), radius: b * 0.4, x: -w, y: -w)
                .shadow(color: c.opacity(0.9), radius: b * 0.4, x:  w, y: -w)
                .shadow(color: c.opacity(0.9), radius: b * 0.4, x: -w, y:  w)
                .shadow(color: c.opacity(0.6), radius: b, x: 0, y: 0)
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
