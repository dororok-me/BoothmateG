//
//  ConsoleSettingsView.swift
//  BoothmateG
//
//  Version: 1.7.0
//  Changelog:
//    1.7.0 - 전사문 보관 안내 문구를 "최근 50개 세션" → "최근 3개월"로 수정(TranscriptArchive 1.1.0 정책 반영).
//    1.6.0 - 환경 내보내기/가져오기 섹션 추가(.boothmate). 용어집·통역 지침·블랙리스트·행사정보를
//            항목 선택(체크박스)해 한 파일로 묶어 백업/이전. 가져오기는 파일에 있고+선택한 항목만 적용.
//    1.5.0 - 단위·환율 자동 변환 토글(convertUnitsCurrency) UI 추가. 번역 음성 재생 토글 아래.
//    1.3.0 - Fish Audio TTS 설정 섹션 추가(켜기/언어/API키/음성ID). 전체 ScrollView화.
//    1.4.0 - 음성 입력 자동 중지 Picker 추가(끄기/1/3/5/10분). 높이 760.
//  Changelog:
//    1.0.0 - 최초 작성. 글자 크기 + 야간 모드
//    1.1.0 - 맨 아래에 Gemini API 키 입력 추가 (메인 콘솔에서 이관)
//    1.2.0 - 전사문 섹션 추가: 자동 저장 안내 + 내보내기/저장 폴더 열기 버튼
//

import SwiftUI
import AppKit

