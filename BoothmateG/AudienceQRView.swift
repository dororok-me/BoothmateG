//
//  AudienceQRView.swift
//  BoothmateG
//
//  Version: 2.2.0
//  Changelog:
//    2.2.0 - 파인더 cornerWidth/Height 극대화(2.1→2.8)로 완전히 둥글게(거의 원형).
//            점 inset 5%→3%로 줄여 더 큰 동그란 원 패턴으로 심플함 강조.
//            길거리 현수막 스타일 QR 완성. 테마색·인식률 유지.
//    2.1.0 - 파인더 cornerWidth/Height 증가(1.8→2.1, 1.2→1.5, 0.8→1.0)로 더 둥근 느낌.
//            인식률 유지하며 길거리 현수막 스타일 QR에 가깝게 시각화. 테마색 추출·자동 어둡게 보정 유지.
//    2.0.0 - 위쪽 띠 로고(logoPath)에서 테마색 자동 추출 → QR 데이터 점·파인더 색에 적용
//            (밝으면 인식 위해 자동으로 어둡게 보정, 로고 없으면 기본 진한 파랑).
//            파인더 더 둥글게 + 파인더는 테마색을 살짝 더 진하게(포인트). 가운데 앱 로고는 색과 무관.
//    1.8.0 - 디자인 QR: 둥근 점 + 둥근 모서리(파인더) + 브랜드 그라데이션(파랑→초록).
//            중앙 로고는 넣으면 표시(둥근 흰 배경), 안 넣으면 QR만. 오류정정 H 유지.
//    1.3.0 - 중앙 그림 300 → 200px로 축소(스캔이 안 되던 문제 해결).
//    1.4.0 - QR 렌더링을 공용 함수로 분리 + BroadcastQRView(세션 QR 빠른보기) 추가.
//    1.5.0 - 그림(로고/중앙)을 앱 저장소로 복사해 원본이 사라져도 유지. 세션 삭제 시 저장 QR 파일도 제거.
//    1.6.0 - 세션 삭제/전체 초기화 시 서버(RTDB) 데이터까지 삭제(링크 무효화) + 확인 알림.
//    1.7.0 - 삭제 호출을 FirebaseRelay.shared.deleteSession으로 변경(인증 토큰 사용, 규칙 잠금 대응).
//
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import CoreImage
import CoreImage.CIFilterBuiltins

// 청중 페이지 주소 (Firebase Hosting에 올릴 sub.html). 본인 도메인으로 수정하세요.
enum AudienceConfig {
    static let baseURL = "https://dororokrealtimespeech.web.app/sub.html"
    static func link(_ sessionID: String) -> String { "\(baseURL)?s=\(sessionID)" }
}

// 세션 1개 = QR 1개 = 고정 링크 1개
struct QRSession: Identifiable, Codable, Hashable {
    var id: String = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10)).lowercased()
    var date: String = ""   // 예: "6월 15일"
    var name: String = ""   // 예: "개회식"
}

struct QREvent: Codable, Equatable {
    var name: String = ""            // 행사명
    var logoPath: String = ""        // 청중 페이지 상단 로고 (2단계 업로드용)
    var centerImagePath: String = "" // QR 가운데 들어갈 그림
    var sessions: [QRSession] = []
}

