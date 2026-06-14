//
//  TranslatedAudioPlayer.swift
//  BoothmateG
//
//  Version: 1.0.0
//  Changelog:
//    1.0.0 - 최초 작성. Gemini가 보내는 24kHz 16-bit mono PCM(번역 음성)을 재생.
//

import Foundation
import AVFoundation

final class TranslatedAudioPlayer {

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 24000
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    private var running = false

    func start() {
        guard !running else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        do {
            try engine.start()
            player.play()
            running = true
            print("[BMG] 번역 음성 재생 시작")
        } catch {
            print("[BMG] 음성 재생 시작 실패: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard running else { return }
        player.stop()
        engine.stop()
        engine.reset()
        running = false
        print("[BMG] 번역 음성 재생 중지")
    }

    // 24kHz 16-bit little-endian mono PCM 데이터를 재생 큐에 추가
    func enqueue(pcm16 data: Data) {
        guard running else { return }
        let frameCount = data.count / 2
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(frameCount)),
              let ch = buffer.floatChannelData?[0]
        else { return }

        buffer.frameLength = AVAudioFrameCount(frameCount)
        data.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            for i in 0..<frameCount {
                ch[i] = Float(samples[i]) / 32768.0   // Int16 → Float [-1,1]
            }
        }
        player.scheduleBuffer(buffer, completionHandler: nil)
    }
}
