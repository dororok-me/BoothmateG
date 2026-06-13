//
//  GlossaryView.swift
//  BoothmateG
//
//  Version: 1.2.0
//  Changelog:
//    1.0.0 - 최초 작성. 용어집 편집 시트
//    1.1.0 - 양방향 별칭(콤마) 입력
//    1.2.0 - 직관적 카드 형태로 개편:
//            · 버튼명 "행 추가" → "용어 추가"
//            · 용어 카드마다 위=표준 표현(대표), 아래=유사 표현(콤마)
//            · 한↔영 양방향 유지 (저장은 "표준, 유사1, 유사2" 형태로 기존 호환)
//

import SwiftUI

struct GlossaryView: View {
    @ObservedObject var settings: AppSettings

    // 시트가 닫힐 때 호출 → 글로서리 엔진에 즉시 반영
    var onApply: ([GlossaryItem]) -> Void

    @Environment(\.dismiss) private var dismiss

    // 편집용 카드 모델
    private struct Draft: Identifiable {
        let id = UUID()
        var koStd: String = ""   // 한국어 표준 표현
        var koSim: String = ""   // 한국어 유사 표현 (콤마)
        var enStd: String = ""   // 영어 표준 표현
        var enSim: String = ""   // 영어 유사 표현 (콤마)
    }

    @State private var drafts: [Draft] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // 헤더
            HStack {
                Text("용어집").font(.title3).bold()
                Spacer()
                Button {
                    drafts.append(Draft())
                } label: {
                    Label("용어 추가", systemImage: "plus")
                }
            }

            Text("‘표준 표현’이 화면에 표시될 대표 표기입니다. ‘유사 표현’에 콤마로 변형들을 넣으면, 번역문에 그 변형이 나올 때 표준 표현으로 자동 통일됩니다 (한↔영 양방향).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 용어 카드 목록
            ScrollView {
                VStack(spacing: 10) {
                    ForEach($drafts) { $d in
                        card($d)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(minHeight: 280)

            if drafts.isEmpty {
                Text("등록된 용어가 없습니다. ‘용어 추가’를 눌러 시작하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }

            Divider()

            HStack {
                Button("취소") { dismiss() }
                Spacer()
                Button("저장") { save() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 640, height: 540)
        .onAppear { load() }
    }

    // ── 용어 카드 1개 ──
    @ViewBuilder
    private func card(_ d: Binding<Draft>) -> some View {
        VStack(spacing: 6) {

            // 표준 표현 (대표) — 한국어 ⇄ 영어
            HStack(spacing: 8) {
                Text("표준 표현")
                    .font(.caption.weight(.semibold))
                    .frame(width: 64, alignment: .leading)
                TextField("예: 넷제로", text: d.koStd)
                    .textFieldStyle(.roundedBorder)
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.secondary)
                TextField("예: Net Zero", text: d.enStd)
                    .textFieldStyle(.roundedBorder)
                Button(role: .destructive) {
                    drafts.removeAll { $0.id == d.wrappedValue.id }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .frame(width: 24)
            }

            // 유사 표현 (콤마) — 한국어 / 영어
            HStack(spacing: 8) {
                Text("유사 표현")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)
                TextField("제로배출, 무배출", text: d.koSim)
                    .textFieldStyle(.roundedBorder)
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.clear)   // 위 줄과 정렬용(투명)
                TextField("net zero, zero emission", text: d.enSim)
                    .textFieldStyle(.roundedBorder)
                Spacer().frame(width: 24)      // 휴지통 자리만큼 비움
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
    }

    // ── 불러오기: 저장된 GlossaryItem → 카드 ──
    private func load() {
        drafts = settings.loadGlossary().map { item in
            let (koS, koR) = splitFirst(item.source)
            let (enS, enR) = splitFirst(item.target)
            return Draft(koStd: koS, koSim: koR, enStd: enS, enSim: enR)
        }
    }

    // ── 저장: 카드 → GlossaryItem("표준, 유사1, 유사2") ──
    private func save() {
        let items: [GlossaryItem] = drafts.compactMap { d in
            let source = join(std: d.koStd, similars: d.koSim)
            let target = join(std: d.enStd, similars: d.enSim)
            // 양쪽 다 비면 버림 (한쪽만 채운 단방향 항목은 허용)
            guard !(source.isEmpty && target.isEmpty) else { return nil }
            return GlossaryItem(source: source, target: target)
        }
        settings.saveGlossary(items)
        onApply(items)
        dismiss()
    }

    // "넷제로, 제로배출, 무배출" → ("넷제로", "제로배출, 무배출")
    private func splitFirst(_ s: String) -> (String, String) {
        let parts = s.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let first = parts.first else { return ("", "") }
        return (first, parts.dropFirst().joined(separator: ", "))
    }

    // 표준 + 유사 → "표준, 유사1, 유사2"  (표준이 비면 그 칸은 빈 문자열)
    private func join(std: String, similars: String) -> String {
        let s = std.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return "" }
        let extra = similars.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return ([s] + extra).joined(separator: ", ")
    }
}
