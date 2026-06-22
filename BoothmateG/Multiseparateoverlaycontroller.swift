//
//  MultiSeparateOverlayController.swift
//  BoothmateG
//
//  Version: 1.2.0
//  Changelog:
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
    //  - 확정 segments: 각 MultiSegment에서 (원문, 그 언어 번역)을 꺼내 SubtitleSegment로
    //  - 진행 중: currentSource / currentTargets[lang]
    private func syncLang(_ lang: String) {
        guard let ms = multiStore, let st = stores[lang] else { return }
        let g = glossary

        // 확정 세그먼트 재구성 (그 언어 번역이 있는 것만)
        var segs: [SubtitleSegment] = []
        for seg in ms.segments {
            let tgt = seg.targets[lang] ?? ""
            // 원문 또는 번역 중 하나라도 있으면 표시
            guard !seg.source.isEmpty || !tgt.isEmpty else { continue }
            var normTgt = g?.normalize(tgt) ?? tgt
            // v1.2.0: 메인 콘솔과 동일한 용어집 음역 교정. 입력=칸 언어면 스킵(원문 보존).
            if let pe = pairEngine, !isSourceLang(detectLang(seg.source), lang) {
                normTgt = pe.apply(source: seg.source, target: normTgt)
            }
            segs.append(SubtitleSegment(sourceText: seg.source, targetText: normTgt))
        }
        st.segments = segs

        // 진행 중 자막
        st.currentSource = ms.currentSource
        let liveTgt = ms.currentTargets[lang] ?? ""
        st.currentTarget = g?.normalize(liveTgt) ?? liveTgt
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
