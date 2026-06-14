//
//  AudienceLangView.swift
//  BoothmateG
//
//  Version: 1.0.0
//  Changelog:
//    1.0.0 - 최초 작성. 청중 언어(여러 개)를 체크로 고르는 시트.
//

import SwiftUI

struct AudienceLangView: View {
    @ObservedObject var settings: AppSettings
    var onDone: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("청중 언어 선택").font(.title3).bold()
                Spacer()
                Text("\(selected.count)개").foregroundStyle(.secondary)
            }

            Text("화자 언어(\(speakerLabel))를 아래 선택한 언어들로 동시에 번역합니다.")
                .font(.caption).foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(targetCandidates) { lang in
                        Button {
                            if selected.contains(lang.id) { selected.remove(lang.id) }
                            else { selected.insert(lang.id) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: selected.contains(lang.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(lang.id) ? .green : .secondary)
                                Text(lang.label)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }

            HStack {
                Text("세션이 언어 수만큼 늘어 비용도 비례해서 증가해요.")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("취소") { dismiss() }
                Button("저장") {
                    // supportedLanguages 순서를 유지해 저장
                    let arr = targetCandidates.map { $0.id }.filter { selected.contains($0) }
                    settings.saveAudienceLangs(arr)
                    onDone(arr)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440, height: 540)
        .onAppear { selected = Set(settings.loadAudienceLangs()) }
    }

    // 화자 언어는 타겟 후보에서 제외
    private var targetCandidates: [LangOption] {
        supportedLanguages.filter { $0.id != settings.sourceLang }
    }

    private var speakerLabel: String {
        supportedLanguages.first { $0.id == settings.sourceLang }?.label ?? settings.sourceLang
    }
}
