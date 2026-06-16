//
//  ContentView.swift
//  BoothmateG
//
//  Version: 2.54.0
//  Changelog:
//    2.31.0 - 다국어 화자를 단일 소스와 분리(multiSourceLang). 헤더에 화자 선택 picker.
//    2.32.0 - 청중 송출: QR 세션 선택 + 송출 토글. 자막을 FirebaseRelay로 실시간 송출.
//    2.33.0 - 송출 버튼 문구 '송출/송출 중' → '자막 송출 시작/자막 송출 중'.
//    2.34.0 - 송출 옆에 ‘QR 보기’ 버튼 추가(선택 세션의 QR을 바로 띄움, BroadcastQRView).
//    2.35.0 - 청중 송출 텍스트에도 용어집 적용(relaySingle/relayMulti에 glossary.normalize).
//             콘솔·오버레이·청중이 동일한 용어로 통일됨.
//    2.36.0 - 음성 입력 없을 때 자동 중지 기능(setupAudioTimeout/stopAudioTimeout).
//             AudioEngine.onAudioRMS로 무음 감지, secondsWithoutAudio(초) 경과 시 stop/stopMulti.
//    2.37.0 - 상·하단 메뉴 순서 변경.
//             상단(단일/다국어): 시작 · 오버레이 · 음성지원 · 자막리셋 · 카운터.
//             하단 1줄: 앱 설정 · 입력 소스 · 용어집. 하단 2줄: 청중 QR · 세션 자막 선택 ·
//             QR 보기 · 호스트 · 자막 송출 시작 · 자막 리셋.
//    2.38.0 - 다국어 전사문 자동 저장 개선: 모든 청중 언어 포함, 언어 코드→라벨 표시,
//             화자/청중 언어 헤더 추가, 용어집 normalize 적용. (stopMulti의 autoSave로 자동 .txt 저장)
//    2.39.0 - 전사문이 헤더만 저장되던 문제 수정: 정지 직전 finalizeTurn으로 진행 중 자막 확정 +
//             transcriptText가 미확정 current* 내용도 출력. 내용 없으면 빈 파일 저장 안 함.
//    2.40.0 - 상단 음성 버튼 라벨 통일: 단일 언어 '음성지원' → '음성' (다국어와 동일하게).
//    2.41.0 - 단일 음성 버튼 스타일을 다국어 음성 메뉴와 동일하게(.borderless + .fixedSize) 통일.
//    2.42.0 - 중지(stop/stopMulti) 시 오버레이 창도 함께 닫기(overlayController/multiOverlay.hide()).
//             단일·다국어 음성 버튼 아이콘 크기 통일(.imageScale(.small)).
//    2.44.0 - 메인 콘솔의 진행 중 자막 수정 시트 완전 제거(잘못 들어간 v2.43 되돌림).
//             메인 콘솔 진행 중 자막은 탭해도 아무 창도 뜨지 않음. 오버레이 창 편집은 OverlayWindow에서 처리.
//    2.45.0 - 메인 콘솔 진행 중(회색) 번역 자막도 단어 더블클릭으로 바로 수정(확정 자막과 동일).
//             더블클릭 순간 내부 확정(글자 튐 없음), 수정 시 청중 송출도 갱신.
//             (EditableSubtitleText.onBeginEdit + SubtitleStore.commitCurrentForEditing 사용)
//    2.46.0 - 진행 중 자막 더블클릭 시 수정창이 즉시 닫히던 문제 수정.
//             더블클릭 시점에 확정하지 않고 텍스트만 고정(frozenCurrentText) → 뷰 유지 → 팝오버 안 닫힘.
//             확정은 저장(onCommit) 시점에 수행.
//    2.47.0 - 다국어 메인 콘솔 표시 형식 변경: 원문 + 각 언어 번역(KR/JP/CH...)을 함께 표시.
//             각 언어 줄의 단어를 더블클릭하면 단일 언어와 동일하게 바로 수정(확정/진행 중 모두).
//             진행 중 자막은 더블클릭 시 내용 고정(frozenMulti*) → 저장 시 확정.
//             (MultiSubtitleStore.updateTarget/commitCurrentForEditing 필요)
//    2.48.0 - 다국어 문장 확정 기준을 한국어로 설정(startMulti에서 sourceIsKorean 전달).
//             다국어 콘솔이 한국어 문장 단위로 끊겨 누적되지 않음.
//    2.49.0 - Fish Audio TTS 연결: 지정 언어 1개만 Fish 음성, 나머지는 Gemini.
//             Fish 언어는 Gemini 음성을 청중 송출에서 제외하고, 자막 텍스트를 Fish로 보내 클립 생성.
//    2.50.0 - Fish 호출을 turnComplete 대신 '문장 확정 콜백'(onSegmentCommitted)으로 변경.
//             Gemini가 turnComplete를 거의 안 보내 Fish가 호출 안 되던 문제 수정. 진단 로그 추가.
//    2.51.0 - 자동 중지 무음 판정 RMS 기준 500→50. 외부 오디오 인터페이스의 낮은 입력 레벨에서
//             발화 중에도 무음으로 오판해 중지되던 문제 수정.
//    2.52.0 - 정지 시 크래시 방지: 정지 시작 시 Fish 콜백(onSegmentCommitted) 먼저 차단,
//             Fish 합성 콜백은 메인에서 active 재확인 후에만 업로드(정지 후 늦은 도착 무시).
//
//    2.53.0 - 정지 시 다운(5분+ 누적 후) 대응: 전사문 파일 저장을 백그라운드로(메인 멈춤 방지),
//             콘솔은 최근 80개 세그먼트만 렌더(자막 누적 시 렌더 부하/스크롤 끊김 완화). 생성시간 로그.
//
//    2.54.0 - 수정 창 중복 해결: 수정 중(editingHold)에는 문장 자동 확정을 보류해
//             수정하던 진행 자막이 segments로 넘어가 중복 표시되던 문제 수정. 엔터 시 확정 재개.
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
    
    // v2.36.0 추가: 음성 입력 자동 중지
    @State private var audioTimeoutTimer: Timer?
    @State private var audioSilenceTime: Double = 0
    @State private var lastAudioRMS: Double?


    @State private var isRunning: Bool = false
    @State private var isMultiRunning: Bool = false
    @State private var statusMessage: String = "대기 중"
    @State private var showGlossary: Bool = false
    @State private var showSettings: Bool = false
    @State private var showInputSource: Bool = false
    @State private var showAudienceLangs: Bool = false
    @State private var showAudienceQR: Bool = false

    @State private var isEditing: Bool = false
    @State private var frozenCurrentText: String? = nil  // v2.46.0: 편집 중 진행 자막 고정 스냅샷(단일)
    @State private var frozenMultiText: [String: String]? = nil  // v2.47.0: 다국어 진행 자막 번역 고정
    @State private var frozenMultiSource: String? = nil          // v2.47.0: 다국어 진행 자막 원문 고정
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
            audio.onAudioRMS = { rms in self.lastAudioRMS = rms }  // v2.36.0
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

                // v2.37.0: 순서 변경 — 시작 · 오버레이 · 음성지원 · 자막리셋 · 카운터
                overlayToggleButton(isOn: overlayController.isVisible, color: .green, help: "오버레이") {
                    overlayController.toggle(store: subtitles, glossary: glossary, mainWindow: NSApp.keyWindow)
                }

                audioSupportButton

                resetButton(disabled: subtitles.segments.isEmpty && subtitles.currentSource.isEmpty) {
                    subtitles.clear()
                }

                timerLabel(sessionStart)
            }
        }
    }

    // 모니터 아이콘 옆 '음성' 토글 버튼 (설정 안 들어가도 바로 전환)
    // 켜짐=파랑, 꺼짐=회색. 켜진 상태로 번역 중이면 '음성 지원 중' 깜빡임.
    // v2.41.0: 다국어 음성 메뉴와 동일한 테두리 없는 스타일·크기로 통일.
    private var audioSupportButton: some View {
        Button {
            settings.playTranslatedAudio.toggle()
        } label: {
            if settings.playTranslatedAudio && isRunning {
                AudioSupportBadge()
            } else {
                HStack(spacing: 3) {
                    Image(systemName: settings.playTranslatedAudio ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    Text("음성")
                }
                .font(.caption)
                .imageScale(.small)
            }
        }
        .buttonStyle(.borderless)
        .fixedSize()
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

                // v2.37.0: 순서 변경 — 시작 · 오버레이 · 음성 · 자막리셋 · 카운터
                overlayToggleButton(isOn: multiOverlay.isVisible, color: .blue, help: "다국어 오버레이") {
                    if multiStore.langs.isEmpty { multiStore.setLanguages(audienceLangs) }
                    multiOverlay.toggle(store: multiStore)
                }

                multiAudioMenu

                resetButton(disabled: multiStore.segments.isEmpty && multiStore.currentSource.isEmpty) {
                    multiStore.clear()
                }

                timerLabel(multiSessionStart)
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
            .imageScale(.small)
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
                    // 확정된 세그먼트: 원문 + 각 언어 번역
                    // v2.53.0: 최근 80개만 렌더(성능). 전체 기록은 전사문에 저장됨.
                    ForEach(multiStore.segments.suffix(80)) { seg in
                        multiSegmentRow(seg)
                    }
                    // 진행 중(회색) 자막: 원문 + 각 언어 번역
                    multiCurrentRow
                }
                .padding(.vertical, 8)
            }
            .onChange(of: multiStore.currentSource) { _, _ in
                if !isEditing { proxy.scrollTo("msrc", anchor: .bottom) }
            }
            .onChange(of: multiStore.segments.count) { _, _ in
                if !isEditing { withAnimation { proxy.scrollTo("msrc", anchor: .bottom) } }
            }
        }
        .frame(minHeight: 260)
    }

    // 확정된 다국어 세그먼트 한 줄: 원문 + 각 언어 번역(단어 더블클릭 수정)
    @ViewBuilder
    private func multiSegmentRow(_ seg: MultiSegment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !seg.source.isEmpty {
                Text("원문: \(seg.source)")
                    .font(.system(size: CGFloat(sourceFont)))
                    .foregroundStyle(.secondary)
            }
            ForEach(multiStore.langs, id: \.self) { lang in
                if let t = seg.targets[lang], !t.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(langShort(lang)):")
                            .font(.system(size: CGFloat(targetFont) * 0.7, weight: .semibold))
                            .foregroundStyle(.blue.opacity(0.7))
                            .padding(.top, 2)
                        EditableSubtitleText(
                            text: glossary.normalize(t),
                            fontSize: CGFloat(targetFont),
                            bold: false,
                            color: .primary,
                            isEditing: $isEditing,
                            onCommit: { newText in
                                multiStore.updateTarget(id: seg.id, lang: lang, newText: newText)
                                relayMulti(lang)
                            }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(6)
    }

    // 진행 중(회색) 다국어 자막: 원문 + 각 언어 번역(단어 더블클릭 수정)
    @ViewBuilder
    private var multiCurrentRow: some View {
        let hasContent = !multiStore.currentSource.isEmpty
            || multiStore.currentTargets.values.contains { !$0.isEmpty }
        if hasContent || frozenMultiText != nil {
            VStack(alignment: .leading, spacing: 4) {
                let srcShown = frozenMultiSource ?? multiStore.currentSource
                if !srcShown.isEmpty {
                    Text("원문: \(srcShown)")
                        .font(.system(size: CGFloat(sourceFont)))
                        .foregroundStyle(.secondary)
                }
                ForEach(multiStore.langs, id: \.self) { lang in
                    let live = multiStore.currentTargets[lang] ?? ""
                    let shown = (frozenMultiText?[lang]) ?? live
                    if !shown.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(langShort(lang)):")
                                .font(.system(size: CGFloat(targetFont) * 0.7, weight: .semibold))
                                .foregroundStyle(.blue.opacity(0.5))
                                .padding(.top, 2)
                            EditableSubtitleText(
                                text: glossary.normalize(shown),
                                fontSize: CGFloat(targetFont),
                                bold: false,
                                color: .secondary.opacity(0.7),
                                isEditing: $isEditing,
                                onCommit: { newText in
                                    if let id = multiStore.commitCurrentForEditing() {
                                        multiStore.updateTarget(id: id, lang: lang, newText: newText)
                                        relayMulti(lang)
                                    }
                                    frozenMultiText = nil
                                    frozenMultiSource = nil
                                    multiStore.editingHold = false   // v2.54.0: 확정 보류 해제
                                },
                                onBeginEdit: {
                                    // 더블클릭 순간: 확정하지 않고 현재 내용만 고정(뷰 유지 → 팝오버 안 닫힘)
                                    frozenMultiText = multiStore.currentTargets
                                    frozenMultiSource = multiStore.currentSource
                                    multiStore.editingHold = true    // v2.54.0: 수정 중 자동 확정 보류(중복 방지)
                                }
                            )
                            .italic()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(6)
            .id("msrc")
        }
    }

    private var pairScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // v2.53.0: 최근 80개만 렌더(자막이 많이 쌓여도 화면이 무거워지지 않게).
                    //          전체 기록은 전사문에 저장됨.
                    ForEach(subtitles.segments.suffix(80)) { segment in segmentRow(segment) }
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
                if !subtitles.currentTarget.isEmpty || frozenCurrentText != nil {
                    // v2.46.0: 진행 중(회색) 번역 단어를 더블클릭하면 그 단어가 블록 선택된 채 바로 수정.
                    // 더블클릭 시점 텍스트를 고정(frozen)해 백그라운드 인식이 계속돼도 수정창이 흔들리지 않게 함.
                    // 확정은 저장(onCommit) 시점에 수행 → 더블클릭 직후 뷰가 사라져 팝오버가 닫히는 문제 방지.
                    EditableSubtitleText(
                        text: glossary.normalize(frozenCurrentText ?? subtitles.currentTarget),
                        fontSize: CGFloat(targetFont),
                        bold: false,
                        color: .secondary.opacity(0.7),
                        isEditing: $isEditing,
                        onCommit: { newText in
                            // 저장 시점에 진행 중 자막을 확정하고 수정 내용 반영
                            if let id = subtitles.commitCurrentForEditing() {
                                subtitles.updateTarget(id: id, newText: newText)
                                relaySingle()   // 청중 송출 중이면 즉시 반영
                            }
                            frozenCurrentText = nil
                            subtitles.editingHold = false   // v2.54.0: 확정 보류 해제
                        },
                        onBeginEdit: {
                            // 더블클릭 순간: 확정하지 않고 현재 텍스트만 고정(뷰 유지 → 팝오버 안 닫힘)
                            frozenCurrentText = subtitles.currentTarget
                            subtitles.editingHold = true    // v2.54.0: 수정 중 자동 확정 보류(중복 방지)
                        }
                    )
                    .italic()
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
                // 1줄: 앱 설정 · 입력 소스 · 용어집  (v2.37.0 순서 변경)
                HStack(spacing: 12) {
                    Button { showSettings = true } label: {
                        HStack(spacing: 5) { Image(systemName: "gearshape"); Text("앱 설정") }.font(.body)
                    }
                    .buttonStyle(.plain)

                    Divider().frame(height: 20)

                    Image(systemName: "mic").foregroundStyle(.secondary)
                    Button { showInputSource = true } label: {
                        HStack(spacing: 4) {
                            Text("입력 소스: \(currentInputName.isEmpty ? "기본 장치" : currentInputName)")
                            Image(systemName: "chevron.up.chevron.down").foregroundStyle(.secondary)
                        }.font(.body)
                    }
                    .buttonStyle(.plain)

                    Divider().frame(height: 20)

                    Button { showGlossary = true } label: {
                        HStack(spacing: 5) { Image(systemName: "character.book.closed"); Text("용어집") }.font(.body)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .imageScale(.large)

                // 2줄: 청중 QR · 세션 자막 선택 · QR 보기 · (호스트) · 자막 송출 시작 · 자막 리셋  (v2.37.0 순서 변경)
                HStack(spacing: 10) {
                    Button { showAudienceQR = true } label: {
                        HStack(spacing: 4) { Image(systemName: "qrcode"); Text("청중 QR") }.font(.body)
                    }
                    .buttonStyle(.bordered).controlSize(.large)

                    Image(systemName: broadcasting ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right")
                        .font(.body).foregroundStyle(broadcasting ? .red : .secondary)
                    Picker("", selection: $broadcastSessionId) {
                        Text("세션 자막 선택").tag("")
                        ForEach(qrSessions) { s in Text(sessionLabel(s)).tag(s.id) }
                    }
                    .labelsHidden().pickerStyle(.menu).controlSize(.large).fixedSize()
                    .disabled(broadcasting)

                    Button { showBroadcastQR = true } label: {
                        HStack(spacing: 4) { Image(systemName: "qrcode.viewfinder"); Text("QR 보기") }.font(.body)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    .disabled(broadcastSessionId.isEmpty)

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
    private var currentEventLogoPath: String {
            guard let d = audienceQREventJSON.data(using: .utf8),
                  let ev = try? JSONDecoder().decode(QREvent.self, from: d) else { return "" }
            return ev.logoPath
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
                                     sessionName: info.session, mode: mode, langs: langs,
                                     logoPath: currentEventLogoPath)
        audioBroadcaster.start(sessionId: broadcastSessionId)
        statusMessage = "📡 청중 송출 중"
    }

    // 단일 모드 자막 송출
    private func relaySingle() {
        guard relay.active else { return }
        // 청중에게도 용어집 적용된 텍스트를 보냄 (오버레이/콘솔과 동일하게 통일)
        let lines = Array(subtitles.segments.map { glossary.normalize($0.targetText) }.suffix(60))
        relay.updateLive(lang: settings.targetLang,
                         current: glossary.normalize(subtitles.currentTarget),
                         lines: lines)
    }
    // 다국어 모드 자막 송출 (언어 1개)
    private func relayMulti(_ lang: String) {
        guard relay.active else { return }
        // 청중에게도 용어집 적용된 텍스트를 보냄
        let lines = Array(multiStore.segments.compactMap { $0.targets[lang] }.map { glossary.normalize($0) }.suffix(60))
        relay.updateLive(lang: lang,
                         current: glossary.normalize(multiStore.currentTargets[lang] ?? ""),
                         lines: lines)
    }
    private func relayMultiAll() {
        guard relay.active else { return }
        for lang in audienceLangs { relayMulti(lang) }
    }

    // ───────────── Fish Audio TTS (v2.49.0) ─────────────
    // 특정 언어 1개만 Fish 음성으로 송출, 나머지는 Gemini. Fish는 자막(번역 텍스트)만 읽음.

    // 해당 언어가 Fish 송출 대상인지
    private func isFishLang(_ lang: String) -> Bool {
        settings.fishEnabled && !settings.fishLang.isEmpty && lang == settings.fishLang
    }

    // 확정된 번역 텍스트를 Fish TTS로 보내 음성 클립을 청중에게 송출
    // v2.50.0: turnComplete 대신 '문장 확정 콜백'에서 호출 (Gemini가 turnComplete를 거의 안 보냄)
    private func sendTextToFish(lang: String, text: String) {
        guard relay.active, settings.fishEnabled, !settings.fishApiKey.isEmpty else { return }
        let trimmed = glossary.normalize(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let config = FishAudioTTS.Config(
            apiKey: settings.fishApiKey,
            referenceId: settings.fishReferenceId,
            model: settings.fishModel,
            sampleRate: 24000
        )
        print("[BMG][Fish] 합성 요청: \(lang) \"\(trimmed.prefix(20))...\"")
        FishAudioTTS.synthesize(text: trimmed, config: config) { pcm in
            guard let pcm = pcm else { print("[BMG][Fish] 합성 실패"); return }
            // v2.52.0: 정지 후 늦게 도착한 콜백은 무시 (정지 중 pushClip 충돌 방지).
            //          콜백은 백그라운드 스레드이므로 메인에서 상태 재확인.
            DispatchQueue.main.async {
                guard self.relay.active, (self.isRunning || self.isMultiRunning) else {
                    print("[BMG][Fish] 정지됨 → 업로드 건너뜀")
                    return
                }
                print("[BMG][Fish] 합성 성공: \(pcm.count) bytes → 업로드")
                self.audioBroadcaster.pushClip(lang: lang, pcm16: pcm)
            }
        }
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
        // v2.50.0: 문장이 확정될 때마다 Fish 언어면 그 텍스트를 Fish로 송출
        subtitles.onSegmentCommitted = { target in
            if self.isFishLang(self.settings.targetLang) {
                self.sendTextToFish(lang: self.settings.targetLang, text: target)
            }
        }
        client.onInputTranscript = { t in DispatchQueue.main.async { self.subtitles.appendSource(t) } }
        client.onOutputTranscript = { t in DispatchQueue.main.async { self.subtitles.appendTarget(t); self.relaySingle() } }
        client.onAudio = { [audioPlayer] d in
                    audioPlayer.enqueue(pcm16: d)
                    // v2.49.0: Fish 대상 언어면 Gemini 음성을 청중 송출에서 제외(Fish로 대체)
                    if !self.isFishLang(self.settings.targetLang) {
                        self.audioBroadcaster.append(lang: self.settings.targetLang, pcm16: d)
                    }
                }
        client.onTurnComplete = { DispatchQueue.main.async {
            self.subtitles.finalizeTurn()
            self.relaySingle()
            // Fish 언어가 아니면 Gemini 누적분 마감 (Fish 언어는 문장 확정 콜백에서 처리)
            if !self.isFishLang(self.settings.targetLang) {
                self.audioBroadcaster.flushBoundary()
            }
        } }
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
            audioSilenceTime = 0          // v2.36.0
            setupAudioTimeout()           // v2.36.0
            if settings.playTranslatedAudio { audioPlayer.start() }
            beginBroadcastIfNeeded()
        } catch {
            statusMessage = "❌ 마이크 시작 실패: \(error.localizedDescription)"
            client.disconnect()
        }
    }

    private func stop() {
        // v2.52.0: 정지 시작 시 Fish 콜백 먼저 끊기 (finalizeTurn이 새 Fish 호출을 트리거하지 않게)
        subtitles.onSegmentCommitted = nil
        isRunning = false
        // v2.39.0: 저장 직전, 아직 확정 안 된 진행 중 자막을 강제 확정 (전사문 누락 방지)
        subtitles.finalizeTurn()
        // 내용이 있을 때만 저장 (헤더만 있는 빈 전사문 방지)
        // v2.53.0: 전사문 생성 시간 측정 + 파일 저장은 백그라운드로(메인 스레드 멈춤 방지)
        if hasAnyTranscriptContent() {
            let t0 = Date()
            let text = transcriptText(started: sessionStart)
            let dt = Date().timeIntervalSince(t0)
            print("[BMG] 전사문 생성 \(String(format: "%.2f", dt))초, \(subtitles.segments.count)개 세그먼트")
            let started = sessionStart
            DispatchQueue.global(qos: .utility).async {
                TranscriptArchive.autoSave(text, started: started)
            }
        }
        audio.stop()
        client.disconnect()
        audioPlayer.stop()
        relay.stopBroadcast()
        audioBroadcaster.stop()
        overlayController.hide()      // v2.42.0: 중지 시 오버레이 창도 닫기
        stopAudioTimeout()            // v2.36.0
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
        multiStore.sourceIsKorean = (settings.multiSourceLang == "ko")  // v2.48.0: 한국어 기준 문장 확정용
        statusMessage = "다국어 연결 중..."

        multiClient.onConnected = {
            DispatchQueue.main.async { self.statusMessage = "✅ 다국어 연결됨 (\(self.audienceLangs.count)개)" }
        }
        // v2.50.0: 문장이 확정될 때마다 Fish 언어가 청중 언어에 있으면 그 언어 번역을 Fish로 송출
        multiStore.onSegmentCommitted = { targets in
            guard self.settings.fishEnabled, !self.settings.fishLang.isEmpty else { return }
            let fl = self.settings.fishLang
            if self.audienceLangs.contains(fl), let t = targets[fl], !t.isEmpty {
                self.sendTextToFish(lang: fl, text: t)
            }
        }
        multiClient.onSource = { t in DispatchQueue.main.async { self.multiStore.appendSource(t) } }
        multiClient.onTarget = { lang, t in DispatchQueue.main.async { self.multiStore.appendTarget(lang, t); self.relayMulti(lang) } }
        multiClient.onAudio = { [audioPlayer] lang, d in
                    if lang == self.settings.multiAudioLang { audioPlayer.enqueue(pcm16: d) }
                    // v2.49.0: Fish 대상 언어면 Gemini 음성을 청중 송출에서 제외(Fish로 대체)
                    if !self.isFishLang(lang) {
                        self.audioBroadcaster.append(lang: lang, pcm16: d)
                    }
                }
        multiClient.onTurnComplete = { DispatchQueue.main.async {
            self.multiStore.finalizeTurn()
            self.relayMultiAll()
            self.audioBroadcaster.flushBoundary()
        } }
        multiClient.onError = { m in DispatchQueue.main.async { self.statusMessage = "❌ \(m)" } }

        audio.onAudioData = { [multiClient] d in multiClient.sendAudio(d) }

        multiClient.connect(apiKey: settings.geminiApiKey, sourceLang: settings.multiSourceLang, targets: targets)

        do {
            try audio.start()
            isMultiRunning = true
            multiSessionStart = Date()
            audioSilenceTime = 0          // v2.36.0
            setupAudioTimeout()           // v2.36.0
            if !settings.multiAudioLang.isEmpty { audioPlayer.start() }
            multiOverlay.show(store: multiStore)
            beginBroadcastIfNeeded()
        } catch {
            statusMessage = "❌ 마이크 시작 실패: \(error.localizedDescription)"
            multiClient.disconnect()
        }
    }

    private func stopMulti() {
        // v2.52.0: 정지 시작 시 Fish 콜백 먼저 끊기
        multiStore.onSegmentCommitted = nil
        isMultiRunning = false
        // v2.39.0: 저장 직전, 아직 확정 안 된 진행 중 자막을 강제 확정 (전사문 누락 방지)
        multiStore.finalizeTurn()
        // 내용이 있을 때만 저장 (헤더만 있는 빈 전사문 방지)
        // v2.53.0: 전사문 생성 시간 측정 + 파일 저장은 백그라운드로
        if hasAnyTranscriptContent() {
            let t0 = Date()
            let text = transcriptText(started: multiSessionStart)
            let dt = Date().timeIntervalSince(t0)
            print("[BMG] 전사문 생성 \(String(format: "%.2f", dt))초, \(multiStore.segments.count)개 세그먼트")
            let started = multiSessionStart
            DispatchQueue.global(qos: .utility).async {
                TranscriptArchive.autoSave(text, started: started)
            }
        }
        audio.stop()
        multiClient.disconnect()
        audioPlayer.stop()
        relay.stopBroadcast()
        audioBroadcaster.stop()
        multiOverlay.hide()           // v2.42.0: 중지 시 다국어 오버레이 창도 닫기
        stopAudioTimeout()            // v2.36.0
        multiSessionStart = nil
        statusMessage = "정지됨"
    }

    // v2.36.0 추가: 음성 입력이 일정 시간 없으면 통역 자동 중지
    private func setupAudioTimeout() {
        stopAudioTimeout()  // 기존 타이머 정리
        guard settings.secondsWithoutAudio > 0 else { return }
        audioTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            guard self.isRunning || self.isMultiRunning else { return }
            // v2.51.0: 무음 판정 기준 500 → 50. 외부 오디오 인터페이스는 입력 레벨이 낮게
            //          들어와 발화 중에도 RMS가 500 미만인 경우가 많아 오작동하던 문제 수정.
            //          진짜 무음은 RMS 한 자리수~십 단위라 50이면 발화와 잘 구분됨.
            if let rms = self.lastAudioRMS, rms < 50 {
                self.audioSilenceTime += 0.5
            } else {
                self.audioSilenceTime = 0
            }
            let timeout = Double(self.settings.secondsWithoutAudio)
            if self.audioSilenceTime >= timeout {
                print("[BMG] 음성 입력 없음(\(Int(timeout))초) → 통역 자동 중지")
                if self.isRunning { self.stop() }
                if self.isMultiRunning { self.stopMulti() }
                self.statusMessage = "음성 입력이 없어 자동 중지됨"
            }
        }
    }

    private func stopAudioTimeout() {
        audioTimeoutTimer?.invalidate()
        audioTimeoutTimer = nil
        audioSilenceTime = 0
    }

    // ── 전사문에 저장할 내용이 하나라도 있는지 (v2.39.0) ──
    private func hasAnyTranscriptContent() -> Bool {
        if !subtitles.segments.isEmpty { return true }
        if !subtitles.currentSource.isEmpty || !subtitles.currentTarget.isEmpty { return true }
        if !multiStore.segments.isEmpty { return true }
        if !multiStore.currentSource.isEmpty { return true }
        if multiStore.currentTargets.values.contains(where: { !$0.isEmpty }) { return true }
        return false
    }

    // ── 전사문 텍스트 생성 (v2.20.0, v2.24.0: 시작 시각 매개변수화) ──
    // 다국어 세션 내용이 있으면 다국어 형식, 아니면 단일 언어 형식으로 구성.
    // v2.39.0: 아직 확정되지 않은 진행 중 자막(current*)도 함께 출력 → 짧은 세션 누락 방지.
    private func transcriptText(started: Date?) -> String {
        var lines: [String] = []
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        lines.append("BoothmateG 전사문 — \(f.string(from: started ?? Date()))")
        lines.append(String(repeating: "─", count: 24))
        lines.append("")

        // 다국어/단일 판단: 확정된 세그먼트 또는 진행 중 내용이 있으면 그 모드로 간주
        let hasMulti = !multiStore.segments.isEmpty
            || !multiStore.currentSource.isEmpty
            || multiStore.currentTargets.values.contains { !$0.isEmpty }

        if hasMulti {
            // 이 세션에 실제로 번역문이 담긴 언어 목록 (확정 + 진행 중 모두 고려)
            var usedLangs: [String] = []
            for lang in multiStore.langs {
                let inSegments = multiStore.segments.contains { ($0.targets[lang]?.isEmpty == false) }
                let inCurrent = (multiStore.currentTargets[lang]?.isEmpty == false)
                if inSegments || inCurrent { usedLangs.append(lang) }
            }
            // langs에 없지만 데이터에 존재하는 언어도 누락 없이 포함
            for seg in multiStore.segments {
                for lang in seg.targets.keys where !(seg.targets[lang]?.isEmpty ?? true) {
                    if !usedLangs.contains(lang) { usedLangs.append(lang) }
                }
            }
            for lang in multiStore.currentTargets.keys where !(multiStore.currentTargets[lang]?.isEmpty ?? true) {
                if !usedLangs.contains(lang) { usedLangs.append(lang) }
            }

            if !usedLangs.isEmpty {
                lines.append("화자: \(langLabel(settings.multiSourceLang))")
                lines.append("청중 언어: \(usedLangs.map { langLabel($0) }.joined(separator: ", "))")
                lines.append("")
            }

            // 확정된 세그먼트
            for seg in multiStore.segments {
                if !seg.source.isEmpty { lines.append("· \(seg.source)") }
                for lang in usedLangs {
                    if let t = seg.targets[lang], !t.isEmpty {
                        lines.append("[\(langLabel(lang))] \(glossary.normalize(t))")
                    }
                }
                lines.append("")
            }
            // 아직 확정 안 된 진행 중 자막
            let curHasContent = !multiStore.currentSource.isEmpty
                || multiStore.currentTargets.values.contains { !$0.isEmpty }
            if curHasContent {
                if !multiStore.currentSource.isEmpty { lines.append("· \(multiStore.currentSource)") }
                for lang in usedLangs {
                    if let t = multiStore.currentTargets[lang], !t.isEmpty {
                        lines.append("[\(langLabel(lang))] \(glossary.normalize(t))")
                    }
                }
                lines.append("")
            }
        } else {
            // 확정된 세그먼트
            for seg in subtitles.segments {
                if !seg.sourceText.isEmpty { lines.append("· \(seg.sourceText)") }
                if !seg.targetText.isEmpty { lines.append(glossary.normalize(seg.targetText)) }
                lines.append("")
            }
            // 아직 확정 안 된 진행 중 자막
            if !subtitles.currentSource.isEmpty || !subtitles.currentTarget.isEmpty {
                if !subtitles.currentSource.isEmpty { lines.append("· \(subtitles.currentSource)") }
                if !subtitles.currentTarget.isEmpty { lines.append(glossary.normalize(subtitles.currentTarget)) }
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
