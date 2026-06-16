//
//  ConsoleSettingsView.swift
//  BoothmateG
//
//  Version: 1.3.0
//  Changelog:
//    1.0.0 - 최초 작성. 글자 크기 + 야간 모드
//    1.1.0 - 맨 아래에 Gemini API 키 입력 추가 (메인 콘솔에서 이관)
//    1.2.0 - 전사문 섹션 추가: 자동 저장 안내 + 내보내기/저장 폴더 열기 버튼
//    1.3.0 - 음성 입력 자동 중지 옵션 추가(secondsWithoutAudio: 끄기/1/3/5/10분).
//

import SwiftUI

struct ConsoleSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // API 키는 AppSettings에 저장 → 같은 객체를 직접 편집
    @ObservedObject var settings: AppSettings

    // 전사문 내보내기 (현재 전사문을 .txt로 저장) — ContentView가 구현
    var onExportTranscript: () -> Void = {}

    // ContentView와 동일한 키를 사용 → 자동 동기화
    @AppStorage("console_targetFont") private var targetFont: Double = 18
    @AppStorage("console_sourceFont") private var sourceFont: Double = 14
    @AppStorage("console_night")      private var night: Bool = false

    var body: some View {
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

            Divider()

            // ── 음성 입력 자동 중지 (v1.3.0) ──
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "pause.circle")
                    Text("무음 시 자동 중지").font(.subheadline.weight(.semibold))
                }
                Picker("", selection: $settings.secondsWithoutAudio) {
                    Text("끄기").tag(0)
                    Text("1분").tag(60)
                    Text("3분").tag(180)
                    Text("5분").tag(300)
                    Text("10분").tag(600)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("음성 입력이 설정한 시간 동안 없으면 통역을 자동으로 멈춰요.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
                Text("세션을 정지하면 전사문이 자동으로 저장됩니다. 최근 50개 세션까지 보관돼요. (파일명에 날짜·시간 포함, .txt)")
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

            // ── Gemini API 키 (가장 아래) ──
            VStack(alignment: .leading, spacing: 6) {
                Text("Gemini API 키").font(.subheadline.weight(.semibold))
                SecureField("API 키를 입력하세요", text: $settings.geminiApiKey)
                    .textFieldStyle(.roundedBorder)
                Text("입력한 키는 이 기기에만 저장됩니다 (BYOK).")
                    .font(.caption2).foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("닫기") { dismiss() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(width: 460, height: 680)
        .preferredColorScheme(night ? .dark : nil)
    }
}
