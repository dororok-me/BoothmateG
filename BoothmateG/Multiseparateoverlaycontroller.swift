//
//  MultiSeparateOverlayController.swift
//  BoothmateG
//
//  Version: 1.5.0
//  Changelog:
//    1.5.0 - [한 줄기 흐름 + 마침표 확정] 오버레이가 메인 콘솔의 끊김을 무시하고, 확정+진행 번역을 모두
//            이어붙여 한 줄기로 만든 뒤 마침표로 끝난 문장만 확정 줄(위 고정), 미완성 꼬리는 진행 줄로 보낸다.
//            확정 줄이 재배치되던 현상("3대의"가 떴다 합쳐짐) 제거. 확정 문장 목록이 바뀔 때만 교체(깜빡임 방지).
//    1.4.0 - [오버레이만 문장 단위] syncLang에서 그 언어 번역들을 모두 이어붙여 문장부호(. ! ?) 기준으로
//            다시 끊어 오버레이 store에 넣는다. 메인 콘솔(MultiSubtitleStore)은 turn 단위 그대로 두어
//            원문 대조를 유지하고, 오버레이(청중 화면)만 문장 단위로 표출 → 둘을 진짜로 분리.
//            (splitIntoSentences 추가, 숫자 소수점은 끊지 않음)
//    1.3.0 - 언어별 개별 토글 지원: isVisible(lang:)/toggleLang/showLang/hideLang 추가.
//            상단 헤더에서 언어 박스마다 오버레이를 따로 켜고 끌 수 있게 함(기존 전체 toggle은 유지).
//            관찰(observeMultiStore)은 처음 한 창이 열릴 때 1회 설정, 모든 창이 닫히면 해제.
//    1.2.0 - 메인 콘솔과 동일한 용어집 음역 교정을 오버레이에도 적용(청중 자막 = 메인 콘솔 일치).
//            syncLang에서 pairEngine.apply 적용 + 입력=칸 언어면 스킵(detectLang/isSourceLang).
//            show/toggle에 pairEngine 인자 추가.
//    1.1.0 - 창 겹침 방지: 처음 뜨는 언어 창에 cascadeIndex 부여(계단식 배치).
//    1.0.0 - 다국어 오버레이를 "언어별 독립 창"으로 띄우는 컨트롤러.
//            청중 언어 수만큼 단일 오버레이(OverlayWindowController)를 생성하여,
//            각 창이 단일 언어 오버레이와 동일한 메뉴·기능·호버 동작을 갖는다.
//            · 각 언어 창의 위치·크기는 langKey로 독립 저장(OverlayWindowController v1.27.0).
//            · MultiSubtitleStore(원문+여러 언어)를 관찰해 언어별 SubtitleStore로 분배.
//            · 어느 언어 창을 X로 닫으면 그 언어만 사라짐(나머지 유지). 다시 토글하면 전체 표시.
//            · QR·청중 송출 등 다른 경로는 건드리지 않음.
//

import SwiftUI
import Combine

@MainActor
final class MultiSeparateOverlayController {

    // 언어별 (컨트롤러 + 그 언어 전용 store)
    private var controllers: [String: OverlayWindowController] = [:]
    private var stores: [String: SubtitleStore] = [:]
    private var cancellables: Set<AnyCancellable> = []
    private weak var multiStore: MultiSubtitleStore?
    private var glossary: GlossaryEngine?
    private var pairEngine: GlossaryPairEngine?   // v1.2.0: 메인 콘솔과 동일한 용어집 음역 교정용
    private weak var mainWindow: NSWindow?

    // 하나라도 떠 있으면 true (상단 토글 버튼 표시용)
    var isVisible: Bool { controllers.values.contains { $0.isVisible } }

    func toggle(store: MultiSubtitleStore, glossary: GlossaryEngine, pairEngine: GlossaryPairEngine, mainWindow: NSWindow?) {
        if isVisible { hide() }
        else { show(store: store, glossary: glossary, pairEngine: pairEngine, mainWindow: mainWindow) }
    }

