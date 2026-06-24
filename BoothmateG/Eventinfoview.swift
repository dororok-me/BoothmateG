//
//  EventInfoView.swift
//  BoothmateG
//
//  Version: 1.5.0
//  Changelog:
//    1.5.0 - 저장 시 창을 닫지 않고 중간 저장(영구 반영). 변경 감지로 저장 버튼 활성/비활성,
//            '저장됨' 표시 + '닫기' 버튼 분리. (용어집 창과 동일한 저장 UX로 통일)
//    1.4.0 - 참석자 입력칸 순서 변경: 이름을 위로, 직책을 아래로 (기존: 직책 위 / 이름 아래).
//    1.0.0 - 행사 정보(Event Information) 입력 UI 뷰
//    1.0.1 - 저장 버튼 dismiss 호출 수정(Button(action: dismiss) → { dismiss() }).
//    1.1.0 - 폰트 전체 확대(.caption→.title3 등).
//    1.2.0 - '글로서리 & 통역 세팅' 창과 폰트 통일: 제목 .title2, 섹션 라벨·입력칸 .body,
//            참석자 내부 소라벨 .callout. (GlossaryPairView와 동일 체계)
//    1.2.1 - 참석자 헤더 상단 고정 시도(스크롤 내부).
//    1.3.0 - 레이아웃 재구성: 행사 기본정보 + 참석자 헤더(+ 버튼)를 스크롤 밖 상단 고정.
//            참석자 입력칸 목록만 ScrollView. 저장·리셋 하단 고정.
//    1.3.1 - 참석자 적을 때도 + 버튼이 안 흔들리게: 스크롤 영역에 maxHeight:.infinity 부여 →
//            상단 고정영역이 항상 창 맨 위에 밀착(가운데 부유 방지). 첫 추가부터 + 위치 불변.
//

import SwiftUI

struct EventInfoView: View {
    @Binding var eventInfo: EventInfo
    var onSave: () -> Void = {}   // v1.5.0: 저장 시 영구 반영(ContentView가 settings.saveEventInfo 연결)
    @Environment(\.dismiss) var dismiss
    
    @State private var editingPosition = -1  // 수정 중인 참석자 인덱스
    // v1.5.0: 변경 감지(마지막 저장 시점 스냅샷) + 저장됨 토스트
    @State private var savedSnapshot = ""
    @State private var showSavedToast = false

