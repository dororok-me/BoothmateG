//
//  AudioEngine.swift
//  BoothmateG
//
//  Version: 2.5.0
//  Changelog:
//    2.5.0 - [TSan 데이터 레이스 정리] lastRMS를 오디오 스레드(process가 쓰기)와
//            메인 타이머(무음 감지가 읽기)가 동시에 접근하던 충돌을 NSLock으로 보호.
//            저장 프로퍼티 _lastRMS + rmsLock으로 분리하고 lastRMS는 잠금 처리된
//            computed 프로퍼티로 노출. process 안의 lastRMS = rms 호출부는 그대로(잠긴 setter 사용).
//    2.4.0 - [CPU 폭주 해결] 마이크 RMS를 ContentView @State로 갱신(초당 십수 회 전체 뷰 재렌더)하던
//            구조 제거. 엔진이 lastRMS로 직접 보관하고, 무음 감지 타이머가 그 값을 읽는다.
//            화면에 안 쓰이는 값이 화면을 계속 다시 그리게 하던 문제 해소.
//    2.3.0 - 입력 장치 변경(예: Sennheiser→RØDE) 후 정지 시 다운(-10877/no object) 해결:
//            엔진 인스턴스를 매 start()마다 새로 생성(let engine → var engine). 이전 장치의
//            stale 노드를 들고 있지 않게 → 정지 정리에서 사라진 장치 접근 차단.
//            stop()도 engine.isRunning일 때만 탭 제거·정지하도록 가드 추가.
//    1.0.0 - 최초 작성. AVAudioConverter로 변환
//    2.0.0 - 다채널/Aggregate Device 대응:
//            첫 번째 채널만 추출 → 직접 다운샘플링하여 16kHz Int16 PCM 생성
//    2.1.0 - RMS 콜백 추가 (음성 자동 중지용): onAudioRMS
//    2.2.0 - 정지 다운(-10877/overload) 완화: running 플래그 추가. stop()에서 먼저 내려
//            진행 중 process 콜백이 끊긴 소켓 전송·정리작업을 건드리지 않게(race 차단).
//            start 끝에서 running=true, process 맨 앞 guard running.
//

import Foundation
import AVFoundation

// 마이크에서 소리를 받아 16kHz PCM 데이터로 바꿔주는 엔진.
// 다채널 입력도 첫 채널만 뽑아서 처리. (Aggregate Device 호환)
final class AudioEngine {

    var onAudioData: ((Data) -> Void)?
    var onAudioRMS: ((Double) -> Void)?  // v2.1.0 추가: RMS 값 콜백
    // v2.4.0: 무음 감지용 최신 RMS. @State 재렌더를 유발하지 않도록 엔진이 직접 보관(ContentView가 읽음).
    // v2.5.0: 오디오 스레드(쓰기)·메인 타이머(읽기) 동시 접근 충돌 방지 → 저장값 분리 + 잠금 처리된 접근.
    private var _lastRMS: Double = 0
    private let rmsLock = NSLock()
    private(set) var lastRMS: Double {
        get { rmsLock.lock(); defer { rmsLock.unlock() }; return _lastRMS }
        set { rmsLock.lock(); defer { rmsLock.unlock() }; _lastRMS = newValue }
    }

    // v2.3.0: 입력 장치 변경 대응 위해 let → var (start마다 새 인스턴스로 교체)
    private var engine = AVAudioEngine()
    private let targetSampleRate: Double = 16000
    private var sourceSampleRate: Double = 48000  // 실제 마이크 샘플레이트 (start 시점에 설정됨)
    // v2.2.0: 정지 후 진행 중 오디오 콜백 무해화용. stop()에서 먼저 내리고, process가 확인.
    private var running = false

    func start() throws {
        // v2.3.0: 매 시작마다 새 엔진 인스턴스. 입력 장치가 바뀌어도(예: Sennheiser→RØDE)
        //   이전 장치의 stale 노드를 들고 있지 않아, 정지 시 -10877/no object 다운을 막는다.
        engine = AVAudioEngine()
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
        running = true   // v2.2.0: 엔진 가동 후 콜백 활성화
    }

    func stop() {
        running = false   // v2.2.0: 콜백 먼저 차단 → 정지 중 process가 끊긴 소켓/정리작업을 건드리지 않게
        // v2.3.0: 엔진이 실제 돌고 있을 때만 탭 제거·정지(이미 멈췄거나 장치가 사라진 상태에서
        //   stale 노드를 건드리다 다운되는 것 방지). 다음 start()가 새 엔진을 만든다.
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
    }

    // 들어온 Float32 버퍼 → 첫 채널 추출 → 16kHz Int16 PCM
    private func process(buffer: AVAudioPCMBuffer) {
        guard running else { return }   // v2.2.0: 정지 후 진행 중 콜백 즉시 종료(race·끊긴 소켓 전송 방지)
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

        // v2.1.0 추가: RMS 값을 ContentView로 전달
        lastRMS = rms        // v2.4.0: 무음 감지 타이머가 읽음(@State 재렌더 회피) / v2.5.0: 잠긴 setter로 안전 기록
        onAudioRMS?(rms)

        struct Counter { static var n = 0 }
        Counter.n += 1
        if Counter.n % 50 == 0 {
            print("[BMG] 마이크 RMS: \(Int(rms)) (0=무음, 500~3000=일반 발화)")
        }

        onAudioData?(data)
    }
}