    func show(store: MultiSubtitleStore, glossary: GlossaryEngine, pairEngine: GlossaryPairEngine, mainWindow: NSWindow?) {
        guard !store.langs.isEmpty else { return }
        self.multiStore = store
        self.glossary = glossary
        self.pairEngine = pairEngine   // v1.2.0
        self.mainWindow = mainWindow

        // 언어별 컨트롤러·store 준비 후 표시
        for (idx, lang) in store.langs.enumerated() {
            let isNew = (controllers[lang] == nil)
            let ctrl = controllers[lang] ?? OverlayWindowController(langKey: lang)
            if isNew { ctrl.cascadeIndex = idx }   // v1.28.0: 처음 만드는 창만 계단식 위치
            controllers[lang] = ctrl
            let st = stores[lang] ?? SubtitleStore()
            stores[lang] = st
            // 표시 직전 현재 multiStore 내용을 그 언어로 채움
            syncLang(lang)
            ctrl.show(store: st, glossary: glossary, mainWindow: mainWindow, displayPolish: nil)
        }

        // multiStore 변화를 관찰해 각 언어 store로 분배
        observeMultiStore(store)
    }

    func hide() {
        for ctrl in controllers.values { ctrl.hide() }
        cancellables.removeAll()
    }

    // ── v1.3.0: 언어별 개별 제어 ─────────────────────────────
    // 특정 언어 창이 떠 있는지
    func isVisible(lang: String) -> Bool {
        controllers[lang]?.isVisible ?? false
    }

    // 특정 언어 창만 켜고 끄기
    func toggleLang(_ lang: String, store: MultiSubtitleStore, glossary: GlossaryEngine, pairEngine: GlossaryPairEngine, mainWindow: NSWindow?) {
        if isVisible(lang: lang) { hideLang(lang) }
        else { showLang(lang, store: store, glossary: glossary, pairEngine: pairEngine, mainWindow: mainWindow) }
    }

    // 특정 언어 창만 표시
    func showLang(_ lang: String, store: MultiSubtitleStore, glossary: GlossaryEngine, pairEngine: GlossaryPairEngine, mainWindow: NSWindow?) {
        guard store.langs.contains(lang) else { return }
        self.multiStore = store
        self.glossary = glossary
        self.pairEngine = pairEngine
        self.mainWindow = mainWindow

        let isNew = (controllers[lang] == nil)
        let ctrl = controllers[lang] ?? OverlayWindowController(langKey: lang)
        if isNew { ctrl.cascadeIndex = store.langs.firstIndex(of: lang) ?? 0 }
        controllers[lang] = ctrl
        let st = stores[lang] ?? SubtitleStore()
        stores[lang] = st
        syncLang(lang)
        ctrl.show(store: st, glossary: glossary, mainWindow: mainWindow, displayPolish: nil)

        // 관찰이 아직 없으면(첫 창) 1회 설정
        if cancellables.isEmpty { observeMultiStore(store) }
    }

    // 특정 언어 창만 숨김. 모든 창이 닫히면 관찰 해제.
    func hideLang(_ lang: String) {
        controllers[lang]?.hide()
        if !isVisible { cancellables.removeAll() }
    }

    // ── multiStore 관찰 → 언어별 동기화 ──
    private func observeMultiStore(_ store: MultiSubtitleStore) {
        cancellables.removeAll()
        // 확정 세그먼트 변화
        store.$segments
            .sink { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async { self.syncAll() }
            }
            .store(in: &cancellables)
        // 진행 중 번역 변화
        store.$currentTargets
            .sink { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async { self.syncAll() }
            }
            .store(in: &cancellables)
        // 진행 중 원문 변화
        store.$currentSource
            .sink { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async { self.syncAll() }
            }
            .store(in: &cancellables)
    }

    private func syncAll() {
        guard let ms = multiStore else { return }
        for lang in ms.langs { syncLang(lang) }
    }

