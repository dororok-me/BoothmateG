//
//  AudienceLangView.swift
//  BoothmateG
//
//  Version: 1.4.0
//  Changelog:
//    1.4.0 - 번역어(동시 세션) 상한 4개 추가(과부하·다운 방지). 4개 도달 시 더 못 고르고 안내.
//    1.3.0 - [통합] 화자 개념 제거. 모든 언어를 번역어로 선택 가능(targetCandidates 필터 폐기).
//            문구 "청중 언어"→"번역어". speakerLabel 제거(미사용).
//    1.0.0 - 최초 작성. 청중 언어(여러 개)를 체크로 고르는 시트.
//    1.1.0 - 불러올 때 화자 언어/유효하지 않은 코드를 제외 (개수·체크 표시 정확화).
//    1.2.0 - 화자 기준을 단일 소스 → 다국어 화자(multiSourceLang)로 변경.
//

import SwiftUI

struct AudienceLangView: View {
    @ObservedObject var settings: AppSettings
    var onDone: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []
    private let maxLangs = 4   // v1.4.0: 번역어(동시 세션) 상한 — 과부하·다운 방지

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("번역어 선택").font(.title3).bold()
                Spacer()
                Text("\(selected.count) / \(maxLangs)개")
                    .foregroundStyle(selected.count >= maxLangs ? .orange : .secondary)
            }

            Text("발화를 아래에서 고른 언어들로 동시에 표시·번역합니다. 입력 언어는 자동으로 감지됩니다.")
                .font(.caption).foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(targetCandidates) { lang in
                        Button {
                            if selected.contains(lang.id) { selected.remove(lang.id) }
                            else if selected.count < maxLangs { selected.insert(lang.id) }   // v1.4.0: 상한 초과 시 무시
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
                Text("최대 \(maxLangs)개까지. 세션이 언어 수만큼 늘어 비용·부하도 함께 증가해요.")
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
        .onAppear {
            // 화자 언어와 목록에 없는 코드는 제외하고 불러옴 (개수/체크 정확화)
            let valid = Set(targetCandidates.map { $0.id })
            selected = Set(settings.loadAudienceLangs()).intersection(valid)
        }
    }

    // v1.3.0: [통합] 화자 개념 제거 — 모든 언어를 번역어 후보로.
    private var targetCandidates: [LangOption] {
        supportedLanguages
    }
}
