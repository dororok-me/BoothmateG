//
//  GlossaryEngine.swift
//  BoothmateG
//
//  Version: 1.4.0
//  Changelog:
//    1.0.0 - 최초 작성. 번역 텍스트에 용어집 항목을 치환
//    1.1.0 - normalize() 추가: 콤마 별칭 + 양방향. 각 칸 첫 단어를 대표 표기로 통일
//    1.3.0 - 제거 항목 지원: source/target이 콤마로 시작하면(표준 빈칸) 그 별칭들을
//            빈 문자열로 치환 → 자막에서 삭제(군더더기 "음," "어," 제거용).
//    1.2.0 - 영어 표현 단·복수(s/es) 자동 인식:
//            영어 별칭은 단어 경계 + 끝의 (s|es)를 선택적으로 매칭하므로
//            "Net Zero"만 등록해도 "Net Zeros"/"Net Zeroes"까지 "Net Zero"로 통일.
//            한국어 별칭은 조사 결합 특성상 기존 단순 치환 유지.
//    1.4.0 - 행사 정보 기능 추가: EventInfo, Speaker 구조체 + 유사도 매칭(Levenshtein) +
//            번역 후처리 함수 applyEventInfo(). systemInstruction 생성 함수 추가.
//

import Foundation

// 용어집 항목으로 번역 텍스트의 단어를 바꿔주는 엔진.
// "번역 후 치환" 방식이라 결과를 받은 직후(또는 화면 표시 직전)에 통과시킴.
final class GlossaryEngine {

    private var items: [GlossaryItem] = []

    // 용어집 항목 갱신
    func update(items: [GlossaryItem]) {
        self.items = items.sorted { $0.source.count > $1.source.count }
    }

    // (구버전) 단순 치환 — 호환용으로 남겨둠. 현재 표시 경로는 normalize() 사용.
    func apply(to text: String) -> String {
        var result = text
        for item in items {
            guard !item.source.isEmpty, !item.target.isEmpty else { continue }
            result = result.replacingOccurrences(of: item.source, with: item.target)
        }
        return result
    }

    // ── 양방향 정규화 (v1.2.0: 영어 단·복수 자동) ───────────
    // 각 칸은 콤마 별칭 목록, 각 칸 "첫 단어"가 대표 표기.
    // 번역문에 어느 칸의 별칭이 나오든 → 그 칸의 대표 표기로 통일.
    func normalize(_ text: String) -> String {
        var result = text

        // (별칭, 대표표기) 쌍 모으기
        var pairs: [(alias: String, canonical: String)] = []
        for item in items {
            let col1 = splitAliases(item.source)
            let col2 = splitAliases(item.target)
            // v1.3.0: 원본이 콤마로 시작하면 "제거 항목"(표준이 빈칸) → 대표표기를 "" 로.
            //         별칭들이 빈 문자열로 치환되어 자막에서 사라짐(군더더기 제거용).
            let src1IsRemoval = item.source.trimmingCharacters(in: .whitespaces).hasPrefix(",")
            let src2IsRemoval = item.target.trimmingCharacters(in: .whitespaces).hasPrefix(",")
            if src1IsRemoval { for a in col1 { pairs.append((a, "")) } }
            else if let c1 = col1.first { for a in col1 { pairs.append((a, c1)) } }
            if src2IsRemoval { for a in col2 { pairs.append((a, "")) } }
            else if let c2 = col2.first { for a in col2 { pairs.append((a, c2)) } }
        }

        // 긴 별칭부터 (부분 일치 사고 방지)
        pairs.sort { $0.alias.count > $1.alias.count }

        for p in pairs where !p.alias.isEmpty {
            if isEnglish(p.alias) {
                // 영어: 단어 경계 + 끝의 (s|es) 선택적 → 단·복수 모두 통일
                result = replaceEnglish(in: result, alias: p.alias, canonical: p.canonical)
            } else {
                // 한국어 등: 기존 단순 치환 (대소문자 무시)
                result = result.replacingOccurrences(
                    of: p.alias, with: p.canonical, options: [.caseInsensitive])
            }
        }
        return result
    }

    // "넷제로, 제로배출, 무배출" → ["넷제로","제로배출","무배출"]
    private func splitAliases(_ s: String) -> [String] {
        s.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // 한글이 없고 영문자가 있으면 영어로 간주
    private func isEnglish(_ s: String) -> Bool {
        let hasHangul = s.unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7A3 }
        let hasLatin = s.unicodeScalars.contains {
            ($0.value >= 0x41 && $0.value <= 0x5A) || ($0.value >= 0x61 && $0.value <= 0x7A)
        }
        return !hasHangul && hasLatin
    }

