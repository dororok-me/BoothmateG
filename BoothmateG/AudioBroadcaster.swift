//
//  AudioBroadcaster.swift
//  BoothmateG
//
//  Version: 1.1.0 - reset 추가
//  다국어 청중 음성 송출(2단계, v1 = 무압축 WAV).
//  Gemini가 언어별로 주는 PCM16(24kHz·모노)을 받아 → 무음 구간마다 한 문장 클립으로 잘라
//  → FirebaseRelay를 통해 Storage에 올리고 → RTDB로 "새 클립" 알림을 push 한다.
//  · 선택 언어 1개만 재생하던 기존 onAudio에서, 모든 언어 PCM을 여기로도 흘려보낸다.
//  · 스레드 안전: 모든 버퍼 작업은 전용 직렬 큐에서 수행.
//  · 추후: WAV → AAC 압축으로 대역폭 절감 예정.
//

import Foundation

final class AudioBroadcaster {
    private let q = DispatchQueue(label: "ai.dororok.BoothmateG.audiobroadcaster")

    private var active = false
    private var sessionId = ""
    private var buffers: [String: Data] = [:]     // 언어 → 누적 PCM
    private var lastAppend: [String: Date] = [:]
    private var seq: [String: Int] = [:]
    private var timer: DispatchSourceTimer?

    // Gemini Live 출력 기준
    private let sampleRate = 24000                 // 24kHz
    private let gapFlush: TimeInterval = 0.6       // 이만큼 무음이면 한 클립으로 마감
    private let maxDur: TimeInterval = 10.0        // 너무 길면 강제 분할
    private var maxBytes: Int { Int(Double(sampleRate * 2) * maxDur) }   // 16bit=2byte
    private var minBytes: Int { Int(Double(sampleRate * 2) * 0.1) }      // 0.1초 미만 조각은 버림

    func start(sessionId: String) {
        q.async {
            self.active = true
            self.sessionId = sessionId
            self.buffers.removeAll()
            self.lastAppend.removeAll()
            self.seq.removeAll()
            self.startTimer()
        }
    }

    func stop() {
        q.async {
            guard self.active else { return }
            self.active = false
            self.timer?.cancel()
            self.timer = nil
            for lang in Array(self.buffers.keys) { self.flush(lang) }   // 남은 것 마저 전송
            self.buffers.removeAll()
            self.lastAppend.removeAll()
        }
    }
    
    /// 진행 중 버퍼만 폐기(플러시 안 함). seq는 유지 → 기존 청취자 재생 안 끊김.
        func reset() {
            q.async {
                self.buffers.removeAll()
                self.lastAppend.removeAll()
            }
        }
    
    // 모든 언어의 PCM이 여기로 들어온다 (송출 중이 아니면 무시)
    func append(lang: String, pcm16 d: Data) {
        q.async {
            guard self.active, !lang.isEmpty, !d.isEmpty else { return }
            self.buffers[lang, default: Data()].append(d)
            self.lastAppend[lang] = Date()
            if let b = self.buffers[lang], b.count >= self.maxBytes {
                self.flush(lang)
            }
        }
    }

    // MARK: - 내부

    private func startTimer() {
        let t = DispatchSource.makeTimerSource(queue: q)
        t.schedule(deadline: .now() + 0.2, repeating: 0.2)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func tick() {
        let now = Date()
        for (lang, b) in buffers where !b.isEmpty {
            if let last = lastAppend[lang], now.timeIntervalSince(last) >= gapFlush {
                flush(lang)
            }
        }
    }

    // 버퍼를 WAV 클립으로 만들어 업로드 (직렬 큐에서만 호출)
    private func flush(_ lang: String) {
        guard let pcm = buffers[lang], pcm.count >= minBytes else {
            buffers[lang] = Data()          // 너무 짧으면 폐기
            return
        }
        buffers[lang] = Data()
        let n = (seq[lang] ?? 0) + 1
        seq[lang] = n
        let wav = Self.makeWAV(pcm: pcm, sampleRate: sampleRate)
        FirebaseRelay.shared.uploadAudioClip(sessionId: sessionId, lang: lang, seq: n, wav: wav)
    }

    // PCM16(LE) → WAV (헤더 44바이트 + 데이터)
    static func makeWAV(pcm: Data, sampleRate: Int) -> Data {
        let channels: UInt16 = 1
        let bits: UInt16 = 16
        let sr = UInt32(sampleRate)
        let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bits / 8)
        let blockAlign = UInt16(channels * (bits / 8))
        let dataLen = UInt32(pcm.count)

        var h = Data()
        func a(_ s: String) { h.append(contentsOf: Array(s.utf8)) }
        func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { h.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { h.append(contentsOf: $0) } }

        a("RIFF"); u32(36 + dataLen); a("WAVE")
        a("fmt "); u32(16); u16(1); u16(channels)
        u32(sr); u32(byteRate); u16(blockAlign); u16(bits)
        a("data"); u32(dataLen)
        h.append(pcm)
        return h
    }
}
