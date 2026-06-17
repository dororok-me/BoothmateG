//
//  GlossaryView.swift
//  BoothmateG
//
//  Version: 1.5.0
//  Changelog:
//    1.0.0 - 최초 작성. 용어집 편집 시트
//    1.1.0 - 양방향 별칭(콤마) 입력
//    1.5.0 - Tab 이동 순서 변경: 표준 표현에서 Tab 누르면 오른쪽(영어)이 아니라
//            같은 칼럼의 유사 표현으로 내려감(한국어 표준→한국어 유사, 영어 표준→영어 유사).
//    1.4.0 - 가운데 양방향 화살표(⇄) 제거 — '한→영 번역' 오해 방지.
//            대신 칼럼 위에 '한국어/영어' 라벨 추가. 안내 문구도 정리(삭제 기능 설명 포함).
//            저장 형식·불러오기는 그대로(기존 용어집 호환).
//    1.3.0 - 용어 추가 시 새 카드에 커서 자동 포커스(바로 타이핑).
//            표준 표현 빈칸 허용 → 유사 표현을 빈 문자열로 치환(군더더기 "음," "어," 제거용).
//            가져오기/내보내기(CSV·TXT, 탭 구분 우선) + 리셋 추가.
//    1.2.0 - 직관적 카드 형태로 개편:
//            · 버튼명 "행 추가" → "용어 추가"
//            · 용어 카드마다 위=표준 표현(대표), 아래=유사 표현(콤마)
//            · 한↔영 양방향 유지 (저장은 "표준, 유사1, 유사2" 형태로 기존 호환)
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
    // v1.5.0: 포커스를 "카드 + 칸" 단위로 식별 (Tab 이동 제어용).
    enum Col { case koStd, koSim, enStd, enSim }
    struct FieldID: Hashable { let card: UUID; let col: Col }
    @FocusState private var focusedField: FieldID?
    // v1.3.0: 리셋 확인 알럿
    @State private var showResetConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // 헤더
            HStack {
                Text("용어집").font(.title3).bold()
                Spacer()
                Button {
                    let d = Draft()
                    drafts.append(d)
                    focusedField = FieldID(card: d.id, col: .koStd)   // 새 카드 한국어 표준 칸 포커스
                } label: {
                    Label("용어 추가", systemImage: "plus")
                }
            }

            Text("‘표준 표현’은 자막에 표시될 대표 표기입니다. ‘유사 표현’에 콤마로 변형들을 넣으면, 자막에 그 변형이 나올 때 표준 표현으로 자동 통일됩니다. 표준 표현을 비워두면 유사 표현이 자막에서 삭제됩니다(예: ‘음,’ ‘어,’ 같은 군더더기 제거). 한국어 자막엔 한국어 칸, 영어 자막엔 영어 칸이 적용됩니다.")
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
                // v1.3.0: 가져오기 / 내보내기 / 리셋 (CSV, TXT)
                Button {
                    importGlossary()
                } label: { Label("가져오기", systemImage: "square.and.arrow.down") }
                Button {
                    exportGlossary()
                } label: { Label("내보내기", systemImage: "square.and.arrow.up") }
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: { Label("리셋", systemImage: "trash") }
                Spacer()
                Button("저장") { save() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 640, height: 540)
        .onAppear { load() }
        .alert("용어집을 모두 비울까요?", isPresented: $showResetConfirm) {
            Button("취소", role: .cancel) {}
            Button("모두 삭제", role: .destructive) { drafts.removeAll() }
        } message: {
            Text("현재 편집 중인 모든 용어가 사라집니다. ‘저장’을 눌러야 실제로 반영됩니다.")
        }
    }

    // ── 용어 카드 1개 ──
    @ViewBuilder
    private func card(_ d: Binding<Draft>) -> some View {
        VStack(spacing: 6) {

            // v1.4.0: 칼럼 라벨 (한국어 / 영어). 화살표(번역 오해) 제거.
            HStack(spacing: 8) {
                Spacer().frame(width: 64)
                Text("한국어")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("영어")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer().frame(width: 24)
            }

            // 표준 표현 (대표) — 한국어 / 영어
            HStack(spacing: 8) {
                Text("표준 표현")
                    .font(.caption.weight(.semibold))
                    .frame(width: 64, alignment: .leading)
                TextField("예: 넷제로", text: d.koStd)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: FieldID(card: d.wrappedValue.id, col: .koStd))
                    // v1.5.0: Tab → 같은 칼럼 유사 표현으로 (오른쪽 영어가 아니라 아래로)
                    .onKeyPress(.tab) {
                        focusedField = FieldID(card: d.wrappedValue.id, col: .koSim)
                        return .handled
                    }
                TextField("예: Net Zero", text: d.enStd)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: FieldID(card: d.wrappedValue.id, col: .enStd))
                    .onKeyPress(.tab) {
                        focusedField = FieldID(card: d.wrappedValue.id, col: .enSim)
                        return .handled
                    }
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
                    .focused($focusedField, equals: FieldID(card: d.wrappedValue.id, col: .koSim))
                TextField("net zero, zero emission", text: d.enSim)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: FieldID(card: d.wrappedValue.id, col: .enSim))
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
    // v1.3.0: 첫 칸(표준)이 빈 "제거 항목"도 보존 — 콤마로 시작하면 표준이 빈 것.
    private func splitFirst(_ s: String) -> (String, String) {
        // 콤마로 시작 = 표준이 빈 제거 항목 (예: ", 음, 어")
        let leadingEmpty = s.trimmingCharacters(in: .whitespaces).hasPrefix(",")
        let parts = s.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if leadingEmpty {
            // 표준은 빈칸, 나머지 전부 유사 표현
            return ("", parts.joined(separator: ", "))
        }
        guard let first = parts.first else { return ("", "") }
        return (first, parts.dropFirst().joined(separator: ", "))
    }

    // 표준 + 유사 → "표준, 유사1, 유사2"
    // v1.3.0: 표준이 비어도 유사 표현이 있으면 "제거 항목"으로 저장(앞에 빈 칸 → ", 유사1, 유사2").
    //         번역문에서 그 유사 표현들이 빈 문자열로 치환되어 자막에서 사라짐(군더더기 제거용).
    private func join(std: String, similars: String) -> String {
        let s = std.trimmingCharacters(in: .whitespaces)
        let extra = similars.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if s.isEmpty {
            // 표준 빈칸: 유사 표현이 있으면 제거 항목으로(앞 빈 칸 표시), 없으면 완전 빈 항목
            guard !extra.isEmpty else { return "" }
            return ", " + extra.joined(separator: ", ")
        }
        return ([s] + extra).joined(separator: ", ")
    }

    // ── 내보내기 (v1.3.0): 탭 구분 한 줄=한 용어. 확장자에 따라 .csv/.txt 저장 ──
    //    형식: 한국어표준<TAB>한국어유사<TAB>영어표준<TAB>영어유사
    //    유사 표현 내부 콤마는 그대로 유지(탭으로 필드가 구분되어 충돌 없음).
    private func exportGlossary() {
        let header = "한국어표준\t한국어유사\t영어표준\t영어유사"
        let lines = drafts.map { d in
            [d.koStd, d.koSim, d.enStd, d.enSim]
                .map { $0.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }
                .joined(separator: "\t")
        }
        let content = ([header] + lines).joined(separator: "\n")

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.nameFieldStringValue = "glossary.csv"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // ── 가져오기 (v1.3.0): 탭 구분 우선, 없으면 콤마(CSV) 파싱 ──
    //    헤더 줄(한국어표준…)이 있으면 건너뜀. 기존 목록에 이어 붙임(덮어쓰지 않음).
    private func importGlossary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText, .text]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let raw = try? String(contentsOf: url, encoding: .utf8) else { return }

        var added: [Draft] = []
        for rawLine in raw.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            // 헤더 줄 건너뛰기
            if line.hasPrefix("한국어표준") { continue }
            // 탭이 있으면 탭, 없으면 콤마로 분리
            let sep: Character = line.contains("\t") ? "\t" : ","
            let cols = line.split(separator: sep, omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
            func col(_ i: Int) -> String { i < cols.count ? cols[i] : "" }
            let d = Draft(koStd: col(0), koSim: col(1), enStd: col(2), enSim: col(3))
            // 완전히 빈 줄은 무시
            if d.koStd.isEmpty && d.koSim.isEmpty && d.enStd.isEmpty && d.enSim.isEmpty { continue }
            added.append(d)
        }
        if !added.isEmpty { drafts.append(contentsOf: added) }
    }
}
