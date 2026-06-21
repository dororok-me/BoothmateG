//
//  TranslatedAudioPlayer.swift
//  BoothmateG
//
//  Version: 1.2.0
//  Changelog:
//    1.0.0 - 최초 작성. Gemini가 보내는 24kHz 16-bit mono PCM(번역 음성)을 재생.
//    1.1.0 - 시작 직후 음성 재생 시 크래시(throwing -10877 / Int16 정렬) 수정.
//            · enqueue: Data를 정렬 안전하게 [Int16]로 복사 후 변환(bindMemory 직접 재해석 제거).
//            · 홀수 바이트·빈 데이터 방어. engine.isRunning 확인 후에만 스케줄.
//            · start: mainMixerNode 출력 포맷을 명시적으로 준비(엔진 그래프 안정화).
//    1.2.0 - 콘솔 번역 음성 재생 임시 차단(disabled=true). 마이크 입력 엔진과 재생 엔진이
//            동시에 도는 충돌(-10877)로 시작 직후 다운되어, 안정화를 위해 재생 진입을 막음.
//            되살릴 때: 아래 `disabled`를 false로. (근본 해결은 두 엔진 통합 후)
//            enqueue/stop은 그대로 — start가 막히면 running=false라 자동으로 무해.
//

import Foundation
import AVFoundation

final class TranslatedAudioPlayer {

    // v1.2.0: 콘솔 음성 재생 임시 차단 스위치. true면 start()가 진입하지 않음(다운 방지).
    //         되살리려면 false로 변경. (두 AVAudioEngine 동시 구동 충돌 회피용)
    private let disabled = true

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 24000
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    private var running = false

    func start() {
        if disabled {
            print("[BMG] 콘솔 번역 음성 재생은 현재 비활성화됨(v1.2.0). 자막·청중 송출은 정상.")
            return
        }
        guard !running else { return }
        engine.attach(player)
        // v1.1.0: 믹서→출력 그래프를 먼저 만져 하드웨어 출력 포맷을 확정(48k 입력과 24k 재생 혼선 방지)
        let mixer = engine.mainMixerNode
        _ = engine.outputNode.inputFormat(forBus: 0)
        engine.connect(player, to: mixer, format: format)
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
    // v1.1.0: 메모리 정렬 안전 처리 — Data를 [Int16]로 복사 후 변환(직접 bindMemory 재해석 제거).
    func enqueue(pcm16 data: Data) {
        guard running, engine.isRunning else { return }

        // 홀수 바이트 방어: 2바이트 단위로만 사용
        let usableCount = data.count - (data.count % 2)
        let frameCount = usableCount / 2
        guard frameCount > 0 else { return }

        // 정렬 안전: 바이트를 직접 Int16(little-endian)로 조합 → 정렬·홀수 문제 원천 차단
        var samples = [Int16](repeating: 0, count: frameCount)
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let base = raw.baseAddress!
            for i in 0..<frameCount {
                let lo = UInt16(base.load(fromByteOffset: i * 2,     as: UInt8.self))
                let hi = UInt16(base.load(fromByteOffset: i * 2 + 1, as: UInt8.self))
                samples[i] = Int16(bitPattern: lo | (hi << 8))
            }
        }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(frameCount)),
              let ch = buffer.floatChannelData?[0]
        else { return }

        buffer.frameLength = AVAudioFrameCount(frameCount)
        for i in 0..<frameCount {
            ch[i] = Float(samples[i]) / 32768.0   // Int16 → Float [-1,1]
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
    }
}
