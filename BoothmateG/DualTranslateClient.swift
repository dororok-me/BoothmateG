//
//  DualTranslateClient.swift
//  BoothmateG
//
//  Version: 1.3.0
//  Changelog:
//    1.2.0 - connect(glossaryInstruction:) 추가 → 두 GeminiLiveClient에 용어집 systemInstruction 전달.
//    1.0.0 - 최초 작성. 두 세션 동시 운용 + 감지 언어로 출력 라우팅
//    1.1.0 - 번역 음성(onAudio) 전달 추가. 자막과 동일하게 "맞는 방향" 음성만 채택.
//    1.3.0 - connect(eventInfo:) 추가 → 두 GeminiLiveClient에 행사 정보 전달(GeminiLiveClient v1.7.0).
//

import Foundation

final class DualTranslateClient {

    var onInputTranscript: ((String) -> Void)?
    var onOutputTranscript: ((String) -> Void)?
    var onAudio: ((Data) -> Void)?              // 번역 음성 (맞는 방향만)
    var onTurnComplete: (() -> Void)?
    var onConnected: (() -> Void)?
    var onClosed: (() -> Void)?
    var onError: ((String) -> Void)?

    private let clientA = GeminiLiveClient()   // 타겟 = langA
    private let clientB = GeminiLiveClient()   // 타겟 = langB

    private var langA = "en"
    private var langB = "ko"
    private var lastSourceLang: String? = nil
    private var didNotifyConnected = false

    func connect(apiKey: String, langA: String, langB: String, glossaryInstruction: String = "", eventInfo: EventInfo = EventInfo()) {
        self.langA = langA
        self.langB = langB
        self.lastSourceLang = nil
        self.didNotifyConnected = false

        // ── A 세션 (타겟 = langA). 원문 자막은 A에서만 사용 ──
        clientA.onConnected = { [weak self] in self?.notifyConnected() }
        clientA.onInputLanguage = { [weak self] code in self?.lastSourceLang = code }
        clientA.onInputTranscript = { [weak self] t in self?.onInputTranscript?(t) }
        clientA.onOutputTranscript = { [weak self] t in
            guard let self else { return }
            if self.accept(target: self.langA) { self.onOutputTranscript?(t) }
        }
        clientA.onAudio = { [weak self] d in
            guard let self else { return }
            if self.accept(target: self.langA) { self.onAudio?(d) }
        }
        clientA.onTurnComplete = { [weak self] in self?.onTurnComplete?() }
        clientA.onError = { [weak self] m in self?.onError?(m) }
        clientA.onClosed = { [weak self] in self?.onClosed?() }

        // ── B 세션 (타겟 = langB). 출력/음성만 사용 ──
        clientB.onConnected = { [weak self] in self?.notifyConnected() }
        clientB.onInputLanguage = { [weak self] code in self?.lastSourceLang = code }
        clientB.onInputTranscript = { _ in }
        clientB.onOutputTranscript = { [weak self] t in
            guard let self else { return }
            if self.accept(target: self.langB) { self.onOutputTranscript?(t) }
        }
        clientB.onAudio = { [weak self] d in
            guard let self else { return }
            if self.accept(target: self.langB) { self.onAudio?(d) }
        }
        clientB.onTurnComplete = { }
        clientB.onError = { [weak self] m in self?.onError?(m) }
        clientB.onClosed = { }

        clientA.connect(apiKey: apiKey, sourceLang: langB, targetLang: langA, glossaryInstruction: glossaryInstruction, eventInfo: eventInfo)
        clientB.connect(apiKey: apiKey, sourceLang: langA, targetLang: langB, glossaryInstruction: glossaryInstruction, eventInfo: eventInfo)
    }

    func sendAudio(_ data: Data) {
        clientA.sendAudio(data)
        clientB.sendAudio(data)
    }

    func disconnect() {
        clientA.disconnect()
        clientB.disconnect()
    }

    // 감지된 소스 언어의 "반대" 타겟만 채택
    private func accept(target: String) -> Bool {
        guard let src = lastSourceLang else {
            return prefix(target) == prefix(langA)
        }
        let s = prefix(src), a = prefix(langA), b = prefix(langB)
        if s == b { return prefix(target) == a }
        if s == a { return prefix(target) == b }
        return prefix(target) == a
    }

    private func prefix(_ code: String) -> String {
        String(code.prefix { $0 != "-" }).lowercased()
    }

    private func notifyConnected() {
        if !didNotifyConnected {
            didNotifyConnected = true
            onConnected?()
        }
    }
}