    // 영어 별칭을 단어 경계 + 선택적 복수(s/es)까지 한 번에 치환
    private func replaceEnglish(in text: String, alias: String, canonical: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: alias)
        // 앞뒤가 영문자가 아닐 때만(단어 경계), 끝의 es/s는 있어도 됨
        let pattern = "(?<![A-Za-z])\(escaped)(?:es|s)?(?![A-Za-z])"
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text.replacingOccurrences(of: alias, with: canonical, options: [.caseInsensitive])
        }
        let full = NSRange(text.startIndex..., in: text)
        let template = NSRegularExpression.escapedTemplate(for: canonical)
        return re.stringByReplacingMatches(in: text, options: [], range: full, withTemplate: template)
    }

    // ── v1.4.0 추가: 행사 정보 관련 함수들 ──────────────────────────────────
    
    // 번역 후처리: 행사 정보로 강제 치환 + 유사도 매칭
    func applyEventInfo(to text: String, eventInfo: EventInfo) -> String {
        var result = text
        
        // 각 참석자 정보 처리
        for speaker in eventInfo.speakers {
            // 케이스 1: "직책 이름" 조합으로 강제 치환
            let combined = "\(speaker.position.en) \(speaker.name.en)"
            let escapedEn = NSRegularExpression.escapedPattern(for: combined)
            let pattern = "(?<![A-Za-z])(\(escapedEn))(?![A-Za-z])"
            if let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let full = NSRange(result.startIndex..., in: result)
                result = re.stringByReplacingMatches(in: result, options: [], range: full, withTemplate: combined)
            }
            
            // 케이스 2: 직책만 나왔으면 이름 추가
            if result.contains(speaker.position.en) && !result.contains(speaker.name.en) {
                let escapedPos = NSRegularExpression.escapedPattern(for: speaker.position.en)
                let posPattern = "(?<![A-Za-z])\(escapedPos)(?![A-Za-z])"
                if let re = try? NSRegularExpression(pattern: posPattern, options: [.caseInsensitive]) {
                    let full = NSRange(result.startIndex..., in: result)
                    let template = NSRegularExpression.escapedTemplate(for: combined)
                    result = re.stringByReplacingMatches(in: result, options: [], range: full, withTemplate: template)
                }
            }
            
            // 케이스 3: 비슷한 이름 (유사도 > 0.75)
            if similarity(result, speaker.name.en) > 0.75 {
                result = result.replacingOccurrences(of: speaker.name.en, with: speaker.name.en, options: [.caseInsensitive])
            }
        }
        
        return result
    }
    
    // systemInstruction 생성: 행사 정보를 명령문으로
    func generateEventInstruction(eventInfo: EventInfo) -> String {
        var instruction = """
        
        === 행사 정보 (Event Information) ===
        """
        
        if !eventInfo.eventName.en.isEmpty {
            instruction += "\n행사명 | Event Name: \(eventInfo.eventName.ko) / \(eventInfo.eventName.en)"
        }
        if !eventInfo.venue.en.isEmpty {
            instruction += "\n장소 | Venue: \(eventInfo.venue.ko) / \(eventInfo.venue.en)"
        }
        if !eventInfo.dateTime.en.isEmpty {
            instruction += "\n일시 | Date/Time: \(eventInfo.dateTime.ko) / \(eventInfo.dateTime.en)"
        }
        
        if !eventInfo.speakers.isEmpty {
            instruction += "\n\n참석자 및 발표:\n"
            for (i, speaker) in eventInfo.speakers.enumerated() {
                instruction += """
                \(i + 1). 직책: \(speaker.position.ko) / \(speaker.position.en)
                   이름: \(speaker.name.ko) / \(speaker.name.en)
                   발표제목: \(speaker.presentationTitle.ko) / \(speaker.presentationTitle.en)
                
                """
            }
        }
        
        instruction += """
        위의 용어들은 번역 시 정확히 사용하시오.
        """
        
        return instruction
    }
    
    // 유사도 계산 (0.0~1.0)
    private func similarity(_ s1: String, _ s2: String) -> Double {
        let longer = s1.count > s2.count ? s1 : s2
        let shorter = s1.count > s2.count ? s2 : s1
        
        if longer.isEmpty { return 1.0 }
        
        let editDistance = levenshteinDistance(longer, shorter)
        return Double(longer.count - editDistance) / Double(longer.count)
    }
    
    // Levenshtein distance 계산
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1 = Array(s1), s2 = Array(s2)
        let m = s1.count, n = s2.count
        
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                if s1[i-1] == s2[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
                }
            }
        }
        
        return dp[m][n]
    }
}

// ── v1.4.0 추가: 행사 정보 데이터 구조 ──────────────────────────────────

struct BilingualText: Codable, Equatable {
    var ko: String = ""
    var en: String = ""
    
    init(_ ko: String = "", _ en: String = "") {
        self.ko = ko
        self.en = en
    }
}

struct Speaker: Codable, Identifiable, Equatable {
    var id = UUID()
    var position: BilingualText = BilingualText()
    var name: BilingualText = BilingualText()
    var presentationTitle: BilingualText = BilingualText()
    
    enum CodingKeys: String, CodingKey {
        case id, position, name, presentationTitle
    }
}

struct EventInfo: Codable, Equatable {
    var eventName: BilingualText = BilingualText()
    var venue: BilingualText = BilingualText()
    var dateTime: BilingualText = BilingualText()
    var speakers: [Speaker] = []
    
    mutating func reset() {
        eventName = BilingualText()
        venue = BilingualText()
        dateTime = BilingualText()
        speakers = []
    }
    
    var isEmpty: Bool {
        eventName.ko.isEmpty && eventName.en.isEmpty &&
        venue.ko.isEmpty && venue.en.isEmpty &&
        dateTime.ko.isEmpty && dateTime.en.isEmpty &&
        speakers.isEmpty
    }
}
