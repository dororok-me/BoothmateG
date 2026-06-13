//
//  AudioEngine.swift
//  BoothmateG
//
//  Version: 2.0.0
//  Changelog:
//    1.0.0 - 최초 작성. AVAudioConverter로 변환
//    2.0.0 - 다채널/Aggregate Device 대응:
//            첫 번째 채널만 추출 → 직접 다운샘플링하여 16kHz Int16 PCM 생성
//

import Foundation
import AVFoundation

// 마이크에서 소리를 받아 16kHz PCM 데이터로 바꿔주는 엔진.
// 다채널 입력도 첫 채널만 뽑아서 처리. (Aggregate Device 호환)
final class AudioEngine {

    var onAudioData: ((Data) -> Void)?

    private let engine = AVAudioEngine()
    private let targetSampleRate: Double = 16000
    private var sourceSampleRate: Double = 48000  // 실제 마이크 샘플레이트 (start 시점에 설정됨)

    func start() throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        // ─── 진단 로그 ───
        print("[BMG] === 오디오 입력 진단 ===")
        print("[BMG] 입력 노드 포맷: \(inputFormat)")
        print("[BMG] 샘플레이트: \(inputFormat.sampleRate) Hz")
        print("[BMG] 채널 수: \(inputFormat.channelCount)")
        if inputFormat.sampleRate == 0 || inputFormat.channelCount == 0 {
            print("[BMG] ⚠️ 입력 장치를 못 찾았거나 권한 없음!")
            throw NSError(domain: "AudioEngine", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "입력 장치 없음"])
        }
        print("[BMG] ========================")

        sourceSampleRate = inputFormat.sampleRate

        // 마이크에 탭을 걸어서 버퍼 받음 (입력 포맷 그대로)
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    // 들어온 Float32 버퍼 → 첫 채널 추출 → 16kHz Int16 PCM
    private func process(buffer: AVAudioPCMBuffer) {
        guard let floatData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        // 첫 번째 채널만 사용 (mono-force)
        let channel0 = floatData[0]

        // 다운샘플링 비율 (48000 → 16000 이면 3:1)
        let ratio = sourceSampleRate / targetSampleRate
        let outputCount = Int(Double(frameCount) / ratio)
        guard outputCount > 0 else { return }

        // 단순 데시메이션 (매 ratio번째 샘플만 취함)
        // + Float32 [-1.0 ~ 1.0] → Int16 [-32768 ~ 32767] 변환
        var int16Samples = [Int16]()
        int16Samples.reserveCapacity(outputCount)

        for i in 0..<outputCount {
            let srcIndex = Int(Double(i) * ratio)
            if srcIndex >= frameCount { break }
            let f = channel0[srcIndex]
            // 클램핑
            let clamped = max(-1.0, min(1.0, f))
            let int16 = Int16(clamped * 32767.0)
            int16Samples.append(int16)
        }

        let data = int16Samples.withUnsafeBufferPointer { ptr in
            Data(buffer: ptr)
        }

        // RMS 측정
        let count = int16Samples.count
        var sumSq: Double = 0
        for v in int16Samples {
            let d = Double(v)
            sumSq += d * d
        }
        let rms = sqrt(sumSq / Double(max(count, 1)))

        struct Counter { static var n = 0 }
        Counter.n += 1
        if Counter.n % 50 == 0 {
            print("[BMG] 마이크 RMS: \(Int(rms)) (0=무음, 500~3000=일반 발화)")
        }

        onAudioData?(data)
    }
}