struct ConsoleSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // API 키는 AppSettings에 저장 → 같은 객체를 직접 편집
    @ObservedObject var settings: AppSettings

    // 전사문 내보내기 (현재 전사문을 .txt로 저장) — ContentView가 구현
    var onExportTranscript: () -> Void = {}

    // v1.6.0: 환경 가져오기 후 ContentView가 행사정보(@State)를 다시 로드하도록 알림
    var onDataImported: () -> Void = {}

    // v1.6.0: 환경 백업 항목 선택
    @State private var bxGlossary = true
    @State private var bxGuide = true
    @State private var bxBlacklist = true
    @State private var bxEvent = true
    @State private var bundleMessage: String? = nil
    @State private var bundleMessageColor: Color = .green

    // ContentView와 동일한 키를 사용 → 자동 동기화
    @AppStorage("console_targetFont") private var targetFont: Double = 18
    @AppStorage("console_sourceFont") private var sourceFont: Double = 14
    @AppStorage("console_night")      private var night: Bool = false

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {

            // 헤더
            HStack {
                Text("메인 콘솔 설정").font(.title3).bold()
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }

            Divider()

            // ── 글자 크기 ──
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("번역 글자 크기")
                        .frame(width: 110, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Slider(value: $targetFont, in: 12...40, step: 1)
                    Text("\(Int(targetFont))pt").frame(width: 42).font(.caption)
                }
                HStack(spacing: 8) {
                    Text("원문 글자 크기")
                        .frame(width: 110, alignment: .leading)
                        .foregroundStyle(.secondary)
                    Slider(value: $sourceFont, in: 10...32, step: 1)
                    Text("\(Int(sourceFont))pt").frame(width: 42).font(.caption)
                }
            }

            Divider()

            // ── 야간 모드 ──
            Toggle(isOn: $night) {
                HStack(spacing: 6) {
                    Image(systemName: night ? "moon.fill" : "moon")
                    Text("야간 모드 (Night View)")
                }
            }
            .toggleStyle(.switch)

            // ── 번역 음성 재생 ──
            Toggle(isOn: $settings.playTranslatedAudio) {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.2.fill")
                    Text("번역 음성 재생")
                }
            }
            .toggleStyle(.switch)

            // ── 단위·환율 자동 변환 (단일 언어 모드) ──  v1.5.0
            Toggle(isOn: $settings.convertUnitsCurrency) {
                HStack(spacing: 6) {
                    Image(systemName: "ruler.fill")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("단위·환율 자동 변환")
                        Text("예: 5마일(8km), $1,000(1,400만원) · 영한 단일 언어만")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .toggleStyle(.switch)

            // ── 미리보기 ──
            VStack(alignment: .leading, spacing: 4) {
                Text("미리보기").font(.caption).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("안녕하세요, 반갑습니다.")
                        .font(.system(size: sourceFont))
                        .foregroundStyle(.secondary)
                    Text("Hello, nice to meet you.")
                        .font(.system(size: targetFont, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(night ? Color.black : Color.blue.opacity(0.06))
                .cornerRadius(6)
            }

            Divider()

            // ── 전사문 ──
            VStack(alignment: .leading, spacing: 8) {
                Text("전사문").font(.subheadline.weight(.semibold))
                Text("세션을 정지하면 전사문이 자동으로 저장됩니다. 최근 3개월까지 보관돼요. (파일명에 날짜·시간 포함, .txt)")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button {
                        onExportTranscript()
                    } label: {
                        Label("전사문 내보내기", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        TranscriptArchive.openFolder()
                    } label: {
                        Label("저장 폴더 열기", systemImage: "folder")
                    }
                }
            }

            Divider()

            // ── 음성 입력 자동 중지 (v1.4.0) ──
            VStack(alignment: .leading, spacing: 8) {
                Text("음성 입력 자동 중지").font(.subheadline.weight(.semibold))
                HStack {
                    Text("무음 지속 시").font(.caption)
                    Spacer()
                    Picker("", selection: $settings.secondsWithoutAudio) {
                        Text("끄기").tag(0)
                        Text("1분").tag(60)
                        Text("3분").tag(180)
                        Text("5분").tag(300)
                        Text("10분").tag(600)
                    }
                    .labelsHidden()
                    .frame(maxWidth: 200)
                }
                Text("입력이 일정 시간 무음이면 통역을 자동으로 멈춥니다. 외부 오디오 인터페이스를 쓰거나 긴 행사에서는 '끄기'를 권장합니다.")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Divider()

            // ── Fish Audio TTS (v1.3.0) ──
            // 지정 언어 1개만 Fish 음성으로 송출, 나머지는 Gemini. Fish는 자막(번역 텍스트)만 읽음.
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $settings.fishEnabled) {
                    Text("Fish Audio 음성 사용").font(.subheadline.weight(.semibold))
                }
                Text("선택한 언어 1개만 Fish 음성으로 내보내고, 나머지는 Gemini 기본 음성으로 송출합니다.")
                    .font(.caption2).foregroundStyle(.secondary)

                if settings.fishEnabled {
                    // Fish 음성으로 내보낼 언어
                    HStack {
                        Text("Fish 음성 언어").font(.caption)
                        Spacer()
                        Picker("", selection: $settings.fishLang) {
                            Text("끄기").tag("")
                            ForEach(supportedLanguages, id: \.id) { lang in
                                Text(lang.label).tag(lang.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: 220)
                    }
                    Text("단일 모드는 출력 언어를, 다국어 모드는 청중 언어 중 하나를 고르세요.")
                        .font(.caption2).foregroundStyle(.secondary)

                    // Fish API 키
                    SecureField("Fish Audio API 키", text: $settings.fishApiKey)
                        .textFieldStyle(.roundedBorder)

                    // 음성 모델 ID (선택)
                    TextField("음성 모델 ID (비우면 기본 음성)", text: $settings.fishReferenceId)
                        .textFieldStyle(.roundedBorder)
                    Text("fish.audio의 '나의 목소리들' 또는 Discover에서 음성 ID를 복사해 넣으세요. 비우면 기본 음성.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            Divider()

            // ── v1.6.0: 환경 백업 (.boothmate) ──
            // 용어집·통역 지침·블랙리스트·행사정보를 한 파일로 묶어 다른 컴퓨터로 옮기거나 백업.
            VStack(alignment: .leading, spacing: 8) {
                Text("환경 내보내기 / 가져오기").font(.subheadline.weight(.semibold))
                Text("용어집·통역 지침·블랙리스트·행사정보를 한 파일(.boothmate)로 저장해 다른 컴퓨터에서 그대로 불러옵니다. 아래에서 포함할 항목을 고르세요. (가져오기는 파일에 있고 + 선택한 항목만 적용됩니다.)")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // 항목 선택
                VStack(alignment: .leading, spacing: 2) {
                    Toggle("용어집", isOn: $bxGlossary)
                    Toggle("통역 지침", isOn: $bxGuide)
                    Toggle("블랙리스트", isOn: $bxBlacklist)
                    Toggle("행사 정보", isOn: $bxEvent)
                }
                .toggleStyle(.checkbox)
                .font(.callout)

                HStack(spacing: 8) {
                    Button {
                        exportBundle()
                    } label: {
                        Label("내보내기", systemImage: "square.and.arrow.up")
                    }
                    .disabled(!(bxGlossary || bxGuide || bxBlacklist || bxEvent))
                    Button {
                        importBundle()
                    } label: {
                        Label("가져오기", systemImage: "square.and.arrow.down")
                    }
                    Spacer()
                    if let msg = bundleMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(bundleMessageColor)
                            .transition(.opacity)
                    }
                }
            }

            Divider()

            // ── Gemini API 키 (가장 아래) ──
            VStack(alignment: .leading, spacing: 6) {
                Text("Gemini API 키").font(.subheadline.weight(.semibold))
                SecureField("API 키를 입력하세요", text: $settings.geminiApiKey)
                    .textFieldStyle(.roundedBorder)
                Text("입력한 키는 이 기기에만 저장됩니다 (BYOK).")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Button("닫기") { dismiss() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        }
        .frame(width: 460, height: 760)
        .preferredColorScheme(night ? .dark : nil)
    }

    // ── v1.6.0: 환경 번들 내보내기/가져오기 ──
    private func currentItems() -> AppSettings.BundleItems {
        AppSettings.BundleItems(glossary: bxGlossary, guide: bxGuide,
                                blacklist: bxBlacklist, event: bxEvent)
    }

    private func flash(_ msg: String, _ color: Color) {
        bundleMessageColor = color
        withAnimation { bundleMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { bundleMessage = nil }
        }
    }

    private func exportBundle() {
        guard let data = settings.makeBundleData(currentItems()) else {
            flash("내보내기 실패", .red); return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "boothmate_환경.boothmate"
        panel.canCreateDirectories = true
        panel.title = "환경 내보내기"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                flash("내보내기 완료", .green)
            } catch {
                flash("저장 실패", .red)
            }
        }
    }

    private func importBundle() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "환경 가져오기 (.boothmate)"
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }

        let result = settings.applyBundleData(data, items: currentItems())
        if result.ok {
            if result.applied.isEmpty {
                flash("적용할 항목이 없습니다", .orange)
            } else {
                onDataImported()   // ContentView가 행사정보 등 다시 로드
                flash("가져오기 완료: \(result.applied.joined(separator: ", "))", .green)
            }
        } else {
            flash("올바른 BoothmateG 환경 파일이 아닙니다", .red)
        }
    }
}
