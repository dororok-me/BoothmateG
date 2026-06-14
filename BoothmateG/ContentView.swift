//
//  ContentView.swift
//  BoothmateG
//
//  Version: 2.34.0
//  Changelog:
//    2.31.0 - 다국어 화자를 단일 소스와 분리(multiSourceLang). 헤더에 화자 선택 picker.
//    2.32.0 - 청중 송출: QR 세션 선택 + 송출 토글. 자막을 FirebaseRelay로 실시간 송출.
//    2.33.0 - 송출 버튼 문구 '송출/송출 중' → '자막 송출 시작/자막 송출 중'.
//    2.34.0 - 송출 옆에 'QR 보기' 버튼 추가(선택 세션의 QR을 바로 띄움, BroadcastQRView).
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
    @ObservedObject private var relay = FirebaseRelay.shared
    @State private var audioBroadcaster = AudioBroadcaster()
    @State private var showHostLogin = false
    
    @State private var overlayController = OverlayWindowController()
    @State private var multiOverlay = MultiOverlayController()

    @State private var isRunning: Bool = false
    @State private var isMultiRunning: Bool = false
    @State private var statusMessage: String = "대기 중"
    @State private var showGlossary: Bool = false
    @State private var showSettings: Bool = false
    @State private var showInputSource: Bool = false
    @State private var showAudienceLangs: Bool = false
    @State private var showAudienceQR: Bool = false

    @State private var isEditing: Bool = false
    @State private var currentInputName: String = ""
    @State private var audienceLangs: [String] = []

    // 청중 송출
    @AppStorage("audienceQREventJSON") private var audienceQREventJSON: String = ""
    @State private var broadcastSessionId: String = ""
    @State private var broadcasting: Bool = false
    @State private var showBroadcastQR: Bool = false

    @State private var sessionStart: Date? = nil
    @State private var multiSessionStart: Date? = nil

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
        .frame(minWidth: 1000, minHeight: 540)
        .background(consoleBackground)
        .preferredColorScheme(night ? .dark : nil)
        .onAppear {
            glossary.update(items: settings.loadGlossary())
            refreshInputName()
            migrateLanguageCodes()
            audienceLangs = settings.loadAudienceLangs().filter { $0 != settings.multiSourceLang }
            multiStore.setLanguages(audienceLangs)
        }
        .onChange(of: settings.playTranslatedAudio) { _, on in
            if on && isRunning { audioPlayer.start() } else { audioPlayer.stop() }
        }
        .onChange(of: settings.multiAudioLang) { _, lang in
            guard isMultiRunning else { return }
            if lang.isEmpty { audioPlayer.stop() } else { audioPlayer.start() }
        }
        .onChange(of: settings.multiSourceLang) { _, src in
            // 화자로 고른 언어는 청중에서 빠져야 함 (영어 화자 → 영어 청중 같은 빈 세션 방지)
            audienceLangs = audienceLangs.filter { $0 != src }
            multiStore.setLanguages(audienceLangs)
        }
        .sheet(isPresented: $showGlossary) {
            GlossaryView(settings: settings) { items in glossary.update(items: items) }
        }
        .sheet(isPresented: $showSettings) {
            ConsoleSettingsView(settings: settings, onExportTranscript: { exportCurrentTranscript() })
        }
        .sheet(isPresented: $showInputSource) {
            InputSourceView { dev in
                currentInputName = dev.name
                if isRunning || isMultiRunning { restartAudio() }
            }
        }
        .sheet(isPresented: $showAudienceLangs) {
            AudienceLangView(settings: settings) { langs in
                audienceLangs = langs.filter { $0 != settings.multiSourceLang }
                multiStore.setLanguages(audienceLangs)
            }
        }
        .sheet(isPresented: $showAudienceQR) {
            AudienceQRView()
        }
        .sheet(isPresented: $showBroadcastQR) {
            BroadcastQRView(sessionId: broadcastSessionId)

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
                .frame(width: 380, alignment: .topLeading)
                .padding(10)
                .background(ActivePulseBox(active: isRunning, color: .green))
            Divider().frame(height: 80)
            multiColumn
                .frame(width: 380, alignment: .topLeading)
                .padding(10)
                .background(ActivePulseBox(active: isMultiRunning, color: .blue))
            Spacer()
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
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRunning ? .red : .green)
                .frame(width: 92)
                .disabled(isMultiRunning)

                timerLabel(sessionStart)

                resetButton(disabled: subtitles.segments.isEmpty && subtitles.currentSource.isEmpty) {
                    subtitles.clear()
                }

                overlayToggleButton(isOn: overlayController.isVisible, color: .green, help: "오버레이") {
                    overlayController.toggle(store: subtitles, glossary: glossary, mainWindow: NSApp.keyWindow)
                }

                audioSupportButton
            }
        }
    }

    // 모니터 아이콘 옆 '음성지원' 토글 버튼 (설정 안 들어가도 바로 전환)
    // 켜짐=파랑, 꺼짐=회색. 켜진 상태로 번역 중이면 '음성 지원 중' 깜빡임.
    private var audioSupportButton: some View {
        Button {
            settings.playTranslatedAudio.toggle()
        } label: {
            if settings.playTranslatedAudio && isRunning {
                AudioSupportBadge()
            } else {
                HStack(spacing: 3) {
                    Image(systemName: settings.playTranslatedAudio ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    Text("음성지원")
                }
                .font(.caption)
            }
        }
        .buttonStyle(.bordered)
        .tint(settings.playTranslatedAudio ? .blue : .gray)
        .disabled(isMultiRunning)
        .help("번역 음성 재생 켜기/끄기")
    }

    // ── 오른쪽: 다국어 ──
    private var multiColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "globe").font(.caption)
                Text("다국어").font(.caption.bold())
                Text("· 화자").font(.caption2)
                Picker("", selection: $settings.multiSourceLang) {
                    ForEach(supportedLanguages) { lang in
                        Text(lang.label).tag(lang.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .fixedSize()
                .disabled(isRunning || isMultiRunning)
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Button { showAudienceLangs = true } label: {
                    Text(audienceLangs.isEmpty ? "청중 언어 선택" : "선택 언어: \(audienceTagList)")
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
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isMultiRunning ? .red : .blue)
                .frame(width: 92)
                .disabled(audienceLangs.isEmpty || isRunning)

                timerLabel(multiSessionStart)

                resetButton(disabled: multiStore.segments.isEmpty && multiStore.currentSource.isEmpty) {
                    multiStore.clear()
                }

                overlayToggleButton(isOn: multiOverlay.isVisible, color: .blue, help: "다국어 오버레이") {
                    if multiStore.langs.isEmpty { multiStore.setLanguages(audienceLangs) }
                    multiOverlay.toggle(store: multiStore)
                }

                multiAudioMenu
            }
        }
    }

    // ── 맨 오른쪽: 전역 메뉴 ── (v2.25.0: 하단 입력 소스 줄로 이동, 제거됨)

    // 다국어 모드 음성: 청중 언어 중 하나만 골라 그 음성만 재생 (v2.28.0)
    private var multiAudioMenu: some View {
        Menu {
            Button("음성 끄기") { settings.multiAudioLang = "" }
            ForEach(audienceLangs, id: \.self) { code in
                Button(langShort(code)) { settings.multiAudioLang = code }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: multiAudioActive ? "speaker.wave.2.fill" : "speaker.slash.fill")
                Text(multiAudioActive ? langShort(settings.multiAudioLang) : "음성")
            }
            .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .tint(multiAudioActive ? .blue : .gray)
        .disabled(audienceLangs.isEmpty)
        .help("재생할 번역 음성 언어 선택 (한 언어만)")
    }

    // 선택된 음성 언어가 현재 청중 언어 목록에 실제로 있는지
    private var multiAudioActive: Bool {
        !settings.multiAudioLang.isEmpty && audienceLangs.contains(settings.multiAudioLang)
    }

    // 언어 코드 → 짧은 표기
    private func langShort(_ code: String) -> String {
        supportedLanguages.first { $0.id == code }.map { String($0.label.prefix(6)) } ?? code
    }

    // 경과 타이머 (줄바꿈 방지: fixedSize). start가 nil이면 00:00:00 회색.
    private func timerLabel(_ start: Date?) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let e = start.map { max(0, context.date.timeIntervalSince($0)) } ?? 0
            Text(formatElapsed(e))
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(start != nil ? .primary : .secondary)
        }
    }

    // '자막리셋' 버튼 (텍스트형)
    private func resetButton(disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("자막리셋").font(.caption)
        }
        .buttonStyle(.bordered)
        .disabled(disabled)
        .help("자막 리셋")
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

    // ── 하단: 입력 소스 + 설정/용어집 + 청중 송출 (2줄·크게) ──
        private var inputSourceBar: some View {
            VStack(alignment: .leading, spacing: 8) {
                // 1줄: 입력 소스 · 설정 · 용어집 · 청중 QR
                HStack(spacing: 12) {
                    Image(systemName: "mic").foregroundStyle(.secondary)
                    Button { showInputSource = true } label: {
                        HStack(spacing: 4) {
                            Text("입력 소스: \(currentInputName.isEmpty ? "기본 장치" : currentInputName)")
                            Image(systemName: "chevron.up.chevron.down").foregroundStyle(.secondary)
                        }.font(.body)
                    }
                    .buttonStyle(.plain)

                    Divider().frame(height: 20)

                    Button { showSettings = true } label: {
                        HStack(spacing: 5) { Image(systemName: "gearshape"); Text("설정") }.font(.body)
                    }
                    .buttonStyle(.plain)

                    Button { showGlossary = true } label: {
                        HStack(spacing: 5) { Image(systemName: "character.book.closed"); Text("용어집") }.font(.body)
                    }
                    .buttonStyle(.plain)

                    Button { showAudienceQR = true } label: {
                        HStack(spacing: 5) { Image(systemName: "qrcode"); Text("청중 QR") }.font(.body)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .imageScale(.large)

                // 2줄: 송출 표시 · 세션 선택 · 로그인 · 송출 · QR · 리셋
                HStack(spacing: 10) {
                    Image(systemName: broadcasting ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right")
                        .font(.body).foregroundStyle(broadcasting ? .red : .secondary)
                    Picker("", selection: $broadcastSessionId) {
                        Text("세션 선택").tag("")
                        ForEach(qrSessions) { s in Text(sessionLabel(s)).tag(s.id) }
                    }
                    .labelsHidden().pickerStyle(.menu).controlSize(.large).fixedSize()
                    .disabled(broadcasting)

                    Button { showHostLogin = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: relay.authReady ? "checkmark.seal.fill" : "person.crop.circle.badge.exclamationmark")
                            Text(relay.authReady ? "호스트" : "로그인")
                        }.font(.body)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    .tint(relay.authReady ? .green : .orange)

                    Button {
                        broadcasting.toggle()
                        if broadcasting { beginBroadcastIfNeeded() }
                        else { relay.stopBroadcast(); audioBroadcaster.stop(); statusMessage = "송출 중지" }
                    } label: {
                        Text(broadcasting ? "자막 송출 중" : "자막 송출 시작").font(.body)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    .tint(broadcasting ? .red : .blue)
                    .disabled(broadcastSessionId.isEmpty || !relay.authReady)

                    Button { showBroadcastQR = true } label: {
                        HStack(spacing: 4) { Image(systemName: "qrcode.viewfinder"); Text("QR 보기") }.font(.body)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    .disabled(broadcastSessionId.isEmpty)

                    Button { resetSubtitles() } label: {
                        HStack(spacing: 4) { Image(systemName: "trash"); Text("자막 리셋") }.font(.body)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    .tint(.orange)
                    .disabled(broadcastSessionId.isEmpty)

                    Spacer()

                    Text(statusMessage).font(.callout).foregroundStyle(.secondary)
                }
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
        if !ids.contains(settings.multiSourceLang) { settings.multiSourceLang = "ko" }
    }

    // ── 청중 송출 ──
    private var qrSessions: [QRSession] {
        guard let d = audienceQREventJSON.data(using: .utf8),
              let ev = try? JSONDecoder().decode(QREvent.self, from: d) else { return [] }
        return ev.sessions
    }
    private func sessionLabel(_ s: QRSession) -> String {
        let l = [s.date, s.name].filter { !$0.isEmpty }.joined(separator: " · ")
        return l.isEmpty ? "세션" : l
    }
    private func qrSessionInfo(_ id: String) -> (event: String, session: String)? {
        guard let d = audienceQREventJSON.data(using: .utf8),
              let ev = try? JSONDecoder().decode(QREvent.self, from: d),
              let s = ev.sessions.first(where: { $0.id == id }) else { return nil }
        return (ev.name, sessionLabel(s))
    }
    private func langLabel(_ code: String) -> String {
        supportedLanguages.first { $0.id == code }?.label ?? code
    }

    // 송출 시작 (실행 중 + 송출 ON + 세션 선택돼 있을 때만 meta 기록)
    private func resetSubtitles() {
            subtitles.clear()                      // 단일 자막 비우기
            multiStore.clear()                     // 다국어 자막 비우기
            relay.clearLive(broadcastSessionId)    // RTDB 라이브 자막·음성 삭제
            audioBroadcaster.reset()               // 진행 중 음성 버퍼 폐기
            statusMessage = "자막 초기화됨"
        }
    
    private func beginBroadcastIfNeeded() {
        guard broadcasting, !broadcastSessionId.isEmpty, (isRunning || isMultiRunning) else { return }
        guard let info = qrSessionInfo(broadcastSessionId) else {
            statusMessage = "❌ 송출할 세션을 선택하세요"; return
        }
        var langs: [String: String] = [:]
        let mode: String
        if isMultiRunning {
            mode = "multi"
            for c in audienceLangs { langs[c] = langLabel(c) }
        } else {
            mode = "single"
            langs[settings.targetLang] = langLabel(settings.targetLang)
        }
        relay.startBroadcast(sessionId: broadcastSessionId, eventName: info.event,
                             sessionName: info.session, mode: mode, langs: langs)
        audioBroadcaster.start(sessionId: broadcastSessionId)
        statusMessage = "📡 청중 송출 중"
    }

    // 단일 모드 자막 송출
    private func relaySingle() {
        guard relay.active else { return }
        let lines = Array(subtitles.segments.map { $0.targetText }.suffix(60))
        relay.updateLive(lang: settings.targetLang, current: subtitles.currentTarget, lines: lines)
    }
    // 다국어 모드 자막 송출 (언어 1개)
    private func relayMulti(_ lang: String) {
        guard relay.active else { return }
        let lines = Array(multiStore.segments.compactMap { $0.targets[lang] }.suffix(60))
        relay.updateLive(lang: lang, current: multiStore.currentTargets[lang] ?? "", lines: lines)
    }
    private func relayMultiAll() {
        guard relay.active else { return }
        for lang in audienceLangs { relayMulti(lang) }
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
        client.onOutputTranscript = { t in DispatchQueue.main.async { self.subtitles.appendTarget(t); self.relaySingle() } }
        client.onAudio = { [audioPlayer] d in
                    audioPlayer.enqueue(pcm16: d)
                    self.audioBroadcaster.append(lang: self.settings.targetLang, pcm16: d)
                }
        client.onTurnComplete = { DispatchQueue.main.async { self.subtitles.finalizeTurn(); self.relaySingle() } }
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
            beginBroadcastIfNeeded()
        } catch {
            statusMessage = "❌ 마이크 시작 실패: \(error.localizedDescription)"
            client.disconnect()
        }
    }

    private func stop() {
        TranscriptArchive.autoSave(transcriptText(started: sessionStart), started: sessionStart)
        audio.stop()
        client.disconnect()
        audioPlayer.stop()
        relay.stopBroadcast()
        audioBroadcaster.stop()
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

        // 화자 언어는 타깃에서 제외 (영어 화자인데 영어 청중 같은 빈 세션 방지)
        let targets = audienceLangs.filter { $0 != settings.multiSourceLang }
        guard !targets.isEmpty else {
            statusMessage = "❌ 화자 언어와 다른 청중 언어를 선택하세요"; return
        }
        audienceLangs = targets

        multiStore.setLanguages(targets)
        statusMessage = "다국어 연결 중..."

        multiClient.onConnected = {
            DispatchQueue.main.async { self.statusMessage = "✅ 다국어 연결됨 (\(self.audienceLangs.count)개)" }
        }
        multiClient.onSource = { t in DispatchQueue.main.async { self.multiStore.appendSource(t) } }
        multiClient.onTarget = { lang, t in DispatchQueue.main.async { self.multiStore.appendTarget(lang, t); self.relayMulti(lang) } }
        multiClient.onAudio = { [audioPlayer] lang, d in
                    if lang == self.settings.multiAudioLang { audioPlayer.enqueue(pcm16: d) }
                    self.audioBroadcaster.append(lang: lang, pcm16: d)
                }
        multiClient.onTurnComplete = { DispatchQueue.main.async { self.multiStore.finalizeTurn(); self.relayMultiAll() } }
        multiClient.onError = { m in DispatchQueue.main.async { self.statusMessage = "❌ \(m)" } }

        audio.onAudioData = { [multiClient] d in multiClient.sendAudio(d) }

        multiClient.connect(apiKey: settings.geminiApiKey, sourceLang: settings.multiSourceLang, targets: targets)

        do {
            try audio.start()
            isMultiRunning = true
            multiSessionStart = Date()
            if !settings.multiAudioLang.isEmpty { audioPlayer.start() }
            multiOverlay.show(store: multiStore)
            beginBroadcastIfNeeded()
        } catch {
            statusMessage = "❌ 마이크 시작 실패: \(error.localizedDescription)"
            multiClient.disconnect()
        }
    }

    private func stopMulti() {
        TranscriptArchive.autoSave(transcriptText(started: multiSessionStart), started: multiSessionStart)
        audio.stop()
        multiClient.disconnect()
        audioPlayer.stop()
        relay.stopBroadcast()
        audioBroadcaster.stop()
        isMultiRunning = false
        multiSessionStart = nil
        statusMessage = "정지됨"
    }

    // ── 전사문 텍스트 생성 (v2.20.0, v2.24.0: 시작 시각 매개변수화) ──
    // 다국어 세션 내용이 있으면 다국어 형식, 아니면 단일 언어 형식으로 구성.
    private func transcriptText(started: Date?) -> String {
        var lines: [String] = []
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        lines.append("BoothmateG 전사문 — \(f.string(from: started ?? Date()))")
        lines.append(String(repeating: "─", count: 24))
        lines.append("")

        if !multiStore.segments.isEmpty {
            for seg in multiStore.segments {
                if !seg.source.isEmpty { lines.append("· \(seg.source)") }
                for lang in multiStore.langs {
                    if let t = seg.targets[lang], !t.isEmpty {
                        lines.append("[\(lang)] \(t)")
                    }
                }
                lines.append("")
            }
        } else {
            for seg in subtitles.segments {
                if !seg.sourceText.isEmpty { lines.append("· \(seg.sourceText)") }
                if !seg.targetText.isEmpty { lines.append(glossary.normalize(seg.targetText)) }
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }

    // ── 전사문 내보내기 (설정 메뉴 버튼) ──
    private func exportCurrentTranscript() {
        if subtitles.segments.isEmpty && multiStore.segments.isEmpty {
            statusMessage = "내보낼 전사문이 없습니다"
            return
        }
        let started = multiStore.segments.isEmpty ? sessionStart : multiSessionStart
        TranscriptArchive.export(transcriptText(started: started), started: started)
    }

    // ── 메인 콘솔 배경 (v2.19.0) ──
    // 파스텔 옅은 푸른 계열 그라데이션. 야간 모드는 기존대로 검정 유지.
    @ViewBuilder
    private var consoleBackground: some View {
        if night {
            Color.black
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.96, blue: 1.00),
                    Color(red: 0.84, green: 0.91, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
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

// ─────────────────────────────────────────────────
// 번역 진행 중 표시 박스 (v2.23.0)
// active일 때 칼럼 뒤에 은은한 색을 깔고, 숨 쉬듯(밝아졌다 흐려졌다) 천천히 변화.
// idle일 때는 투명(박스 없음).
struct ActivePulseBox: View {
    var active: Bool
    var color: Color
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(color.opacity(active ? (pulse ? 0.22 : 0.09) : 0.0))
            .animation(
                active ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true) : .easeOut(duration: 0.4),
                value: pulse
            )
            .onAppear { pulse = active }
            .onChange(of: active) { _, on in pulse = on }
    }
}

// ─────────────────────────────────────────────────
// 음성 지원(번역 음성 재생) 켜진 상태 표시 (v2.18.0)
// 화면에 나타날 때(=조건 충족 시)만 onAppear로 은은하게 맥동.
// 빨간 마이크(입력 받는 느낌)를 피하려고 스피커 + "음성 지원" 텍스트 사용.
struct AudioSupportBadge: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("음성 지원 중")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.blue)
        .opacity(pulse ? 1.0 : 0.55)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                   value: pulse)
        .onAppear { pulse = true }
        .help("번역 음성 재생 중")
    }
}

#Preview {
    ContentView()
}