    // 특정 언어의 SubtitleStore를 multiStore 내용으로 채운다.
    //  v1.5.0: [한 줄기 흐름 + 마침표 확정] 메인 콘솔이 어디서 끊든 무시하고, 그 언어의 확정 번역 전체와
    //    진행 중 번역을 모두 이어붙여 하나의 줄기로 만든 뒤 — 마침표(. ! ?)로 끝난 문장들만 확정 줄(위에 고정),
    //    아직 마침표가 안 온 마지막 부분은 진행 줄(맨 아래, 실시간으로 흐르다 마침표 오면 위로 확정)로 보낸다.
    //    → 확정 줄은 절대 재배치되지 않고("3대의"가 떴다 합쳐지는 현상 제거), 메인 콘솔은 그대로(분리 유지).
    private func syncLang(_ lang: String) {
        guard let ms = multiStore, let st = stores[lang] else { return }
        let g = glossary

        // 1) 확정 번역 전체 + 진행 중 번역을 한 줄기로 이어붙임 (용어집 교정 적용)
        var joined = ""
        for seg in ms.segments {
            let tgt = seg.targets[lang] ?? ""
            guard !tgt.isEmpty else { continue }
            var normTgt = g?.normalize(tgt) ?? tgt
            // v1.2.0: 메인 콘솔과 동일한 용어집 음역 교정. 입력=칸 언어면 스킵(원문 보존).
            if let pe = pairEngine, !isSourceLang(detectLang(seg.source), lang) {
                normTgt = pe.apply(source: seg.source, target: normTgt)
            }
            let piece = normTgt.trimmingCharacters(in: .whitespaces)
            guard !piece.isEmpty else { continue }
            joined += (joined.isEmpty ? "" : " ") + piece
        }
        // 진행 중(아직 말하는 중) 번역도 같은 줄기에 이어붙임
        let rawLive = ms.currentTargets[lang] ?? ""
        let liveTgt = (g?.normalize(rawLive) ?? rawLive).trimmingCharacters(in: .whitespaces)
        if !liveTgt.isEmpty {
            joined += (joined.isEmpty ? "" : " ") + liveTgt
        }

        // 2) 마침표 기준으로 분리: 완성된 문장들 + 마지막 미완성 꼬리
        let (sentences, tail) = Self.splitSentencesAndTail(joined)

        // 3) 완성된 문장 = 확정 줄(위에 고정). 내용이 바뀔 때만 교체 → 진행 줄만 자랄 땐 재렌더/깜빡임 없음.
        if st.segments.map({ $0.targetText }) != sentences {
            st.segments = sentences.map { SubtitleSegment(sourceText: "", targetText: $0) }
        }
        // 4) 미완성 꼬리 = 진행 줄(맨 아래에서 실시간으로 흐르다, 마침표 오면 위로 확정)
        st.currentSource = ms.currentSource
        st.currentTarget = tail
    }

    // v1.5.0: 문장 종결부호(. ! ? 。！？)로 텍스트를 (완성된 문장들, 마지막 미완성 꼬리)로 나눈다.
    //   숫자 사이의 마침표(예: 9.5)는 소수점으로 보고 끊지 않는다.
    private static func splitSentencesAndTail(_ text: String) -> ([String], String) {
        let enders: Set<Character> = [".", "!", "?", "。", "！", "？"]
        let chars = Array(text)
        var sentences: [String] = []
        var cur = ""
        for i in 0..<chars.count {
            let ch = chars[i]
            cur.append(ch)
            if enders.contains(ch) {
                if ch == "." {
                    let prev = i > 0 ? chars[i - 1] : " "
                    let next = i + 1 < chars.count ? chars[i + 1] : " "
                    if prev.isNumber && next.isNumber { continue }   // 9.5 같은 소수점
                }
                let t = cur.trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { sentences.append(t) }
                cur = ""
            }
        }
        let tail = cur.trimmingCharacters(in: .whitespaces)   // 마침표로 안 끝난 미완성 부분
        return (sentences, tail)
    }

    // v1.2.0: 입력 텍스트 주 언어 추정(메인 콘솔 detectLang과 동일 규칙). 입력=칸이면 교정 스킵용.
    private func detectLang(_ text: String) -> String {
        for ch in text.unicodeScalars {
            if (0xAC00...0xD7A3).contains(ch.value) { return "ko" }   // 한글
            if (0x3040...0x30FF).contains(ch.value) { return "ja" }   // 히라가나/가타카나
        }
        for ch in text.unicodeScalars {
            if (0x4E00...0x9FFF).contains(ch.value) { return "zh" }   // CJK 한자(가나 없으면 중국어로 추정)
        }
        return "en"
    }

    // v1.2.0: 입력 언어와 표시 칸 언어가 같은 언어인지(중국어 간/번체는 같은 언어로 취급).
    private func isSourceLang(_ srcLang: String, _ lang: String) -> Bool {
        srcLang == lang || (srcLang == "zh" && lang.hasPrefix("zh"))
    }
}
