//
//  GlossaryPairView.swift
//  BoothmateG
//
//  Version: 2.4.1
//  Changelog:
//    2.4.1 - 유사어란 안내/placeholder에 영어 별칭(음차 오인식) 등록 가능 명시.
//    2.4.0 - 각 용어 카드에 유사어(sourceAliases) 입력란 추가. 음성인식이 고유명사를 잘못 들어도
//            (예: 천궁2호→전군2호) 별칭이 잡히면 용어 발동. 콤마 구분 입력 → 카드별 저장/로드.
//    2.3.0 - 블랙리스트 저장을 줄바꿈(\n) 구분 + 공백 보존으로 변경.
//    1.7.0 - 엔터(Return)로도 저장: 저장 버튼에 .defaultAction 단축키 지정.
//    1.6.0 - 저장=빈 유사표현 AI 자동생성 후 저장, 창은 유지(닫히지 않음).
//            닫기는 우상단 X + 하단 '닫기' 버튼으로만. 글자·버튼·창 크기 확대(접근성).
//    2.2.1 - 빌드 오류 수정: 필러 ForEach($fillers)의 f는 값이므로 f.id 사용(f.wrappedValue.id 제거).
//    2.2.0 - 통역 지침 탭 안내 강화(최우선 표준 지침, 민감 표현 처리 포함). 블랙리스트 안내를 '딱 그 단어만'으로 명확화.
//    2.1.0 - 블랙리스트를 박스형(카드)으로: 필러를 하나씩 등록/삭제. 저장 시 콤마로 합쳐
//            blacklistWords에 저장, 로드 시 박스로 분리. 안내에 '단어 일부 보호' 명시.
//    2.0.0 - 탭 3개 구조(용어집 / 통역 지침 / 블랙리스트). 통역 지침·블랙리스트는 TextEditor로
//            자유 입력 → systemInstruction에 함께 주입. 변경 감지·저장에 셋 다 포함.
//    1.9.0 - 저장 UX: 변경 없으면 저장 버튼 비활성(회색), 저장 시 '저장됨' 표시.
//            저장 안 된 변경이 있으면 안내. 변경 감지(스냅샷 비교).
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
        var aliasText: String = ""     // v2.4.0: 유사어/오인식 표기 (콤마 구분, 예: "전군2호, 천궁 이호")
    }

    // 블랙리스트(필러) 항목 모델 — 박스 하나 = 필러 하나
    private struct FillerItem: Identifiable {
        let id = UUID()
        var word: String = ""
    }

    @State private var drafts: [Draft] = []
    @State private var fillers: [FillerItem] = []
    @FocusState private var focusedField: UUID?
    @FocusState private var focusedFiller: UUID?
    @State private var showResetConfirm = false
    // 변경 감지: 마지막 저장 시점의 스냅샷(정규화 문자열). 현재와 다르면 "변경됨".
    @State private var savedSnapshot = ""
    @State private var showSavedToast = false
    // 탭 선택 (0=용어집, 1=통역 지침, 2=블랙리스트)
    @State private var selectedTab = 0

    // 현재 편집 내용을 비교용 문자열로 (용어집 + 통역 지침 + 블랙리스트)
    private var currentSnapshot: String {
        let pairs = drafts.map {
            "\($0.source.trimmingCharacters(in: .whitespaces))|\($0.canonical.trimmingCharacters(in: .whitespaces))|\($0.learnedText.trimmingCharacters(in: .whitespaces))|\($0.aliasText.trimmingCharacters(in: .whitespaces))"
        }.joined(separator: "\n")
        let fillerStr = fillers.map { $0.word }.filter { !$0.isEmpty }.joined(separator: "\n")
        return pairs + "\n##GUIDE##\n" + settings.interpretGuide + "\n##BLACK##\n" + fillerStr
    }
    // 저장할 변경이 있는가
    private var hasUnsavedChanges: Bool {
        currentSnapshot != savedSnapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // 헤더 (공통)
            HStack {
                Text("용어집 · 통역 설정").font(.title2).bold()
                Spacer()
                Toggle("이 방식 사용", isOn: $settings.useGlossaryPairMode)
                    .toggleStyle(.switch)
                    .help("켜면 용어집·통역 지침·블랙리스트가 통역에 적용됩니다.")
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

            // 탭 선택
            Picker("", selection: $selectedTab) {
                Text("용어집").tag(0)
                Text("통역 지침").tag(1)
                Text("블랙리스트").tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // 탭별 내용
            Group {
                if selectedTab == 0 {
                    glossaryTab
                } else if selectedTab == 1 {
                    guideTab
                } else {
                    blacklistTab
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            // 하단 버튼 (공통)
            HStack(spacing: 10) {
                if selectedTab == 0 {
                    Button {
                        importPairs()
                    } label: { Label("가져오기", systemImage: "square.and.arrow.down") }
                    Button {
                        exportPairs()
                    } label: { Label("내보내기", systemImage: "square.and.arrow.up") }
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: { Label("리셋", systemImage: "trash") }
                }

                Spacer()
                // 저장 완료 피드백
                if showSavedToast {
                    Label("저장됨", systemImage: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                } else if hasUnsavedChanges {
                    Text("저장 안 된 변경 있음")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                // 닫기(저장 안 함, 창만 닫기)
                Button("닫기") { dismiss() }
                    .controlSize(.large)
                // 저장 → 창은 유지. 변경 없으면 비활성(회색).
                Button("저장") { save() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!hasUnsavedChanges)
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

    // ── 탭 1: 용어집 ──
    @ViewBuilder
    private var glossaryTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("영어 ↔ 한국어 용어를 등록하면 통역 단계에서 그대로 반영됩니다(예: patient = 피험자). 양방향 적용.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button {
                    let d = Draft()
                    drafts.append(d)
                    focusedField = d.id
                } label: {
                    Label("용어 추가", systemImage: "plus").font(.body)
                }
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach($drafts) { $d in
                        card($d)
                    }
                }
                .padding(.vertical, 2)
            }

            if drafts.isEmpty {
                Text("등록된 용어가 없습니다. ‘용어 추가’를 눌러 시작하세요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
    }

    // ── 탭 2: 통역 지침 ──
    @ViewBuilder
    private var guideTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("이 행사의 통역 방향을 자유롭게 지시하세요. 가장 강력한 표준 지침으로, 톤·격식·호칭은 물론 민감하거나 부적절한 표현의 처리 방침까지 AI가 맥락에 맞춰 따릅니다.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("예시: 청중은 정부 고위 관계자이니 정중한 격식체로. ‘그녀/그들/당신’ 대신 ‘교수님’으로 호칭. 청중에 무슬림이 포함되니 종교 비하·신성모독 표현은 직접 옮기지 말고 중립적으로 완곡하게 처리. 노골적 성차별 표현은 순화. 가능한 간결하게.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $settings.interpretGuide)
                .font(.body)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(6)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
        }
    }

    // ── 탭 3: 블랙리스트 ──
    @ViewBuilder
    private var blacklistTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("등록한 표현을 자막에서 글자 그대로 제거합니다. 필러는 보통 쉼표와 공백을 달고 나오므로, ‘어, ’처럼 쉼표와 뒤 공백까지 포함해 등록하세요(예: ‘어, ’ ‘음, ’ ‘저기, ’). 그러면 ‘마음’ ‘먹음’의 ‘음’은 패턴이 달라 안전하게 보호됩니다. 톤·민감 표현은 ‘통역 지침’ 탭을 쓰세요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button {
                    let f = FillerItem()
                    fillers.append(f)
                    focusedFiller = f.id
                } label: {
                    Label("필러 추가", systemImage: "plus").font(.body)
                }
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach($fillers) { $f in
                        HStack(spacing: 8) {
                            TextField("필러 (예: 어,  ← 쉼표와 공백까지)", text: $f.word)
                                .textFieldStyle(.roundedBorder)
                                .font(.title3)
                                .focused($focusedFiller, equals: f.id)
                            Button(role: .destructive) {
                                fillers.removeAll { $0.id == f.id }
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
                }
                .padding(.vertical, 2)
            }

            if fillers.isEmpty {
                Text("등록된 필러가 없습니다. ‘필러 추가’를 눌러 시작하세요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
    }

    // ── 용어 카드 1개 (영어 ↔ 한국어 쌍만) ──
    @ViewBuilder
    private func card(_ d: Binding<Draft>) -> some View {
        VStack(spacing: 6) {
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
            // v2.4.0: 유사어(오인식 표기) — 음성인식이 고유명사를 잘못 들어도 잡아내기 위함.
            HStack(spacing: 8) {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .help("음성인식이 자주 틀리게 듣는 표기를 콤마로 등록하면, 그 표기가 들려도 이 용어로 인식합니다. 한국어 오인식(전군2호)과 영어 연사의 음차 오인식(Cheongunino 등)을 모두 등록할 수 있습니다.")
                TextField("유사어 (콤마 구분, 한국어·영어 모두 가능. 예: 전군2호, 천궁 이호, Cheongunino)", text: d.aliasText)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                Spacer().frame(width: 28)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
    }

    // ── 불러오기 ──
    private func load() {
        drafts = settings.loadGlossaryPairs().map {
            Draft(source: $0.source, canonical: $0.canonical,
                  learnedText: $0.learnedTargets.joined(separator: ", "),
                  aliasText: $0.sourceAliases.joined(separator: ", "))   // v2.4.0
        }
        // v2.3.0: 블랙리스트 — 줄바꿈(\n) 구분으로 로드, 공백 보존("어, " 패턴 유지).
        //         단, 줄바꿈이 전혀 없고 콤마만 있는 구버전 저장본은 콤마로 분리(호환).
        let raw = settings.blacklistWords
        let parts: [String]
        if raw.contains("\n") {
            parts = raw.components(separatedBy: "\n")
        } else if raw.contains(",") {
            // 구버전: 콤마 구분 → 분리 후 공백 정리(구버전은 어차피 공백 의미 없었음)
            parts = raw.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            parts = [raw]
        }
        fillers = parts
            .filter { !$0.isEmpty }
            .map { FillerItem(word: $0) }
        // 불러온 직후 = 저장된 상태 → 스냅샷 기준 설정(이때 저장 버튼 회색)
        savedSnapshot = currentSnapshot
    }

    // ── 저장(엔진 반영, 창은 닫지 않음) ──
    private func save() {
        let items: [GlossaryPair] = drafts.compactMap { d in
            let s = d.source.trimmingCharacters(in: .whitespaces)
            let c = d.canonical.trimmingCharacters(in: .whitespaces)
            guard !s.isEmpty, !c.isEmpty else { return nil }   // 둘 다 있어야 의미 있음
            let learned = d.learnedText.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            // v2.4.0: 유사어(콤마 구분) → sourceAliases
            let aliases = d.aliasText.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            return GlossaryPair(source: s, canonical: c, learnedTargets: learned, sourceAliases: aliases)
        }
        settings.saveGlossaryPairs(items)
        // v2.3.0: 블랙리스트 — 필러를 줄바꿈(\n)으로 구분 저장. 공백을 자르지 않아
        //         "어, "(쉼표+공백)처럼 패턴 전체를 그대로 보존. 빈 줄만 제거.
        settings.blacklistWords = fillers
            .map { $0.word }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        onApply(items)
        // 저장 완료 → 스냅샷 갱신(버튼 회색) + "저장됨" 잠깐 표시
        savedSnapshot = currentSnapshot
        withAnimation { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showSavedToast = false }
        }
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
