//
//  ContentView.swift
//  BoothmateG
//
//  Version: 2.16.0
//  Changelog:
//    2.15.0 - 헤더 좌/우 2등분, 상태 하단 이동, 모니터 아이콘
//    2.16.0 - 오버레이(모니터) 버튼 켜짐/꺼짐 시각 구분 강화(켜짐=색 채움, 꺼짐=회색)
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var subtitles = SubtitleStore()
    @StateObject private var multiStore = MultiSubtitleStore()

    @State private var audio = AudioEngine()
    @State private var client = DualTranslateClient()
    @State private var multiClient = MultiTranslateClient()
    @State private var glossary = GlossaryEngine()
    @State private var audioPlayer = TranslatedAudioPlayer()

    @State private var overlayController = OverlayWindowController()
    @State private var multiOverlay = MultiOverlayController()

    @State private var isRunning: Bool = false
    @State private var isMultiRunning: Bool = false
    @State private var statusMessage: String = "대기 중"
    @State private var showGlossary: Bool = false
    @State private var showSettings: Bool = false
    @State private var showInputSource: Bool = false
    @State private var showAudienceLangs: Bool = false

    @State private var isEditing: Bool = false
    @State private var currentInputName: String = ""
    @State private var audienceLangs: [String] = []

    @State private var sessionStart: Date? = nil

    @AppStorage("console_targetFont") private var targetFont: Double = 18
    @AppStorage("console_sourceFont") private var sourceFont: Double = 14
    @AppStorage("console_night")      private var night: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerArea
            Divider()
            subtitleScroll
            Divider()
            inputSourceBar
        }
        .padding(20)
        .frame(minWidth: 880, minHeight: 540)
        .background(night ? Color.black : Color.clear)
        .preferredColorScheme(night ? .dark : nil)
        .onAppear {
            glossary.update(items: settings.loadGlossary())
            refreshInputName()
            migrateLanguageCodes()
            audienceLangs = settings.loadAudienceLangs()
            multiStore.setLanguages(audienceLangs)
        }
        .onChange(of: settings.playTranslatedAudio) { _, on in
            if on && isRunning { audioPlayer.start() } else { audioPlayer.stop() }
        }
        .sheet(isPresented: $showGlossary) {
            GlossaryView(settings: settings) { items in glossary.update(items: items) }
        }
        .sheet(isPresented: $showSettings) {
            ConsoleSettingsView(settings: settings)
        }
        .sheet(isPresented: $showInputSource) {
            InputSourceView { dev in
                currentInputName = dev.name
                if isRunning || isMultiRunning { restartAudio() }
            }
        }
        .sheet(isPresented: $showAudienceLangs) {
            AudienceLangView(settings: settings) { langs in
                audienceLangs = langs
                multiStore.setLanguages(langs)
            }
        }
    }

    // ═══════════════ 헤더 ═══════════════
    private var headerArea: some View {
        HStack(alignment: .center, spacing: 14) {
            Image("BoothmateG_logo_512")
                .resizable()
                .scaledToFit()
                .frame(height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Divider().frame(height: 80)
            singleColumn
            Divider().frame(height: 80)
            multiColumn
            Spacer()
            rightMenu
        }
    }

    // 모니터(오버레이) 토글 버튼 — 켜짐=색 채움, 꺼짐=회색
    private func overlayToggleButton(isOn: Bool, color: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "display")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isOn ? .white : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isOn ? color : Color.gray.opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isOn ? color : Color.gray.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help + (isOn ? " (켜짐)" : " (꺼짐)"))
    }

    // ── 왼쪽: 단일 언어 ──
    private var singleColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("단일 언어").font(.caption.bold()).foregroundStyle(.secondary)

            HStack(spacing: 6) {
                compactLangPicker($settings.sourceLang)
                Button { swapLanguages() } label: {
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .disabled(isRunning || isMultiRunning)
                compactLangPicker($settings.targetLang)
            }

            HStack(spacing: 6) {
                Button {
                    if isRunning { stop() } else { start() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isRunning ? "stop.fill" : "play.fill")
                        Text(isRunning ? "정지" : "시작")
                    }
                    .frame(minWidth: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRunning ? .red : .green)
                .disabled(isMultiRunning)

                timerView

                Button { subtitles.clear() } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("자막 리셋")
                .disabled(subtitles.segments.isEmpty && subtitles.currentSource.isEmpty)

                overlayToggleButton(isOn: overlayController.isVisible, color: .green, help: "오버레이") {
                    overlayController.toggle(store: subtitles, glossary: glossary, mainWindow: NSApp.keyWindow)
                }
            }
        }
    }

    // ── 오른쪽: 다국어 ──
    private var multiColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "globe").font(.caption)
                Text("다국어").font(.caption.bold())
                Text("· 화자 \(sourceShort)").font(.caption2)
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Button { showAudienceLangs = true } label: {
                    Text(audienceLangs.isEmpty ? "청중 언어 선택" : "청중: \(audienceTagList)")
                        .font(.caption).lineLimit(1)
                }
                .disabled(isRunning || isMultiRunning)
            }

            HStack(spacing: 6) {
                Button {
                    if isMultiRunning { stopMulti() } else { startMulti() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isMultiRunning ? "stop.fill" : "play.fill")
                        Text(isMultiRunning ? "정지" : "시작")
                    }
                    .frame(minWidth: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(isMultiRunning ? .red : .blue)
                .disabled(audienceLangs.isEmpty || isRunning)

                overlayToggleButton(isOn: multiOverlay.isVisible, color: .blue, help: "다국어 오버레이") {
                    if multiStore.langs.isEmpty { multiStore.setLanguages(audienceLangs) }
                    multiOverlay.toggle(store: multiStore)
                }
            }
        }
    }

    // ── 맨 오른쪽: 전역 메뉴 ──
    private var rightMenu: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape"); Text("설정")
            }
            Button { showGlossary = true } label: {
                Image(systemName: "character.book.closed"); Text("용어집")
            }
        }
    }

    private var timerView: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let e = sessionStart.map { max(0, context.date.timeIntervalSince($0)) } ?? 0
            Text(formatElapsed(e))
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(sessionStart != nil ? .primary : .secondary)
        }
    }

    private var sourceShort: String {
        let label = supportedLanguages.first { $0.id == settings.sourceLang }?.label ?? settings.sourceLang
        return String(label.prefix(12))
    }

    private var audienceTagList: String {
        audienceLangs.map { code in
            supportedLanguages.first { $0.id == code }.map { String($0.label.prefix(6)) } ?? code
        }.joined(separator: ", ")
    }

    private func compactLangPicker(_ selection: Binding<String>) -> some View {
        Picker("", selection: selection) {
            ForEach(supportedLanguages) { lang in
                Text(lang.label).tag(lang.id)
            }
        }
        .labelsHidden()
        .frame(width: 130)
        .disabled(isRunning || isMultiRunning)
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let total = Int(t)
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    // ═══════════════ 콘솔 자막 ═══════════════
    @ViewBuilder
    private var subtitleScroll: some View {
        if isMultiRunning { multiSourceScroll } else { pairScroll }
    }

    private var multiSourceScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(multiStore.segments) { seg in
                        Text(seg.source)
                            .font(.system(size: CGFloat(targetFont)))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.blue.opacity(0.06))
                            .cornerRadius(6)
                    }
                    if !multiStore.currentSource.isEmpty {
                        Text(multiStore.currentSource)
                            .font(.system(size: CGFloat(targetFont)))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(6)
                            .id("msrc")
                    }
                }
                .padding(.vertical, 8)
            }
            .onChange(of: multiStore.currentSource) { _, _ in proxy.scrollTo("msrc", anchor: .bottom) }
            .onChange(of: multiStore.segments.count) { _, _ in
                withAnimation { proxy.scrollTo("msrc", anchor: .bottom) }
            }
        }
        .frame(minHeight: 260)
    }

    private var pairScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(subtitles.segments) { segment in segmentRow(segment) }
                    currentProgressView
                }
                .padding(.vertical, 8)
            }
            .onChange(of: subtitles.segments.count) { _, _ in
                if !isEditing { withAnimation { proxy.scrollTo("current", anchor: .bottom) } }
            }
            .onChange(of: subtitles.currentTarget) { _, _ in
                if !isEditing { proxy.scrollTo("current", anchor: .bottom) }
            }
        }
        .frame(minHeight: 260)
    }

    @ViewBuilder
    private func segmentRow(_ segment: SubtitleSegment) -> some View {
        SegmentRow(
            segment: segment,
            glossary: glossary,
            fontSize: CGFloat(targetFont),
            srcFontSize: CGFloat(sourceFont),
            isEditing: $isEditing,
            onCommitSource: { subtitles.updateSource(id: segment.id, newText: $0) },
            onCommitTarget: { subtitles.updateTarget(id: segment.id, newText: $0) }
        )
        .id(segment.id)
    }

    @ViewBuilder
    private var currentProgressView: some View {
        if !subtitles.currentSource.isEmpty || !subtitles.currentTarget.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if !subtitles.currentSource.isEmpty {
                    Text(subtitles.currentSource)
                        .font(.system(size: CGFloat(sourceFont)))
                        .foregroundStyle(.secondary)
                }
                if !subtitles.currentTarget.isEmpty {
                    Text(glossary.normalize(subtitles.currentTarget))
                        .font(.system(size: CGFloat(targetFont)))
                        .italic()
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(6)
            .id("current")
        }
    }

    // ── 하단: 입력 소스 + 상태 ──
    private var inputSourceBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "mic").foregroundStyle(.secondary)
            Button { showInputSource = true } label: {
                Text("입력 소스: \(currentInputName.isEmpty ? "기본 장치" : currentInputName)")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2).foregroundStyle(.secondary)

            Spacer()

            Text(statusMessage).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func refreshInputName() {
        if let id = AudioDeviceManager.defaultInputDevice() {
            currentInputName = AudioDeviceManager.deviceName(id) ?? ""
        }
    }

    private func migrateLanguageCodes() {
        let ids = Set(supportedLanguages.map { $0.id })
        if !ids.contains(settings.sourceLang) { settings.sourceLang = "ko" }
        if !ids.contains(settings.targetLang) { settings.targetLang = "en" }
    }

    private func swapLanguages() {
        let s = settings.sourceLang
        settings.sourceLang = settings.targetLang
        settings.targetLang = s
        if isRunning { stop(); start() }
    }

    private func restartAudio() {
        audio.stop()
        do { try audio.start() } catch {
            statusMessage = "❌ 입력 장치 전환 실패: \(error.localizedDescription)"
        }
    }

    // ── 양방향 시작/정지 ──
    private func start() {
        if isMultiRunning { stopMulti() }
        guard !settings.geminiApiKey.isEmpty else {
            statusMessage = "❌ 설정에서 API 키를 입력하세요"; return
        }
        statusMessage = "연결 중..."

        client.onConnected = { DispatchQueue.main.async { self.statusMessage = "✅ 연결됨" } }
        client.onInputTranscript = { t in DispatchQueue.main.async { self.subtitles.appendSource(t) } }
        client.onOutputTranscript = { t in DispatchQueue.main.async { self.subtitles.appendTarget(t) } }
        client.onAudio = { [audioPlayer] d in audioPlayer.enqueue(pcm16: d) }
        client.onTurnComplete = { DispatchQueue.main.async { self.subtitles.finalizeTurn() } }
        client.onError = { m in DispatchQueue.main.async { self.statusMessage = "❌ \(m)" } }
        client.onClosed = {
            DispatchQueue.main.async { if self.isRunning { self.statusMessage = "연결 종료됨" } }
        }

        audio.onAudioData = { [client] d in client.sendAudio(d) }

        client.connect(apiKey: settings.geminiApiKey, langA: settings.targetLang, langB: settings.sourceLang)

        do {
            try audio.start()
            isRunning = true
            sessionStart = Date()
            if settings.playTranslatedAudio { audioPlayer.start() }
        } catch {
            statusMessage = "❌ 마이크 시작 실패: \(error.localizedDescription)"
            client.disconnect()
        }
    }

    private func stop() {
        audio.stop()
        client.disconnect()
        audioPlayer.stop()
        isRunning = false
        sessionStart = nil
        statusMessage = "정지됨"
    }

    // ── 다국어 시작/정지 ──
    private func startMulti() {
        if isRunning { stop() }
        guard !settings.geminiApiKey.isEmpty else {
            statusMessage = "❌ 설정에서 API 키를 입력하세요"; return
        }
        guard !audienceLangs.isEmpty else {
            statusMessage = "❌ 청중 언어를 먼저 선택하세요"; return
        }

        multiStore.setLanguages(audienceLangs)
        statusMessage = "다국어 연결 중..."

        multiClient.onConnected = {
            DispatchQueue.main.async { self.statusMessage = "✅ 다국어 연결됨 (\(self.audienceLangs.count)개)" }
        }
        multiClient.onSource = { t in DispatchQueue.main.async { self.multiStore.appendSource(t) } }
        multiClient.onTarget = { lang, t in DispatchQueue.main.async { self.multiStore.appendTarget(lang, t) } }
        multiClient.onTurnComplete = { DispatchQueue.main.async { self.multiStore.finalizeTurn() } }
        multiClient.onError = { m in DispatchQueue.main.async { self.statusMessage = "❌ \(m)" } }

        audio.onAudioData = { [multiClient] d in multiClient.sendAudio(d) }

        multiClient.connect(apiKey: settings.geminiApiKey, sourceLang: settings.sourceLang, targets: audienceLangs)

        do {
            try audio.start()
            isMultiRunning = true
            sessionStart = Date()
            multiOverlay.show(store: multiStore)
        } catch {
            statusMessage = "❌ 마이크 시작 실패: \(error.localizedDescription)"
            multiClient.disconnect()
        }
    }

    private func stopMulti() {
        audio.stop()
        multiClient.disconnect()
        isMultiRunning = false
        sessionStart = nil
        statusMessage = "정지됨"
    }
}

// ─────────────────────────────────────────────────
struct SegmentRow: View {
    let segment: SubtitleSegment
    let glossary: GlossaryEngine
    var fontSize: CGFloat = 18
    var srcFontSize: CGFloat = 14
    @Binding var isEditing: Bool
    var onCommitSource: (String) -> Void = { _ in }
    var onCommitTarget: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !segment.sourceText.isEmpty {
                EditableSubtitleText(
                    text: segment.sourceText,
                    fontSize: srcFontSize, bold: false, color: .secondary,
                    isEditing: $isEditing, onCommit: onCommitSource
                )
            }
            if !segment.targetText.isEmpty {
                EditableSubtitleText(
                    text: glossary.normalize(segment.targetText),
                    fontSize: fontSize, bold: true, color: .primary,
                    isEditing: $isEditing, onCommit: onCommitTarget
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(6)
    }
}

#Preview {
    ContentView()
}
