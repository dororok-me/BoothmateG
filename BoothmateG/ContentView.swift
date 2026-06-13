//
//  ContentView.swift
//  BoothmateG
//
//  Version: 2.9.0
//  Changelog:
//    ... (이전 이력 생략) ...
//    2.8.0 - 언어 즉시 스왑, API 키 설정 이관, 입력 소스 선택
//    2.9.0 - 양방향 자동: GeminiLiveClient → DualTranslateClient 로 교체.
//            언어쌍(소스/타겟 칸) 두 세션 동시 운용 → 말한 언어 반대로 자동 표시.
//            ※ 두 언어 칸은 이제 "방향"이 아니라 "언어쌍"을 정함.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var subtitles = SubtitleStore()

    @State private var audio = AudioEngine()
    @State private var client = DualTranslateClient()   // ← 양방향 듀얼 세션
    @State private var glossary = GlossaryEngine()

    @State private var overlayController = OverlayWindowController()

    @State private var isRunning: Bool = false
    @State private var statusMessage: String = "대기 중"
    @State private var showGlossary: Bool = false
    @State private var showSettings: Bool = false
    @State private var showInputSource: Bool = false

    @State private var isEditing: Bool = false
    @State private var currentInputName: String = ""

    @AppStorage("console_targetFont") private var targetFont: Double = 18
    @AppStorage("console_sourceFont") private var sourceFont: Double = 14
    @AppStorage("console_night")      private var night: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerBar
            Divider()
            controlsRow
            Divider()
            subtitleScroll
            Divider()
            inputSourceBar
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 500)
        .background(night ? Color.black : Color.clear)
        .preferredColorScheme(night ? .dark : nil)
        .onAppear {
            glossary.update(items: settings.loadGlossary())
            refreshInputName()
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
                if isRunning { restartAudio() }
            }
        }
    }

    // ── 헤더 ──
    private var headerBar: some View {
        HStack {
            Text("BoothmateG").font(.title2).bold()
            Spacer()
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
            Text(statusMessage).font(.caption).foregroundStyle(.secondary)
        }
    }

    // ── 입력 줄 (언어쌍 + 스왑 + 시작/정지/지우기) ──
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

            Button(isRunning ? "정지" : "시작") {
                if isRunning { stop() } else { start() }
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)

            Button("지우기") { subtitles.clear() }
                .disabled(subtitles.segments.isEmpty && subtitles.currentSource.isEmpty)

            Spacer()
        }
    }

    private func langPicker(_ selection: Binding<String>) -> some View {
        Picker("", selection: selection) {
            ForEach(supportedLanguages) { lang in
                Text(lang.label).tag(lang.id)
            }
        }
        .labelsHidden()
        .frame(width: 110)
        .disabled(isRunning)
    }

    // ── 자막 목록 ──
    private var subtitleScroll: some View {
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
        .frame(minHeight: 280)
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

    // ── 언어쌍 순서 스왑 ──
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

    // ───────────────────────────────────────────────
    // 시작 (양방향 듀얼 세션)
    // ───────────────────────────────────────────────
    private func start() {
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

        // 언어쌍: A = 타겟 칸, B = 소스 칸 (방향은 자동 감지)
        client.connect(
            apiKey: settings.geminiApiKey,
            langA: settings.targetLang,
            langB: settings.sourceLang
        )

        do {
            try audio.start()
            isRunning = true
        } catch {
            statusMessage = "❌ 마이크 시작 실패: \(error.localizedDescription)"
            client.disconnect()
        }
    }

    private func stop() {
        audio.stop()
        client.disconnect()
        isRunning = false
        statusMessage = "정지됨"
    }
}

// ─────────────────────────────────────────────────
// 한 segment(문장 한 쌍) — 단어 더블클릭 수정
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
