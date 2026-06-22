//
//  ReflectionLog.swift
//  BoothmateG
//
//  Version: 1.0.1
//  Changelog:
//    1.0.1 - Combine import 추가(@Published 사용에 필요한 모듈 누락 빌드 오류 수정).
//    1.0.0 - 메인 콘솔 우측 "반영 로그" 패널용 데이터 모델·저장소.
//            문장이 확정될 때마다 어떤 용어집·생략어·행사·연사 정보가 반영되었는지 기록한다.
//            · glossary(파랑): 새 방식 용어집 canonical/유사어가 번역문에 나타나면 추정 표시
//            · omission(주황): applyBlacklist가 실제로 제거한 패턴
//            · event(초록): 행사명·장소 등이 번역문에 나타나면 추정 표시
//            · speaker(보라): 연사 이름·직책이 번역문에 나타나면 추정 표시
//            최근 100개 유지.
//

import SwiftUI
import Combine

enum ReflectionKind: String {
    case glossary    // 용어집(새 방식) 반영 추정 — 파랑
    case omission    // 생략어(필러) 제거 — 주황
    case event       // 행사 정보 반영 추정 — 초록
    case speaker     // 연사 정보 반영 추정 — 보라

    var color: Color {
        switch self {
        case .glossary: return Color.blue
        case .omission: return Color.orange
        case .event:    return Color.green
        case .speaker:  return Color.purple
        }
    }

    var label: String {
        switch self {
        case .glossary: return "용어집"
        case .omission: return "생략"
        case .event:    return "행사"
        case .speaker:  return "연사"
        }
    }
}

struct ReflectionEntry: Identifiable {
    let id = UUID()
    let kind: ReflectionKind
    let text: String          // 표시 내용 (예: "천궁2호 → Sky Pierce II", "어, 생략")
    let at: Date = Date()
}

@MainActor
final class ReflectionLogStore: ObservableObject {
    @Published var entries: [ReflectionEntry] = []
    private let maxEntries = 100

    func add(_ kind: ReflectionKind, _ text: String) {
        entries.append(ReflectionEntry(kind: kind, text: text))
        trim()
    }

    func addMany(_ found: [(ReflectionKind, String)]) {
        for f in found { entries.append(ReflectionEntry(kind: f.0, text: f.1)) }
        trim()
    }

    func clear() { entries.removeAll() }

    private func trim() {
        if entries.count > maxEntries { entries.removeFirst(entries.count - maxEntries) }
    }
}
