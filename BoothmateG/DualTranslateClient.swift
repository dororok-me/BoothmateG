//
//  DualTranslateClient.swift
//  BoothmateG
//
//  Version: 1.0.0
//  Changelog:
//    1.0.0 - 최초 작성. GeminiLiveClient 2개를 동시 운용하는 양방향 코디네이터.
//            같은 오디오를 두 세션(타겟=langA, 타겟=langB)에 보내고,
//            감지된 입력 언어(languageCode)의 "반대" 타겟 출력만 화면에 채택.
//            → 한국어 말하면 영어로, 영어 말하면 한국어로 자동 표시.
//

import Foundation

final class DualTranslateClient {

    // ContentView가 쓰는 통합 콜백 (GeminiLiveClient와 동일한 이름)
    var onInputTranscript: ((String) -> Void)?
    var onOutputTranscript: ((String) -> Void)?
    var onTurnComplete: (() -> Void)?
    var onConnected: (() -> Void)?
    var onClosed: (() -> Void)?
    var onError: ((String) -> Void)?

    private let clientA = GeminiLiveClient()   // 타겟 = langA
    private let clientB = GeminiLiveClient()   // 타겟 = langB

    private var langA = "en-US"
    private var langB = "ko-KR"
    private var lastSourceLang: String? = nil  // API가 알려준 감지 입력 언어
    private var didNotifyConnected = false

    func connect(apiKey: String, langA: String, langB: String) {
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
        clientA.onTurnComplete = { [weak self] in self?.onTurnComplete?() }
        clientA.onError = { [weak self] m in self?.onError?(m) }
        clientA.onClosed = { [weak self] in self?.onClosed?() }

        // ── B 세션 (타겟 = langB). 출력만 사용 (원문은 A에서 받아 중복 방지) ──
        clientB.onConnected = { [weak self] in self?.notifyConnected() }
        clientB.onInputLanguage = { [weak self] code in self?.lastSourceLang = code }
        clientB.onInputTranscript = { _ in }
        clientB.onOutputTranscript = { [weak self] t in
            guard let self else { return }
            if self.accept(target: self.langB) { self.onOutputTranscript?(t) }
        }
        clientB.onTurnComplete = { }      // 종료 신호는 A 기준
        clientB.onError = { [weak self] m in self?.onError?(m) }
        clientB.onClosed = { }

        // sourceLang은 형식상 값일 뿐 — 실제 소스 언어는 Gemini가 자동 감지
        clientA.connect(apiKey: apiKey, sourceLang: langB, targetLang: langA)
        clientB.connect(apiKey: apiKey, sourceLang: langA, targetLang: langB)
    }

    func sendAudio(_ data: Data) {
        clientA.sendAudio(data)
        clientB.sendAudio(data)
    }

    func disconnect() {
        clientA.disconnect()
        clientB.disconnect()
    }

    // 출력 채택 규칙: 감지된 소스 언어의 "반대" 타겟만 채택
    private func accept(target: String) -> Bool {
        guard let src = lastSourceLang else {
            return prefix(target) == prefix(langA)   // 아직 모르면 기본 방향(A)
        }
        let s = prefix(src), a = prefix(langA), b = prefix(langB)
        if s == b { return prefix(target) == a }     // 소스가 B언어 → A로 번역(A 채택)
        if s == a { return prefix(target) == b }     // 소스가 A언어 → B로 번역(B 채택)
        return prefix(target) == a                   // 그 외 언어 → 기본 A
    }

    // "en-US" → "en", "ko-KR" → "ko"
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
