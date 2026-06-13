//
//  AppSettings.swift
//  BoothmateG
//
//  Version: 1.1.0
//  Changelog:
//    1.0.0 - 최초 작성. API 키, 언어쌍, 용어집 저장 관리
//    1.1.0 - 용어집을 CSV 호환 구조(GlossaryItem 배열)로 변경
//

import SwiftUI
import Combine

// 앱 전역 설정을 담는 클래스.
// @AppStorage로 저장하면 앱을 껐다 켜도 값이 유지됨.
final class AppSettings: ObservableObject {

    // Gemini API 키 (BYOK - 사용자가 직접 입력)
    @AppStorage("geminiApiKey") var geminiApiKey: String = ""

    // 원본 언어 (말하는 사람의 언어)
    @AppStorage("sourceLang") var sourceLang: String = "ko-KR"

    // 번역 목표 언어
    @AppStorage("targetLang") var targetLang: String = "en-US"

    // 번역된 음성을 재생할지 여부 (기본 끔 - 자막만)
    @AppStorage("playTranslatedAudio") var playTranslatedAudio: Bool = false

    // 용어집을 JSON 문자열로 저장 (CSV 가져오기/내보내기와 호환되는 구조)
    @AppStorage("glossaryJSON") var glossaryJSON: String = "[]"

    // 저장된 JSON을 GlossaryItem 배열로 읽어오기
    func loadGlossary() -> [GlossaryItem] {
        guard let data = glossaryJSON.data(using: .utf8),
              let items = try? JSONDecoder().decode([GlossaryItem].self, from: data)
        else { return [] }
        return items
    }

    // GlossaryItem 배열을 JSON 문자열로 저장하기
    func saveGlossary(_ items: [GlossaryItem]) {
        guard let data = try? JSONEncoder().encode(items),
              let str = String(data: data, encoding: .utf8)
        else { return }
        glossaryJSON = str
    }
}

// 앱에서 지원하는 언어 목록 (드롭다운용)
struct LangOption: Identifiable, Hashable {
    let id: String      // 예: "ko-KR"
    let label: String   // 예: "한국어"
}

let supportedLanguages: [LangOption] = [
    LangOption(id: "ko-KR", label: "한국어"),
    LangOption(id: "en-US", label: "English"),
    LangOption(id: "ja-JP", label: "日本語"),
    LangOption(id: "zh-CN", label: "中文")
]

// 용어집 한 항목 = 원문 용어 하나 + 지정 번역 하나
struct GlossaryItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var source: String   // 원문 용어 (예: "탄소중립")
    var target: String   // 지정 번역 (예: "carbon neutrality")
}
