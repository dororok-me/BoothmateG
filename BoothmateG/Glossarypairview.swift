//
//  GlossaryPairView.swift
//  BoothmateG
//
//  Version: 1.8.0
//  Changelog:
//    1.7.0 - 엔터(Return)로도 저장: 저장 버튼에 .defaultAction 단축키 지정.
//    1.6.0 - 저장=빈 유사표현 AI 자동생성 후 저장, 창은 유지(닫히지 않음).
//            닫기는 우상단 X + 하단 '닫기' 버튼으로만. 글자·버튼·창 크기 확대(접근성).
//    1.8.0 - systemInstruction 방식 전환에 따른 정리: 유사 표현 칸·AI 자동 생성 버튼 제거.
//            영어↔한국어 쌍만 입력(AI가 통역 단계에서 의미로 반영). 카드 1줄로 단순화.
//            learnedText는 데이터 호환 위해 모델에만 보존(UI 비노출).
//    1.5.0 - UI 용어 정리: '번역어' → '유사 표현', 버튼 'AI 번역어 생성' → 'AI 자동 생성'.
//    1.4.0 - 2줄 카드: 윗줄 영어↔한국어, 아랫줄 번역어 전체 폭(끊김 없이 다 보임).
//    1.3.0 - 칸 영-한 고정(왼쪽 영어, 오른쪽 한국어) + 라벨/안내 명확화. 양방향 매칭 안정화.
//    1.2.0 - AI 번역어 자동 생성('AI 번역어 생성' 버튼): 빈 번역어 칸을 Gemini가 채움.
//            생성 후 사용자가 수정 가능. 진행 표시 + 생성 중 저장/생성 비활성화.
//    1.1.0 - 번역어 입력칸 추가(원문어=표준표기=번역어). '이 방식 사용' 토글 추가.
//    1.0.0 - 새 방식(번역쌍 매칭) 용어집 편집 창.
//            원문어(source) = 표준표기(canonical) 한 쌍으로 등록.
//            예: patient = 피험자  →  원문에 patient가 나오면 타겟을 피험자로 통일.
//            유사어를 일일이 등록할 필요 없음(앱이 실제 번역어를 학습/캐시).
//            기존 GlossaryView(동일언어 치환)와 별도. 데이터도 별도(glossaryPairJSON).
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct GlossaryPairView: View {
    @ObservedObject var settings: AppSettings

    // 시트가 닫힐 때 호출 → 새 방식 엔진에 즉시 반영
    var onApply: ([GlossaryPair]) -> Void

    @Environment(\.dismiss) private var dismiss

    // 편집용 카드 모델
    private struct Draft: Identifiable {
        let id = UUID()
        var source: String = ""        // 원문어 (예: patient)
        var canonical: String = ""     // 타겟 표준표기 (예: 피험자)
        var learnedText: String = ""   // 번역어 캐시 (콤마 구분 문자열, 예: "환자, 환자분")
    }

    @State private var drafts: [Draft] = []
    @FocusState private var focusedField: UUID?
    @State private var showResetConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // 헤더
            HStack {
                Text("용어집 (새 방식)").font(.title2).bold()
                Spacer()
                Toggle("이 방식 사용", isOn: $settings.useGlossaryPairMode)
                    .toggleStyle(.switch)
                    .help("켜면 새 방식(번역쌍 매칭), 끄면 기존 방식(동일언어 치환)이 자막에 적용됩니다.")
                Button {
                    let d = Draft()
                    drafts.append(d)
                    focusedField = d.id
                } label: {
                    Label("용어 추가", systemImage: "plus").font(.body)
                }
                // 우상단 닫기(X)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("닫기")
            }

            Text("왼쪽에 영어, 오른쪽에 한국어를 넣으세요(예: patient = 피험자). 양방향으로 적용됩니다: 영어 원문에 patient가 나오면 한국어를 ‘피험자’로, 한국어 원문에 피험자가 나오면 영어를 ‘patient’로 통일합니다. 등록한 용어를 AI가 통역 단계에서 그대로 반영합니다. ‘이 방식 사용’을 켜고 ‘저장’ 후 ‘시작’하면 적용됩니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 용어 카드 목록
            ScrollView {
                VStack(spacing: 8) {
                    ForEach($drafts) { $d in
                        card($d)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(minHeight: 280)

            if drafts.isEmpty {
                Text("등록된 용어가 없습니다. ‘용어 추가’를 눌러 시작하세요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }

            Divider()

            HStack(spacing: 10) {
                Button {
                    importPairs()
                } label: { Label("가져오기", systemImage: "square.and.arrow.down") }
                Button {
                    exportPairs()
                } label: { Label("내보내기", systemImage: "square.and.arrow.up") }
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: { Label("리셋", systemImage: "trash") }

                Spacer()
                // 닫기(저장 안 함, 창만 닫기)
                Button("닫기") { dismiss() }
                    .controlSize(.large)
                // 저장(엔진 반영) → 창은 유지. 닫기는 X/닫기 버튼으로만.
                Button("저장") { save() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)   // 엔터(Return)로도 저장
            }
            .font(.body)
        }
        .padding(24)
        .frame(width: 760, height: 620)
        .onAppear { load() }
        .alert("용어집을 모두 비울까요?", isPresented: $showResetConfirm) {
            Button("취소", role: .cancel) {}
            Button("모두 삭제", role: .destructive) { drafts.removeAll() }
        } message: {
            Text("현재 편집 중인 모든 용어가 사라집니다. ‘저장’을 눌러야 실제로 반영됩니다.")
        }
    }

    // ── 용어 카드 1개 (영어 ↔ 한국어 쌍만) ──
    @ViewBuilder
    private func card(_ d: Binding<Draft>) -> some View {
        HStack(spacing: 8) {
            TextField("영어 (예: patient)", text: d.source)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .focused($focusedField, equals: d.wrappedValue.id)
            Image(systemName: "arrow.left.and.right")
                .font(.title3)
                .foregroundStyle(.secondary)
                .help("양방향: 영어가 나오면 한국어로, 한국어가 나오면 영어로 통일")
            TextField("한국어 (예: 피험자)", text: d.canonical)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
            Button(role: .destructive) {
                drafts.removeAll { $0.id == d.wrappedValue.id }
            } label: {
                Image(systemName: "trash").font(.title3)
            }
            .buttonStyle(.borderless)
            .frame(width: 28)
        }
        .padding(10)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
    }

    // ── 불러오기 ──
    private func load() {
        drafts = settings.loadGlossaryPairs().map {
            Draft(source: $0.source, canonical: $0.canonical,
                  learnedText: $0.learnedTargets.joined(separator: ", "))
        }
    }

    // ── 저장(엔진 반영, 창은 닫지 않음) ──
    private func save() {
        let items: [GlossaryPair] = drafts.compactMap { d in
            let s = d.source.trimmingCharacters(in: .whitespaces)
            let c = d.canonical.trimmingCharacters(in: .whitespaces)
            guard !s.isEmpty, !c.isEmpty else { return nil }   // 둘 다 있어야 의미 있음
            let learned = d.learnedText.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return GlossaryPair(source: s, canonical: c, learnedTargets: learned)
        }
        settings.saveGlossaryPairs(items)
        onApply(items)
        // 창은 닫지 않음 — 닫기(X/닫기 버튼)로만 닫힘.
    }

    // ── 내보내기: 탭 구분 (원문어<TAB>표준표기<TAB>학습캐시) ──
    private func exportPairs() {
        let header = "원문어\t표준표기\t학습된번역어"
        let lines = drafts.map { d in
            [d.source, d.canonical, d.learnedText]
                .map { $0.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }
                .joined(separator: "\t")
        }
        let content = ([header] + lines).joined(separator: "\n")

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.nameFieldStringValue = "glossary_pairs.csv"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // ── 가져오기: 탭 우선, 없으면 콤마 ──
    private func importPairs() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText, .text]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let raw = try? String(contentsOf: url, encoding: .utf8) else { return }

        var added: [Draft] = []
        for rawLine in raw.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            if line.hasPrefix("원문어") { continue }   // 헤더 건너뜀
            let sep: Character = line.contains("\t") ? "\t" : ","
            let cols = line.split(separator: sep, omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
            func col(_ i: Int) -> String { i < cols.count ? cols[i] : "" }
            let s = col(0), c = col(1)
            if s.isEmpty && c.isEmpty { continue }
            added.append(Draft(source: s, canonical: c, learnedText: col(2)))
        }
        if !added.isEmpty { drafts.append(contentsOf: added) }
    }
}
