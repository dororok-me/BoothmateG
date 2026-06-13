//
//  GlossaryView.swift
//  BoothmateG
//
//  Version: 1.1.0
//  Changelog:
//    1.0.0 - 최초 작성. 용어집 편집 시트
//    1.1.0 - 양방향 별칭 안내. 각 칸 콤마 구분, 첫 단어가 대표 표기
//

import SwiftUI

struct GlossaryView: View {
    @ObservedObject var settings: AppSettings

    // 시트가 닫힐 때 호출 → 글로서리 엔진에 즉시 반영
    var onApply: ([GlossaryItem]) -> Void

    @Environment(\.dismiss) private var dismiss

    // 편집용 작업 사본 (저장을 눌러야 실제 저장됨)
    @State private var items: [GlossaryItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // 헤더
            HStack {
                Text("용어집").font(.title3).bold()
                Spacer()
                Button {
                    items.append(GlossaryItem(source: "", target: ""))
                } label: {
                    Label("행 추가", systemImage: "plus")
                }
            }

            Text("각 칸에 콤마로 여러 표기를 넣을 수 있어요. 각 칸의 첫 단어가 화면에 표시될 대표 표기입니다.\n번역문에 어느 쪽 표기가 나오든 그 칸의 대표로 자동 통일됩니다 (양방향).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 입력 목록
            List {
                ForEach($items) { $item in
                    HStack(spacing: 8) {
                        TextField("한국어 표기들 (예: 넷제로, 제로배출, 무배출)", text: $item.source)
                            .textFieldStyle(.roundedBorder)

                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundStyle(.secondary)

                        TextField("영어 표기들 (예: Net Zero, net zero, zero emission)", text: $item.target)
                            .textFieldStyle(.roundedBorder)

                        Button(role: .destructive) {
                            items.removeAll { $0.id == item.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(minHeight: 240)

            if items.isEmpty {
                Text("아직 등록된 용어가 없습니다. ‘행 추가’를 눌러 시작하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }

            Divider()

            // 하단 버튼
            HStack {
                Button("취소") { dismiss() }
                Spacer()
                Button("저장") {
                    // 양쪽 다 비어있는 행은 버림
                    let cleaned = items.filter {
                        !$0.source.trimmingCharacters(in: .whitespaces).isEmpty
                        && !$0.target.trimmingCharacters(in: .whitespaces).isEmpty
                    }
                    settings.saveGlossary(cleaned)   // 디스크에 저장
                    onApply(cleaned)                 // 엔진에 즉시 반영
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 560, height: 460)
        .onAppear {
            items = settings.loadGlossary()
        }
    }
}
