//
//  AppSettings.swift
//  BoothmateG
//
//  Version: 1.6.0
//  Changelog:
//    1.2.0 - 지원 언어 전체 + BCP-47 코드
//    1.3.0 - 청중 언어(다국어 모드 타겟들) 저장 추가
//    1.4.0 - 다국어 모드에서 음성 재생할 언어 1개 저장(multiAudioLang) 추가
//    1.5.0 - 다국어 모드 화자 언어(multiSourceLang)를 단일 소스와 독립 저장.
//    1.6.0 - 음성 입력 없을 때 자동 중지 옵션 추가(secondsWithoutAudio: 0/60/180/300/600)
//

import SwiftUI
import Combine

final class AppSettings: ObservableObject {

    @AppStorage("geminiApiKey") var geminiApiKey: String = ""

    @AppStorage("sourceLang") var sourceLang: String = "ko"
    @AppStorage("targetLang") var targetLang: String = "en"

    // 다국어 모드 화자(speaker) 언어 — 단일 언어 소스와 독립 (예: 화자 한국어 → 청중 영/중/일)
    @AppStorage("multiSourceLang") var multiSourceLang: String = "ko"

    @AppStorage("playTranslatedAudio") var playTranslatedAudio: Bool = false

    // 다국어 모드에서 음성으로 재생할 언어 1개 (빈 값 = 끄기)
    @AppStorage("multiAudioLang") var multiAudioLang: String = ""

    @AppStorage("glossaryJSON") var glossaryJSON: String = "[]"

    // 다국어 모드: 청중 언어 목록 (기본: 영어/중국어 간체/일본어)
    @AppStorage("audienceLangsJSON") var audienceLangsJSON: String = "[\"en\",\"zh-Hans\",\"ja\"]"

    // v1.6.0 추가: 음성 입력이 없을 때 자동 중지 시간 (초)
    // 0 = 비활성화, 60 = 1분, 180 = 3분, 300 = 5분, 600 = 10분
    @AppStorage("secondsWithoutAudio") var secondsWithoutAudio: Int = 0

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

    func loadAudienceLangs() -> [String] {
        guard let data = audienceLangsJSON.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return arr
    }

    func saveAudienceLangs(_ langs: [String]) {
        guard let data = try? JSONEncoder().encode(langs),
              let str = String(data: data, encoding: .utf8)
        else { return }
        audienceLangsJSON = str
    }
}

struct LangOption: Identifiable, Hashable {
    let id: String
    let label: String
}

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

struct GlossaryItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var source: String
    var target: String
}