struct AudienceQRView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("audienceQREventJSON") private var eventJSON: String = ""

    @State private var event = QREvent()
    @State private var selectedSessionID: String? = nil
    @State private var pendingDelete: QRSession? = nil
    @State private var showResetConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("청중용 자막 QR").font(.title3).bold()
                Spacer()
                Button(role: .destructive) { showResetConfirm = true } label: {
                    Label("전체 초기화", systemImage: "trash")
                }
                .disabled(event.sessions.isEmpty && event.name.isEmpty
                          && event.logoPath.isEmpty && event.centerImagePath.isEmpty)
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    eventSection
                    Divider()
                    sessionsSection
                    if let sid = selectedSessionID,
                       let s = event.sessions.first(where: { $0.id == sid }) {
                        Divider()
                        qrDetail(s)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 580, height: 700)
        .onAppear(perform: load)
        .onChange(of: event) { _, _ in persist() }
        .alert("이 세션을 삭제할까요?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } })) {
            Button("삭제", role: .destructive) { if let s = pendingDelete { deleteSession(s) }; pendingDelete = nil }
            Button("취소", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("저장된 QR 파일과 청중 링크(서버 데이터)도 함께 삭제됩니다. 청중 페이지는 더 이상 자막을 표시하지 않습니다.")
        }
        .alert("전체 초기화", isPresented: $showResetConfirm) {
            Button("전부 삭제", role: .destructive) { resetAll() }
            Button("취소", role: .cancel) { }
        } message: {
            Text("모든 세션·QR 파일·그림·청중 링크(서버 데이터)가 삭제됩니다. 되돌릴 수 없습니다.")
        }
    }

    // ── 행사 정보 ──
    private var eventSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("행사 정보").font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                Text("행사명").frame(width: 96, alignment: .leading).foregroundStyle(.secondary)
                TextField("예: 제25회 인공지능 국제 컨퍼런스", text: $event.name)
                    .textFieldStyle(.roundedBorder)
            }

            filePickRow(title: "행사 로고", path: event.logoPath,
                        hint: "QR 상단 + 청중 페이지에 표시") {
                if let p = pickImage(), let stored = importAsset(from: p) {
                    deleteAssetIfManaged(event.logoPath)
                    event.logoPath = stored
                }
            } clear: {
                deleteAssetIfManaged(event.logoPath); event.logoPath = ""
            }

            filePickRow(title: "QR 중앙 그림", path: event.centerImagePath,
                        hint: "선택 안 하면 그림 없이 생성") {
                if let p = pickImage(), let stored = importAsset(from: p) {
                    deleteAssetIfManaged(event.centerImagePath)
                    event.centerImagePath = stored
                }
            } clear: {
                deleteAssetIfManaged(event.centerImagePath); event.centerImagePath = ""
            }
        }
    }

    private func filePickRow(title: String, path: String, hint: String,
                             pick: @escaping () -> Void, clear: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(title).frame(width: 96, alignment: .leading).foregroundStyle(.secondary)
            Button("파일 선택", action: pick)
            if !path.isEmpty {
                Text((path as NSString).lastPathComponent)
                    .font(.caption).lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(.secondary)
                Button { clear() } label: { Image(systemName: "xmark.circle") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
            } else {
                Text(hint).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // ── 세션 목록 ──
    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("세션 (각각 QR 1개)").font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    event.sessions.append(QRSession())
                } label: { Label("세션 추가", systemImage: "plus") }
            }

            if event.sessions.isEmpty {
                Text("‘세션 추가’를 눌러 날짜와 세션명을 입력하세요.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 8)
            }

            ForEach($event.sessions) { $s in
                HStack(spacing: 8) {
                    TextField("날짜 (예: 6월 15일)", text: $s.date)
                        .textFieldStyle(.roundedBorder).frame(width: 150)
                    TextField("세션명 (예: 개회식)", text: $s.name)
                        .textFieldStyle(.roundedBorder)
                    Button("QR 보기") { selectedSessionID = s.id }
                        .buttonStyle(.bordered)
                    Button(role: .destructive) {
                        pendingDelete = s
                    } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    // ── 선택한 세션의 QR + 동작 버튼 ──
    @ViewBuilder
    private func qrDetail(_ s: QRSession) -> some View {
        let link = AudienceConfig.link(s.id)
        VStack(alignment: .leading, spacing: 10) {
            Text("QR 미리보기").font(.subheadline.weight(.semibold))

            if let img = qrImage(link: link, centerPath: event.centerImagePath,
                                 logoPath: event.logoPath, caption: captionString(s)) {
                Image(nsImage: img)
                    .resizable().scaledToFit()
                    .frame(width: 240)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 8) {
                    Button { saveToFolder(img, name: fileName(s)) } label: {
                        Label("저장하기", systemImage: "tray.and.arrow.down")
                    }
                    Button { exportPNG(img, suggested: fileName(s)) } label: {
                        Label("내보내기", systemImage: "square.and.arrow.up")
                    }
                    Button { copyLink(link) } label: {
                        Label("링크 복사", systemImage: "link")
                    }
                    Spacer()
                }
            } else {
                Text("QR 생성 실패").foregroundStyle(.red).font(.caption)
            }

            Text(link).font(.caption2).foregroundStyle(.secondary)
                .textSelection(.enabled).lineLimit(1).truncationMode(.middle)
        }
    }

    // ── 캡션(행사명 / 날짜 · 세션명) ──
    private func captionString(_ s: QRSession) -> NSAttributedString {
        audienceQRCaption(eventName: event.name, date: s.date, name: s.name)
    }

    // ── QR 이미지 생성 ──
    private func qrImage(link: String, centerPath: String, logoPath: String, caption: NSAttributedString) -> NSImage? {
        makeAudienceQRImage(link: link, centerPath: centerPath, logoPath: logoPath, caption: caption)
    }

    // ── 동작 ──
    private func pickImage() -> String? {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.png, .jpeg]
        p.allowsMultipleSelection = false
        p.canChooseDirectories = false
        return p.runModal() == .OK ? p.url?.path : nil
    }

    private func pngData(_ image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private func fileName(_ s: QRSession) -> String {
        let raw = [event.name, s.date, s.name].filter { !$0.isEmpty }.joined(separator: "_")
        let base = raw.isEmpty ? "QR" : raw
        // 세션 ID를 파일명에 포함 → 삭제 시 찾아서 지울 수 있음
        return base.replacingOccurrences(of: " ", with: "") + "_\(s.id).png"
    }

    // ── 앱 저장소(그림/QR) 관리 ──
    private func assetsDir() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("BoothmateG/Assets", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func qrCodesDir() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("BoothmateG/QRCodes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // 고른 그림을 앱 저장소로 복사 (원본이 옮겨지거나 지워져도 계속 적용되도록)
    private func importAsset(from path: String) -> String? {
        let src = URL(fileURLWithPath: path)
        let folder = assetsDir().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let dest = folder.appendingPathComponent(src.lastPathComponent)
        do { try FileManager.default.copyItem(at: src, to: dest); return dest.path }
        catch { return nil }
    }

    // 앱이 복사해둔 그림만 삭제 (사용자 원본 파일은 건드리지 않음)
    private func deleteAssetIfManaged(_ path: String) {
        guard !path.isEmpty, path.contains("/BoothmateG/Assets/") else { return }
        let folder = URL(fileURLWithPath: path).deletingLastPathComponent()
        if folder.path.contains("/BoothmateG/Assets/") {
            try? FileManager.default.removeItem(at: folder)
        } else {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    // 세션 삭제 시, 저장해둔 QR 파일(파일명에 세션 ID 포함)도 폴더에서 제거
    private func deleteSavedQR(forSessionID id: String) {
        let dir = qrCodesDir()
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        for f in files where f.contains(id) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(f))
        }
    }

    // 세션 하나 완전 삭제: 로컬 기록 + 저장 QR 파일 + 서버(RTDB) 데이터
    private func deleteSession(_ s: QRSession) {
        if selectedSessionID == s.id { selectedSessionID = nil }
        deleteSavedQR(forSessionID: s.id)
        FirebaseRelay.shared.deleteSession(s.id)        // 청중 링크 무효화
        event.sessions.removeAll { $0.id == s.id }
    }

    // 전체 초기화: 모든 세션·파일·그림·서버 데이터 제거
    private func resetAll() {
        for s in event.sessions {
            deleteSavedQR(forSessionID: s.id)
            FirebaseRelay.shared.deleteSession(s.id)
        }
        deleteAssetIfManaged(event.logoPath)
        deleteAssetIfManaged(event.centerImagePath)
        selectedSessionID = nil
        event = QREvent()
    }

    private func exportPNG(_ image: NSImage, suggested: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = suggested
        panel.canCreateDirectories = true
        panel.title = "QR 내보내기"
        panel.begin { resp in
            guard resp == .OK, let url = panel.url, let data = pngData(image) else { return }
            try? data.write(to: url)
        }
    }

    private func saveToFolder(_ image: NSImage, name: String) {
        let url = qrCodesDir().appendingPathComponent(name)
        if let data = pngData(image) {
            try? data.write(to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func copyLink(_ link: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link, forType: .string)
    }

    // ── 저장/불러오기 ──
    private func load() {
        guard !eventJSON.isEmpty,
              let data = eventJSON.data(using: .utf8),
              let e = try? JSONDecoder().decode(QREvent.self, from: data) else { return }
        event = e
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(event),
              let str = String(data: data, encoding: .utf8) else { return }
        eventJSON = str
    }
}

// ───────────────────────────────────────────────
// 공용 QR 렌더링 함수 (QR 탭 + 빠른보기에서 공유)
// ───────────────────────────────────────────────

func audienceQRCaption(eventName: String, date: String, name: String) -> NSAttributedString {
    let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineSpacing = 5
    let out = NSMutableAttributedString()
    out.append(NSAttributedString(string: "동시통역 자막용 QR 코드\n", attributes: [
        .font: NSFont.boldSystemFont(ofSize: 22),
        .foregroundColor: NSColor.black, .paragraphStyle: para]))
    out.append(NSAttributedString(string: "Simultaneous Interpretation Subtitle QR Code\n", attributes: [
        .font: NSFont.systemFont(ofSize: 14),
        .foregroundColor: NSColor.gray, .paragraphStyle: para]))
    if !eventName.isEmpty {
        out.append(NSAttributedString(string: eventName + "\n", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 22),
            .foregroundColor: NSColor.black, .paragraphStyle: para]))
    }
    let line2 = [date, name].filter { !$0.isEmpty }.joined(separator: " · ")
    out.append(NSAttributedString(string: line2, attributes: [
        .font: NSFont.systemFont(ofSize: 17),
        .foregroundColor: NSColor.darkGray, .paragraphStyle: para]))
    return out
}

func audienceAspectFit(_ imageSize: NSSize, into rect: NSRect) -> NSRect {
    guard imageSize.width > 0, imageSize.height > 0 else { return rect }
    let s = min(rect.width / imageSize.width, rect.height / imageSize.height)
    let w = imageSize.width * s, h = imageSize.height * s
    return NSRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
}

// v1.9.0: 디자인 QR (안정 우선) — 격자 파싱 정확화(여백 자동 측정), 점 크게, 파인더 살짝만 둥글게, 진한 단색.
//         중앙 로고는 centerPath가 있으면 표시(둥근 흰 배경), 없으면 QR만. 오류정정 H.
func makeAudienceQRImage(link: String, centerPath: String, logoPath: String, caption: NSAttributedString) -> NSImage? {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(link.utf8)
    filter.correctionLevel = "H"
    guard let output = filter.outputImage, output.extent.width > 0 else { return nil }

    // CIFilter QR은 1픽셀 = 1모듈(칸) + 둘레 여백으로 나온다. 1:1 비트맵으로 읽는다.
    let W = Int(output.extent.width.rounded())
    let H = Int(output.extent.height.rounded())
    guard W > 0, H > 0,
          let cg = context.createCGImage(output, from: output.extent) else { return nil }
    var px = [UInt8](repeating: 0, count: W * H * 4)
    guard let bmp = CGContext(data: &px, width: W, height: H, bitsPerComponent: 8,
                              bytesPerRow: W * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    bmp.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
    // CIFilter 출력은 아래가 y=0. 행을 위→아래로 쓰려고 뒤집어 읽는다.
    func darkPx(_ x: Int, _ y: Int) -> Bool {
        let yy = H - 1 - y
        let i = (yy * W + x) * 4
        return px[i] < 128
    }

    // 여백(quiet zone) 자동 측정: 위에서 첫 어두운 픽셀 행/열 찾기
    func firstDarkRow() -> Int { for y in 0..<H { for x in 0..<W { if darkPx(x,y) { return y } } }; return 0 }
    func lastDarkRow() -> Int { for y in stride(from: H-1, through: 0, by: -1) { for x in 0..<W { if darkPx(x,y) { return y } } }; return H-1 }
    let margin = firstDarkRow()                 // 둘레 여백(픽셀=모듈)
    let gridStart = margin
    let gridEnd = lastDarkRow()                  // 마지막 어두운 행
    let moduleCount = (gridEnd - gridStart) + 1  // 실제 칸 개수
    guard moduleCount >= 21 else { return nil }  // QR 최소 21x21

    // (col,row) 칸이 어두운지 — 여백 보정
    func isDark(_ col: Int, _ row: Int) -> Bool {
        let x = gridStart + col, y = gridStart + row
        guard x >= 0, x < W, y >= 0, y < H else { return false }
        return darkPx(x, y)
    }

    let qrPx: CGFloat = 600
    let module = qrPx / CGFloat(moduleCount)
    // v2.0.0: 위쪽 띠 로고(logoPath)에서 테마색 자동 추출. 없거나 추출 실패 시 기본 진한 파랑.
    let themeColor = audienceExtractThemeColor(fromImagePath: logoPath)
        ?? NSColor(red: 0/255, green: 90/255, blue: 200/255, alpha: 1)
    let brand = themeColor                          // 데이터 점
    let finderColor = audienceDarken(themeColor, by: 0.15)  // 파인더: 살짝 더 진하게(포인트)

    let qr = NSImage(size: NSSize(width: qrPx, height: qrPx), flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
        let n = moduleCount
        func inFinder(_ c: Int, _ r: Int) -> Bool {
            (c < 7 && r < 7) || (c >= n - 7 && r < 7) || (c < 7 && r >= n - 7)
        }

        // 데이터 점(더 큰 둥근 원) — inset 3%, 파인더 제외, 패턴 심플화
        ctx.setFillColor(brand.cgColor)
        for row in 0..<n {
            for col in 0..<n {
                guard isDark(col, row), !inFinder(col, row) else { continue }
                let x = CGFloat(col) * module
                let y = qrPx - CGFloat(row + 1) * module
                let inset = module * 0.03
                ctx.fillEllipse(in: CGRect(x: x + inset, y: y + inset,
                                           width: module - inset*2, height: module - inset*2))
            }
        }

        // 파인더 3개 — 완전히 둥글게(거의 원형) + 포인트색(finderColor)
        func drawFinder(_ cc: Int, _ cr: Int) {
            let x = CGFloat(cc) * module
            let y = qrPx - CGFloat(cr) * module - module * 7
            let outer = CGRect(x: x, y: y, width: module*7, height: module*7)
            ctx.setFillColor(finderColor.cgColor)
            ctx.addPath(CGPath(roundedRect: outer, cornerWidth: module*2.8, cornerHeight: module*2.8, transform: nil)); ctx.fillPath()
            let mid = outer.insetBy(dx: module, dy: module)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.addPath(CGPath(roundedRect: mid, cornerWidth: module*2.0, cornerHeight: module*2.0, transform: nil)); ctx.fillPath()
            let inner = outer.insetBy(dx: module*2, dy: module*2)
            ctx.setFillColor(finderColor.cgColor)
            ctx.addPath(CGPath(roundedRect: inner, cornerWidth: module*1.3, cornerHeight: module*1.3, transform: nil)); ctx.fillPath()
        }
        drawFinder(0, 0)
        drawFinder(n - 7, 0)
        drawFinder(0, n - 7)
        return true
    }

    // 캔버스 합성 (기존 레이아웃)
    let pad: CGFloat = 20
    let captionH: CGFloat = 150
    let hasLogo = !logoPath.isEmpty && FileManager.default.fileExists(atPath: logoPath)
    let logoH: CGFloat = hasLogo ? 130 : 0
    let canvas = NSSize(width: qrPx + pad*2, height: pad + captionH + qrPx + logoH + pad)

    return NSImage(size: canvas, flipped: false) { _ in
        NSColor.white.setFill()
        NSRect(origin: .zero, size: canvas).fill()
        let qrRect = NSRect(x: pad, y: pad + captionH, width: qrPx, height: qrPx)
        qr.draw(in: qrRect)
        if !centerPath.isEmpty, let center = NSImage(contentsOfFile: centerPath) {
            let cz: CGFloat = 170   // 안정 위해 200→170로 축소
            let cx = qrRect.minX + (qrPx - cz)/2
            let cy = qrRect.minY + (qrPx - cz)/2
            let bg = NSRect(x: cx-14, y: cy-14, width: cz+28, height: cz+28)
            NSColor.white.setFill(); NSBezierPath(roundedRect: bg, xRadius: 24, yRadius: 24).fill()
            center.draw(in: audienceAspectFit(center.size, into: NSRect(x: cx, y: cy, width: cz, height: cz)))
        }
        if hasLogo, let logo = NSImage(contentsOfFile: logoPath) {
            let band = NSRect(x: pad, y: pad + captionH + qrPx, width: qrPx, height: logoH)
            logo.draw(in: audienceAspectFit(logo.size, into: band.insetBy(dx: 20, dy: 12)))
        }
        caption.draw(in: NSRect(x: pad, y: 12, width: qrPx, height: captionH - 12))
        return true
    }
}

func audienceQRPNG(_ image: NSImage) -> Data? {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
}

// v2.0.0: 로고 이미지에서 테마색 자동 추출.
// 불투명하고 너무 밝거나 너무 어둡지 않은(=유채색) 픽셀들의 평균을 구한 뒤,
// QR 인식을 위해 너무 밝으면 어둡게 보정한다. 추출 불가하면 nil.
func audienceExtractThemeColor(fromImagePath path: String) -> NSColor? {
    guard !path.isEmpty, FileManager.default.fileExists(atPath: path),
          let img = NSImage(contentsOfFile: path),
          let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    let w = rep.pixelsWide, h = rep.pixelsHigh
    guard w > 0, h > 0 else { return nil }

    var rSum = 0.0, gSum = 0.0, bSum = 0.0, count = 0.0
    let stepX = max(1, w / 60), stepY = max(1, h / 60)   // 표본 추출(성능)
    var y = 0
    while y < h {
        var x = 0
        while x < w {
            if let c = rep.colorAt(x: x, y: y) {
                let a = c.alphaComponent
                let r = c.redComponent, g = c.greenComponent, b = c.blueComponent
                let maxc = max(r, g, b), minc = min(r, g, b)
                let brightness = maxc
                let sat = maxc > 0 ? (maxc - minc) / maxc : 0
                // 불투명 + 너무 희거나 검지 않고 + 어느 정도 채도 있는 픽셀만
                if a > 0.6 && brightness > 0.15 && brightness < 0.97 && sat > 0.15 {
                    rSum += r; gSum += g; bSum += b; count += 1
                }
            }
            x += stepX
        }
        y += stepY
    }
    guard count >= 10 else { return nil }   // 표본이 너무 적으면 실패 처리

    var r = rSum / count, g = gSum / count, b = bSum / count
    // 인식 안전: 평균 밝기가 높으면(연한 색) 어둡게 눌러 대비 확보
    let bright = max(r, max(g, b))
    if bright > 0.55 {
        let k = 0.55 / bright   // 가장 밝은 채널을 0.55로 맞춤
        r *= k; g *= k; b *= k
    }
    return NSColor(red: r, green: g, blue: b, alpha: 1)
}

// 색을 비율만큼 어둡게 (0.15 = 15% 어둡게)
func audienceDarken(_ color: NSColor, by ratio: CGFloat) -> NSColor {
    let c = color.usingColorSpace(.deviceRGB) ?? color
    let k = max(0, 1 - ratio)
    return NSColor(red: c.redComponent * k, green: c.greenComponent * k,
                   blue: c.blueComponent * k, alpha: 1)
}

func audienceCopyLink(_ link: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(link, forType: .string)
}

func audienceExportQR(_ image: NSImage, suggestedName: String) {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.png]
    panel.nameFieldStringValue = suggestedName
    panel.canCreateDirectories = true
    panel.title = "QR 내보내기"
    panel.begin { resp in
        guard resp == .OK, let url = panel.url, let data = audienceQRPNG(image) else { return }
        try? data.write(to: url)
    }
}

// ───────────────────────────────────────────────
// 빠른보기: 선택한 세션의 QR을 바로 띄우는 창
// ───────────────────────────────────────────────
struct BroadcastQRView: View {
    let sessionId: String
    @Environment(\.dismiss) private var dismiss
    @AppStorage("audienceQREventJSON") private var eventJSON: String = ""

    private var event: QREvent? {
        guard let d = eventJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(QREvent.self, from: d)
    }
    private var session: QRSession? { event?.sessions.first { $0.id == sessionId } }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("자막 QR").font(.title3).bold()
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }

            if let ev = event, let s = session {
                let link = AudienceConfig.link(s.id)
                if let img = makeAudienceQRImage(link: link, centerPath: ev.centerImagePath,
                                                 logoPath: ev.logoPath,
                                                 caption: audienceQRCaption(eventName: ev.name, date: s.date, name: s.name)) {
                    Image(nsImage: img).resizable().scaledToFit()
                        .frame(maxWidth: 380, maxHeight: 440)
                    Text(link).font(.caption2).foregroundStyle(.secondary)
                        .textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                    HStack(spacing: 8) {
                        Button { audienceCopyLink(link) } label: { Label("링크 복사", systemImage: "link") }
                        Button { audienceExportQR(img, suggestedName: "QR_\(s.id).png") } label: {
                            Label("내보내기", systemImage: "square.and.arrow.up")
                        }
                    }
                } else {
                    Text("QR 생성 실패").foregroundStyle(.red)
                }
            } else {
                Text("세션을 먼저 선택하세요.\n('청중 QR' 탭에서 만든 세션이 있어야 합니다.)")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary).font(.callout)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
