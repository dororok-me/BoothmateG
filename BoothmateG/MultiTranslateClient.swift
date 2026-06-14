//
//  MultiTranslateClient.swift
//  BoothmateG
//
//  Version: 1.0.0
//  Changelog:
//    1.0.0 - 최초 작성. 화자 1명(소스 1개) → 청중 여러 언어(타겟 N개) 동시 번역.
//            타겟 언어마다 GeminiLiveClient 세션을 하나씩 띄우고 같은 음성을 보냄.
//

import Foundation

final class MultiTranslateClient {

    var onSource: ((String) -> Void)?            // 화자 원문 (첫 세션에서만)
    var onTarget: ((String, String) -> Void)?    // (언어코드, 번역문)
    var onTurnComplete: (() -> Void)?
    var onConnected: (() -> Void)?
    var onError: ((String) -> Void)?

    private var clients: [GeminiLiveClient] = []
    private var notifiedConnected = false

    func connect(apiKey: String, sourceLang: String, targets: [String]) {
        teardown()
        notifiedConnected = false

        for (idx, lang) in targets.enumerated() {
            let c = GeminiLiveClient()
            let isFirst = (idx == 0)

            c.onConnected = { [weak self] in self?.notifyConnected() }
            c.onInputTranscript = { [weak self] t in if isFirst { self?.onSource?(t) } }
            c.onOutputTranscript = { [weak self] t in self?.onTarget?(lang, t) }
            c.onTurnComplete = { [weak self] in if isFirst { self?.onTurnComplete?() } }
            c.onError = { [weak self] m in self?.onError?(m) }
            c.onClosed = { }

            clients.append(c)
            c.connect(apiKey: apiKey, sourceLang: sourceLang, targetLang: lang)
        }
    }

    func sendAudio(_ data: Data) {
        for c in clients { c.sendAudio(data) }
    }

    func disconnect() {
        teardown()
    }

    private func teardown() {
        for c in clients { c.disconnect() }
        clients.removeAll()
    }

    private func notifyConnected() {
        if !notifiedConnected {
            notifiedConnected = true
            onConnected?()
        }
    }
}
