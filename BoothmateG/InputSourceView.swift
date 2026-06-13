//
//  InputSourceView.swift
//  BoothmateG
//
//  Version: 1.0.0
//  Changelog:
//    1.0.0 - 최초 작성. 입력 소스(마이크) 목록 표시 + 선택 시 macOS 기본 입력 장치 변경
//

import SwiftUI
import CoreAudio

struct InputSourceView: View {
    @Environment(\.dismiss) private var dismiss

    // 선택된 장치를 상위로 전달 (이름 표시 갱신 + 필요 시 오디오 재시작)
    var onSelect: (AudioInputDevice) -> Void

    @State private var devices: [AudioInputDevice] = []
    @State private var currentID: AudioDeviceID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Text("입력 소스 선택").font(.title3).bold()
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }

            Text("선택하면 이 앱과 macOS의 기본 입력 장치가 함께 바뀝니다.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(devices) { dev in
                        Button {
                            AudioDeviceManager.setDefaultInputDevice(dev.id)
                            currentID = dev.id
                            onSelect(dev)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "mic")
                                    .foregroundStyle(.secondary)
                                Text(dev.name)
                                Spacer()
                                if dev.id == currentID {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(dev.id == currentID ? Color.blue.opacity(0.12) : Color.clear)
                            .cornerRadius(6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minHeight: 200)

            if devices.isEmpty {
                Text("사용 가능한 입력 장치를 찾지 못했습니다.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(20)
        .frame(width: 420, height: 360)
        .onAppear {
            devices = AudioDeviceManager.inputDevices()
            currentID = AudioDeviceManager.defaultInputDevice()
        }
    }
}
