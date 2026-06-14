//
//  ContentView.swift
//  BoothmateG
//
//  Version: 2.14.0
//  Changelog:
//    2.13.0 - 다국어 모드 중 콘솔에 원문 표시
//    2.14.0 - 로고 3배 확대 + 메뉴를 로고 오른쪽에 배치.
//             다국어 줄에 화자(소스) 언어 표시.
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
            headerBar
            Divider()
            controlsRow
            multiRow
            Divider()
            subtitleScroll
            Divider()
            inputSourceBar
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 520)
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
            GlossaryView(settings: settings) { items in
                glossary.update(items: items)
            }
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

    // ── 헤더: 큰 로고 + 그 오른쪽에 메뉴 ──
    private var headerBar: some View {
        HStack(spacing: 16) {
            Image("BoothmateG_logo_512")
                .resizable()
                .scaledToFit()
                .frame(height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Button {
                overlayController.toggle(store: subtitles, glossary: glossary, mainWindow: NSApp.keyWindow)
            } label: {
                Image(systemName: overlayController.isVisible
                      ? "rectangle.on.rectangle.fill" : "rectangle.on.rectangle")
                Text("오버레이")
            }
            Button { showGlossary = true } label: {
                Image(systemName: "character.book.closed"); Text("용어집")
            }
            Button { showSettings = true } label: {
                Image(systemName: "gearshape"); Text("설정")
            }

            Spacer()

            Text(statusMessage).font(.caption).foregroundStyle(.secondary)
        }
    }

    // ── 양방향(2개 언어) 줄 ──
    private var controlsRow: some View {
        HStack(spacing: 12) {
            langPicker($settings.sourceLang)

            Button { swapLanguages() } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("언어쌍 순서 바꾸기")

            langPicker($settings.targetLang)

            Button {
                if isRunning { stop() } else { start() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: isRunning ? "stop.fill" : "play.fill")
                    Text(isRunning ? "정지" : "시작")
                }
                .frame(minWidth: 56)
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
            .tint(isRunning ? .red : .green)
            .disabled(isMultiRunning)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let e = sessionStart.map { max(0, context.date.timeIntervalSince($0)) } ?? 0
                Text(formatElapsed(e))
                    .font(.system(.body, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(sessionStart != nil ? .primary : .secondary)
            }

            Spacer()

            Button {
                subtitles.clear()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("자막 리셋")
                }
            }
            .disabled(subtitles.segments.isEmpty && subtitles.currentSource.isEmpty)
        }
    }

    // ── 다국어(1→N) 줄 ──
    private var multiRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "globe").foregroundStyle(.secondary)
            Text("다국어").font(.caption).foregroundStyle(.secondary)

            Text("화자: \(sourceLabel)")
                .font(.caption)
                .foregroundStyle(.blue)

            Button {
                showAudienceLangs = true
            } label: {
                Text(audienceLangs.isEmpty ? "청중 언어 선택" : "청중: \(audienceTagList)")
                    .font(.caption)
                    .lineLimit(1)
            }
            .disabled(isRunning || isMultiRunning)

            Button {
                if isMultiRunning { stopMulti() } else { startMulti() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isMultiRunning ? "stop.fill" : "play.fill")
                    Text(isMultiRunning ? "다국어 정지" : "다국어 시작")
                }
            }
            .buttonStyle(.bordered)
            .tint(isMultiRunning ? .red : .blue)
            .disabled(audienceLangs.isEmpty || isRunning)

            Button {
                if multiStore.langs.isEmpty { multiStore.setLanguages(audienceLangs) }
                multiOverlay.toggle(store: multiStore)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: multiOverlay.isVisible
                          ? "rectangle.on.rectangle.fill" : "rectangle.on.rectangle")
                    Text("다국어 오버레이").font(.caption)
                }
            }
            .buttonStyle(.bordered)

            Spacer()
        }
    }

    private var sourceLabel: String {
        supportedLanguages.first { $0.id == settings.sourceLang }?.label ?? settings.sourceLang
    }

    private var audienceTagList: String {
        audienceLangs.map { code in
            supportedLanguages.first { $0.id == code }.map { String($0.label.prefix(6)) } ?? code
        }.joined(separator: ", ")
    }

    private func langPicker(_ selection: Binding<String>) -> some View {
        Picker("", selection: selection) {
            ForEach(supportedLanguages) { lang in
                Text(lang.label).tag(lang.id)
            }
        }
        .labelsHidden()
        .frame(width: 150)
        .disabled(isRunning || isMultiRunning)
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let total = Int(t)
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    // ── 콘솔 자막 영역 ──
    @ViewBuilder
    private var subtitleScroll: some View {
        if isMultiRunning {
            multiSourceScroll
        } else {
            pairScroll
        }
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
                    ForEach(subtitles.segments) { segment in
                        segmentRow(segment)
                    }
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

    // ── 하단 입력 소스 ──
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
            statusMessage = "❌ 설정에서 API 키를 입력하세요"
            return
        }

        statusMessage = "연결 중..."

        client.onConnected = {
            DispatchQueue.main.async { self.statusMessage = "✅ 연결됨 - 말해보세요" }
        }
        client.onInputTranscript = { text in
            DispatchQueue.main.async { self.subtitles.appendSource(text) }
        }
        client.onOutputTranscript = { text in
            DispatchQueue.main.async { self.subtitles.appendTarget(text) }
        }
        client.onAudio = { [audioPlayer] data in
            audioPlayer.enqueue(pcm16: data)
        }
        client.onTurnComplete = {
            DispatchQueue.main.async { self.subtitles.finalizeTurn() }
        }
        client.onError = { msg in
            DispatchQueue.main.async { self.statusMessage = "❌ \(msg)" }
        }
        client.onClosed = {
            DispatchQueue.main.async {
                if self.isRunning { self.statusMessage = "연결 종료됨" }
            }
        }

        audio.onAudioData = { [client] data in
            client.sendAudio(data)
        }

        client.connect(
            apiKey: settings.geminiApiKey,
            langA: settings.targetLang,
            langB: settings.sourceLang
        )

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
            statusMessage = "❌ 설정에서 API 키를 입력하세요"
            return
        }
        guard !audienceLangs.isEmpty else {
            statusMessage = "❌ 청중 언어를 먼저 선택하세요"
            return
        }

        multiStore.setLanguages(audienceLangs)
        statusMessage = "다국어 연결 중..."

        multiClient.onConnected = {
            DispatchQueue.main.async { self.statusMessage = "✅ 다국어 연결됨 (\(self.audienceLangs.count)개 언어)" }
        }
        multiClient.onSource = { text in
            DispatchQueue.main.async { self.multiStore.appendSource(text) }
        }
        multiClient.onTarget = { lang, text in
            DispatchQueue.main.async { self.multiStore.appendTarget(lang, text) }
        }
        multiClient.onTurnComplete = {
            DispatchQueue.main.async { self.multiStore.finalizeTurn() }
        }
        multiClient.onError = { msg in
            DispatchQueue.main.async { self.statusMessage = "❌ \(msg)" }
        }

        audio.onAudioData = { [multiClient] data in
            multiClient.sendAudio(data)
        }

        multiClient.connect(
            apiKey: settings.geminiApiKey,
            sourceLang: settings.sourceLang,
            targets: audienceLangs
        )

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
