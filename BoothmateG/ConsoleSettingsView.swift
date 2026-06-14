//
//  ConsoleSettingsView.swift
//  BoothmateG
//
//  Version: 1.1.0
//  Changelog:
//    1.0.0 - 최초 작성. 글자 크기 + 야간 모드
//    1.1.0 - 맨 아래에 Gemini API 키 입력 추가 (메인 콘솔에서 이관)
//

import SwiftUI

struct ConsoleSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // API 키는 AppSettings에 저장 → 같은 객체를 직접 편집
    @ObservedObject var settings: AppSettings

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
        .frame(width: 460, height: 480)
        .preferredColorScheme(night ? .dark : nil)
    }
}
