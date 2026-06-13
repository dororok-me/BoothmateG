//
//  AppSettings.swift
//  BoothmateG
//
//  Version: 1.2.0
//  Changelog:
//    1.0.0 - 최초 작성. API 키, 언어쌍, 용어집 저장 관리
//    1.1.0 - 용어집을 CSV 호환 구조(GlossaryItem 배열)로 변경
//    1.2.0 - 지원 언어 전체(70여 개) 추가. 언어 코드를 BCP-47(ko, en, zh-Hans...)로 변경.
//            기본값 sourceLang="ko", targetLang="en"
//

import SwiftUI
import Combine

final class AppSettings: ObservableObject {

    @AppStorage("geminiApiKey") var geminiApiKey: String = ""

    // 언어 코드는 BCP-47 (Gemini Live Translate가 받는 형식)
    @AppStorage("sourceLang") var sourceLang: String = "ko"
    @AppStorage("targetLang") var targetLang: String = "en"

    @AppStorage("playTranslatedAudio") var playTranslatedAudio: Bool = false

    @AppStorage("glossaryJSON") var glossaryJSON: String = "[]"

    func loadGlossary() -> [GlossaryItem] {
        guard let data = glossaryJSON.data(using: .utf8),
              let items = try? JSONDecoder().decode([GlossaryItem].self, from: data)
        else { return [] }
        return items
    }

    func saveGlossary(_ items: [GlossaryItem]) {
        guard let data = try? JSONEncoder().encode(items),
              let str = String(data: data, encoding: .utf8)
        else { return }
        glossaryJSON = str
    }
}

// 드롭다운용 언어 항목
struct LangOption: Identifiable, Hashable {
    let id: String      // BCP-47 코드 (예: "ko", "en", "zh-Hans")
    let label: String
}

// Gemini Live Translate 지원 언어 전체 (70여 개)
// 자주 쓰는 언어를 위로, 나머지는 알파벳 순
let supportedLanguages: [LangOption] = [
    LangOption(id: "ko",      label: "Korean (한국어)"),
    LangOption(id: "en",      label: "English"),
    LangOption(id: "ja",      label: "Japanese (日本語)"),
    LangOption(id: "zh-Hans", label: "Chinese, Simplified (简体)"),
    LangOption(id: "zh-Hant", label: "Chinese, Traditional (繁體)"),

    LangOption(id: "af",  label: "Afrikaans"),
    LangOption(id: "ak",  label: "Akan"),
    LangOption(id: "sq",  label: "Albanian"),
    LangOption(id: "am",  label: "Amharic"),
    LangOption(id: "ar",  label: "Arabic"),
    LangOption(id: "hy",  label: "Armenian"),
    LangOption(id: "az",  label: "Azerbaijani"),
    LangOption(id: "eu",  label: "Basque"),
    LangOption(id: "be",  label: "Belarusian"),
    LangOption(id: "bn",  label: "Bengali"),
    LangOption(id: "bg",  label: "Bulgarian"),
    LangOption(id: "my",  label: "Burmese"),
    LangOption(id: "ca",  label: "Catalan"),
    LangOption(id: "hr",  label: "Croatian"),
    LangOption(id: "cs",  label: "Czech"),
    LangOption(id: "da",  label: "Danish"),
    LangOption(id: "nl",  label: "Dutch"),
    LangOption(id: "et",  label: "Estonian"),
    LangOption(id: "fil", label: "Filipino"),
    LangOption(id: "fi",  label: "Finnish"),
    LangOption(id: "fr",  label: "French"),
    LangOption(id: "gl",  label: "Galician"),
    LangOption(id: "ka",  label: "Georgian"),
    LangOption(id: "de",  label: "German"),
    LangOption(id: "el",  label: "Greek"),
    LangOption(id: "gu",  label: "Gujarati"),
    LangOption(id: "ha",  label: "Hausa"),
    LangOption(id: "he",  label: "Hebrew"),
    LangOption(id: "hi",  label: "Hindi"),
    LangOption(id: "hu",  label: "Hungarian"),
    LangOption(id: "is",  label: "Icelandic"),
    LangOption(id: "id",  label: "Indonesian"),
    LangOption(id: "it",  label: "Italian"),
    LangOption(id: "jv",  label: "Javanese"),
    LangOption(id: "kn",  label: "Kannada"),
    LangOption(id: "kk",  label: "Kazakh"),
    LangOption(id: "km",  label: "Khmer"),
    LangOption(id: "rw",  label: "Kinyarwanda"),
    LangOption(id: "lo",  label: "Lao"),
    LangOption(id: "lv",  label: "Latvian"),
    LangOption(id: "lt",  label: "Lithuanian"),
    LangOption(id: "mk",  label: "Macedonian"),
    LangOption(id: "ms",  label: "Malay"),
    LangOption(id: "ml",  label: "Malayalam"),
    LangOption(id: "mr",  label: "Marathi"),
    LangOption(id: "mn",  label: "Mongolian"),
    LangOption(id: "ne",  label: "Nepali"),
    LangOption(id: "no",  label: "Norwegian"),
    LangOption(id: "fa",  label: "Persian"),
    LangOption(id: "pl",  label: "Polish"),
    LangOption(id: "pt-BR", label: "Portuguese (Brazil)"),
    LangOption(id: "pt-PT", label: "Portuguese (Portugal)"),
    LangOption(id: "pa",  label: "Punjabi"),
    LangOption(id: "ro",  label: "Romanian"),
    LangOption(id: "ru",  label: "Russian"),
    LangOption(id: "sr",  label: "Serbian"),
    LangOption(id: "sd",  label: "Sindhi"),
    LangOption(id: "si",  label: "Sinhala"),
    LangOption(id: "sk",  label: "Slovak"),
    LangOption(id: "sl",  label: "Slovenian"),
    LangOption(id: "es",  label: "Spanish"),
    LangOption(id: "su",  label: "Sundanese"),
    LangOption(id: "sw",  label: "Swahili"),
    LangOption(id: "sv",  label: "Swedish"),
    LangOption(id: "ta",  label: "Tamil"),
    LangOption(id: "te",  label: "Telugu"),
    LangOption(id: "th",  label: "Thai"),
    LangOption(id: "tr",  label: "Turkish"),
    LangOption(id: "uk",  label: "Ukrainian"),
    LangOption(id: "ur",  label: "Urdu"),
    LangOption(id: "uz",  label: "Uzbek"),
    LangOption(id: "vi",  label: "Vietnamese"),
    LangOption(id: "zu",  label: "Zulu"),
]

// 용어집 한 항목
struct GlossaryItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var source: String
    var target: String
}
