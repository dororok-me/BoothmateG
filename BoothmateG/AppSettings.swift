//
//  AppSettings.swift
//  BoothmateG
//
//  Version: 1.10.0
//  Changelog:
//    1.10.0 - 단위·환율 자동 변환 토글(convertUnitsCurrency) 추가. 단일 언어 모드 번역문에
//             단위/환율 환산을 괄호로 덧붙임. (UnitConverter/CurrencyConverter 연동)
//    1.9.0 - 통역 지침(interpretGuide, 자유 서술) + 단어 블랙리스트(blacklistWords) 저장 추가.
//            systemInstruction에 합쳐 주입(번역 톤·인칭 지시 + 필러 생략).
//    1.2.0 - 지원 언어 전체 + BCP-47 코드
//    1.3.0 - 청중 언어(다국어 모드 타겟들) 저장 추가
//    1.4.0 - 다국어 모드에서 음성 재생할 언어 1개 저장(multiAudioLang) 추가
//    1.5.0 - 다국어 모드 화자 언어(multiSourceLang)를 단일 소스와 독립 저장.
//    1.6.0 - 음성 입력 없을 때 자동 중지 옵션 추가(secondsWithoutAudio: 0/60/180/300/600)
//    1.8.0 - 새 방식(번역쌍 매칭) 용어장 추가(glossaryPairJSON, GlossaryPair 모델, load/save).
//            적용 방식 전환 플래그(useGlossaryPairMode). 기존 glossary와 완전 별도.
//    1.7.0 - Fish Audio TTS 설정 추가(fishApiKey/fishEnabled/fishLang/fishReferenceId/fishModel).
//            특정 언어 1개만 Fish 음성, 나머지는 Gemini 기본 음성.
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

    // v1.8.0: 새 방식(번역쌍 매칭) 용어장 — 기존과 별도 저장.
    // 원문어(source) + 표준표기(canonical) + 학습된 번역어 캐시(learnedTargets).
    @AppStorage("glossaryPairJSON") var glossaryPairJSON: String = "[]"
    // v1.8.0: 적용할 글로서리 방식 (false = 기존 동일언어 치환, true = 새 번역쌍 방식)
    @AppStorage("useGlossaryPairMode") var useGlossaryPairMode: Bool = false

    // v1.9.0: 통역 지침(자유 서술) — AI에게 번역 톤·격식·인칭 방향을 지시.
    //  예: "청중은 정부 고위 관계자. 정중한 격식체로. 3인칭·2인칭은 '의장님'으로 통일."
    @AppStorage("interpretGuide") var interpretGuide: String = ""
    // v1.9.0: 단어 블랙리스트(생략할 필러) — 콤마 구분. 예: "음, 어, 저기, 그러니까요"
    @AppStorage("blacklistWords") var blacklistWords: String = ""

    // 다국어 모드: 청중 언어 목록 (기본: 영어/중국어 간체/일본어)
    @AppStorage("audienceLangsJSON") var audienceLangsJSON: String = "[\"en\",\"zh-Hans\",\"ja\"]"

    // v1.6.0 추가: 음성 입력이 없을 때 자동 중지 시간 (초)
    // 0 = 비활성화, 60 = 1분, 180 = 3분, 300 = 5분, 600 = 10분
    @AppStorage("secondsWithoutAudio") var secondsWithoutAudio: Int = 0

    // v1.7.0 추가: Fish Audio TTS (특정 언어 1개만 Fish 음성으로, 나머지는 Gemini 기본 음성)
    @AppStorage("fishApiKey") var fishApiKey: String = ""        // Fish Audio API 키
    @AppStorage("fishEnabled") var fishEnabled: Bool = false     // Fish 음성 사용 여부
    @AppStorage("fishLang") var fishLang: String = ""            // Fish로 내보낼 언어 1개 (빈 값 = 끄기)
    @AppStorage("fishReferenceId") var fishReferenceId: String = ""  // Fish 음성 모델 ID (빈 값 = 기본 음성)
    @AppStorage("fishModel") var fishModel: String = "s1"        // Fish 모델 (s1 / s2-pro)

    // v1.10.0: 단위·환율 자동 변환 (단일 언어 모드). 번역문에 "5마일(8km)", "$1,000(1,400만원)" 식으로 덧붙임.
    @AppStorage("convertUnitsCurrency") var convertUnitsCurrency: Bool = false

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

    // v1.8.0: 새 방식(번역쌍) 용어장 불러오기/저장
    func loadGlossaryPairs() -> [GlossaryPair] {
        guard let data = glossaryPairJSON.data(using: .utf8),
              let items = try? JSONDecoder().decode([GlossaryPair].self, from: data)
        else { return [] }
        return items
    }

    func saveGlossaryPairs(_ items: [GlossaryPair]) {
        guard let data = try? JSONEncoder().encode(items),
              let str = String(data: data, encoding: .utf8)
        else { return }
        glossaryPairJSON = str
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

// v1.8.0: 새 방식(번역쌍 매칭) 용어 모델.
//  - source: 원문어 (예: "patient") — 원문에 이게 있으면 발동
//  - canonical: 타겟 표준표기 (예: "피험자") — 화면에 이 표기로 통일
//  - learnedTargets: 앱이 학습한 "실제 번역어" 캐시 (예: ["환자","환자분"])
//    원문에 source가 있을 때, 타겟에서 이 단어들을 찾아 canonical로 교체. 조사는 그대로 둠.
struct GlossaryPair: Identifiable, Codable, Hashable {
    var id = UUID()
    var source: String
    var canonical: String
    var learnedTargets: [String] = []
}