    // 현재 행사정보를 비교용 문자열로(Codable JSON, 키 정렬로 안정적 비교)
    private var currentSnapshot: String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        guard let d = try? enc.encode(eventInfo), let s = String(data: d, encoding: .utf8) else { return "" }
        return s
    }
    private var hasUnsavedChanges: Bool { currentSnapshot != savedSnapshot }
    
    var body: some View {
        VStack(spacing: 0) {
            // 타이틀바 (고정)
            HStack {
                Text("행사 정보")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("완료") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor))
            .border(Color(nsColor: .separatorColor), width: 1)

            // 상단 고정 영역: 행사 기본정보 + 참석자 헤더(+ 버튼은 여기서 항상 고정)
            VStack(alignment: .leading, spacing: 16) {
                // 행사명
                VStack(alignment: .leading, spacing: 6) {
                    Text("행사명 | Event Name")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                    HStack(spacing: 8) {
                        TextField("한국어", text: $eventInfo.eventName.ko)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                        TextField("English", text: $eventInfo.eventName.en)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                    }
                }

                // 장소
                VStack(alignment: .leading, spacing: 6) {
                    Text("장소 | Venue")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                    HStack(spacing: 8) {
                        TextField("한국어", text: $eventInfo.venue.ko)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                        TextField("English", text: $eventInfo.venue.en)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                    }
                }

                // 일시
                VStack(alignment: .leading, spacing: 6) {
                    Text("일시 | Date/Time")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                    HStack(spacing: 8) {
                        TextField("한국어", text: $eventInfo.dateTime.ko)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                        TextField("English", text: $eventInfo.dateTime.en)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                    }
                }

                Divider()

                // 참석자 헤더(제목 + 추가 버튼) — 스크롤과 무관하게 항상 같은 자리 고정
                HStack {
                    Text("참석자 | Speakers")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fontWeight(.semibold)
                    Spacer()
                    Button(action: addSpeaker) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // 참석자 목록만 스크롤 (추가하면 이 영역만 길어지고 아래로 스크롤)
            ScrollView {
                VStack(spacing: 12) {
                    if eventInfo.speakers.isEmpty {
                        Text("위 + 버튼으로 참석자를 추가하세요")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    } else {
                        ForEach(eventInfo.speakers.indices, id: \.self) { i in
                            SpeakerRow(
                                speaker: $eventInfo.speakers[i],
                                index: i,
                                onDelete: { deleteSpeaker(at: i) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .frame(maxHeight: .infinity)

            Divider()

            // 하단 고정 버튼 (리셋 / 저장)
            HStack(spacing: 12) {
                Button(action: resetEventInfo) {
                    Label("리셋", systemImage: "arrow.counterclockwise")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Spacer()

                // 저장 완료 피드백 / 미저장 안내
                if showSavedToast {
                    Label("저장됨", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                } else if hasUnsavedChanges {
                    Text("저장 안 된 변경 있음")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // 닫기(저장 안 함, 창만 닫기)
                Button("닫기") { dismiss() }
                    .controlSize(.large)

                // 저장 → 창은 유지. 변경 없으면 비활성(회색).
                Button(action: saveEventInfo) {
                    Label("저장", systemImage: "checkmark.circle.fill")
                        .font(.body)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!hasUnsavedChanges)
            }
            .padding(16)
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear { savedSnapshot = currentSnapshot }   // v1.5.0: 열 때 기준 스냅샷(저장 버튼 회색)
    }

    // v1.5.0: 중간 저장 — 영구 반영 + 스냅샷 갱신(버튼 회색) + '저장됨' 잠깐 표시. 창은 닫지 않음.
    private func saveEventInfo() {
        onSave()
        savedSnapshot = currentSnapshot
        withAnimation { showSavedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showSavedToast = false }
        }
    }
    
    private func addSpeaker() {
        eventInfo.speakers.append(Speaker())
    }
    
    private func deleteSpeaker(at index: Int) {
        eventInfo.speakers.remove(at: index)
    }
    
    private func resetEventInfo() {
        let alert = NSAlert()
        alert.messageText = "행사 정보를 초기화하시겠습니까?"
        alert.informativeText = "모든 정보가 삭제됩니다."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "초기화")
        alert.addButton(withTitle: "취소")
        
        if alert.runModal() == .alertFirstButtonReturn {
            eventInfo.reset()
        }
    }
}

// MARK: - 참석자 입력 로우
struct SpeakerRow: View {
    @Binding var speaker: Speaker
    var index: Int
    var onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("[\(index + 1)]")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.body)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
            
            // 이름
            VStack(alignment: .leading, spacing: 4) {
                Text("이름 | Name")
                    .font(.callout)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    TextField("한국어", text: $speaker.name.ko)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                    TextField("English", text: $speaker.name.en)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
            }

            // 직책
            VStack(alignment: .leading, spacing: 4) {
                Text("직책 | Position")
                    .font(.callout)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    TextField("한국어", text: $speaker.position.ko)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                    TextField("English", text: $speaker.position.en)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
            }
            
            // 발표제목
            VStack(alignment: .leading, spacing: 4) {
                Text("발표제목 | Presentation Title")
                    .font(.callout)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    TextField("한국어", text: $speaker.presentationTitle.ko)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                    TextField("English", text: $speaker.presentationTitle.en)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    EventInfoView(eventInfo: .constant(EventInfo()))
}
