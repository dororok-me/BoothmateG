//
//  ContentView.swift
//  BoothmateG
//
//  Version: 2.6.1
//  Changelog:
//    1.0.0 - 최초 작성
//    2.0.0 - SubtitleStore 기반으로 자막을 segment 단위 누적 표시
//    2.1.0 - 오버레이 창 토글 버튼 추가
//    2.2.0 - 용어집 편집 시트 추가 (헤더에 용어집 버튼)
//    2.3.0 - 글로서리를 오버레이로 이관. 메인 콘솔/저장소는 Gemini 원본 그대로 유지
//    2.4.0 - 메인 콘솔 설정 버튼/시트 (글자 크기, 야간 모드)
//    2.5.0 - 자막 수정(연필 버튼, 라인 단위)
//    2.6.0 - 자막 수정 방식 변경: 단어 더블클릭 → 블록선택 팝오버. 편집 중 자동 스크롤 정지
//    2.6.1 - body가 너무 커서 생기는 컴파일러 타입체크 타임아웃 해결:
//            헤더/입력줄/자막목록을 컴퓨티드 뷰로 분리 (동작 동일)
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var subtitles = SubtitleStore()

    @State private var audio = AudioEngine()
    @State private var client = GeminiLiveClient()
    @State private var glossary = GlossaryEngine()

    @State private var overlayController = OverlayWindowController()

    @State private var isRunning: Bool = false
    @State private var statusMessage: String = "대기 중"
    @State private var showGlossary: Bool = false
    @State private var showSettings: Bool = false

    // 편집 중이면 자동 스크롤 일시정지 (백그라운드 자막은 계속 진행)
    @State private var isEditing: Bool = false

    // ── 메인 콘솔 표시 설정 (ConsoleSettingsView와 키 공유) ──
    @AppStorage("console_targetFont") private var targetFont: Double = 18
    @AppStorage("console_sourceFont") private var sourceFont: Double = 14
    @AppStorage("console_night")      private var night: Bool = false

    // ───────────────────────────────────────────────
    // 화면 전체
    // ───────────────────────────────────────────────
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerBar
            Divider()
            controlsRow
            Divider()
            subtitleScroll
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 500)
        .background(night ? Color.black : Color.clear)   // 야간 모드 배경
        .preferredColorScheme(night ? .dark : nil)        // 야간 모드 색 구성
        .onAppear {
            glossary.update(items: settings.loadGlossary())
        }
        .sheet(isPresented: $showGlossary) {
            GlossaryView(settings: settings) { items in
                glossary.update(items: items)   // 저장 즉시 글로서리 엔진 갱신
            }
        }
        .sheet(isPresented: $showSettings) {
            ConsoleSettingsView()
        }
    }

    // ───────────────────────────────────────────────
    // 헤더 (제목 + 버튼들)
    // ───────────────────────────────────────────────
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
            Button {
                showGlossary = true
            } label: {
                Image(systemName: "character.book.closed")
                Text("용어집")
            }
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                Text("설정")
            }
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // ───────────────────────────────────────────────
    // 입력 줄 (API 키 + 언어 + 시작/정지/지우기)
    // ───────────────────────────────────────────────
    private var controlsRow: some View {
        HStack(spacing: 12) {
            SecureField("Gemini API Key", text: $settings.geminiApiKey)
                .textFieldStyle(.roundedBorder)
                .disabled(isRunning)

            langPicker($settings.sourceLang)

            Image(systemName: "arrow.right").foregroundStyle(.secondary)

            langPicker($settings.targetLang)

            Button(isRunning ? "정지" : "시작") {
                if isRunning { stop() } else { start() }
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)

            Button("지우기") {
                subtitles.clear()
            }
            .disabled(subtitles.segments.isEmpty && subtitles.currentSource.isEmpty)
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

    // ───────────────────────────────────────────────
    // 자막 목록 (스크롤)
    // ───────────────────────────────────────────────
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
            // 새 자막이 들어와도 편집 중이면 스크롤하지 않음 (편집 줄 고정)
            .onChange(of: subtitles.segments.count) { _, _ in
                if !isEditing {
                    withAnimation { proxy.scrollTo("current", anchor: .bottom) }
                }
            }
            .onChange(of: subtitles.currentTarget) { _, _ in
                if !isEditing {
                    proxy.scrollTo("current", anchor: .bottom)
                }
            }
        }
        .frame(minHeight: 300)
    }

    // 확정된 한 줄
    @ViewBuilder
    private func segmentRow(_ segment: SubtitleSegment) -> some View {
        SegmentRow(
            segment: segment,
            fontSize: CGFloat(targetFont),
            srcFontSize: CGFloat(sourceFont),
            isEditing: $isEditing,
            onCommitSource: { subtitles.updateSource(id: segment.id, newText: $0) },
            onCommitTarget: { subtitles.updateTarget(id: segment.id, newText: $0) }
        )
        .id(segment.id)
    }

    // 현재 진행 중 (회색)
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
                    Text(subtitles.currentTarget)
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

    // ───────────────────────────────────────────────
    // 시작
    // ───────────────────────────────────────────────
    private func start() {
        guard !settings.geminiApiKey.isEmpty else {
            statusMessage = "❌ API 키를 입력하세요"
            return
        }

        statusMessage = "연결 중..."

        // 콜백들
        client.onConnected = {
            DispatchQueue.main.async {
                self.statusMessage = "✅ 연결됨 - 말해보세요"
            }
        }
        client.onInputTranscript = { text in
            DispatchQueue.main.async {
                self.subtitles.appendSource(text)
            }
        }
        client.onOutputTranscript = { text in
            DispatchQueue.main.async {
                // 원본 그대로 저장 — 글로서리 교정은 오버레이 표시 단계에서 적용
                self.subtitles.appendTarget(text)
            }
        }
        client.onTurnComplete = {
            DispatchQueue.main.async {
                self.subtitles.finalizeTurn()
            }
        }
        client.onError = { msg in
            DispatchQueue.main.async {
                self.statusMessage = "❌ \(msg)"
            }
        }
        client.onClosed = {
            DispatchQueue.main.async {
                if self.isRunning {
                    self.statusMessage = "연결 종료됨"
                }
            }
        }

        // 마이크 → Gemini
        audio.onAudioData = { [client] data in
            client.sendAudio(data)
        }

        client.connect(
            apiKey: settings.geminiApiKey,
            sourceLang: settings.sourceLang,
            targetLang: settings.targetLang
        )

        do {
            try audio.start()
            isRunning = true
        } catch {
            statusMessage = "❌ 마이크 시작 실패: \(error.localizedDescription)"
            client.disconnect()
        }
    }

    // ───────────────────────────────────────────────
    // 정지
    // ───────────────────────────────────────────────
    private func stop() {
        audio.stop()
        client.disconnect()
        isRunning = false
        statusMessage = "정지됨"
    }
}

// ─────────────────────────────────────────────────
// 한 segment(문장 한 쌍)를 표시하는 행 — 단어 더블클릭 수정
// ─────────────────────────────────────────────────
struct SegmentRow: View {
    let segment: SubtitleSegment
    var fontSize: CGFloat = 18       // 번역 글자 크기
    var srcFontSize: CGFloat = 14    // 원문 글자 크기
    @Binding var isEditing: Bool
    var onCommitSource: (String) -> Void = { _ in }
    var onCommitTarget: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !segment.sourceText.isEmpty {
                EditableSubtitleText(
                    text: segment.sourceText,
                    fontSize: srcFontSize,
                    bold: false,
                    color: .secondary,
                    isEditing: $isEditing,
                    onCommit: onCommitSource
                )
            }
            if !segment.targetText.isEmpty {
                EditableSubtitleText(
                    text: segment.targetText,
                    fontSize: fontSize,
                    bold: true,
                    color: .primary,
                    isEditing: $isEditing,
                    onCommit: onCommitTarget
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
