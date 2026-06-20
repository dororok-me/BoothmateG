//
//  GlossaryPairEngine.swift
//  BoothmateG
//
//  Version: 1.5.0
//  Changelog:
//    1.5.0 - phrase(여러 단어 구) 부분 매칭·자기 간섭 버그 수정. 통합 치환(applySubstitutions):
//            (1) 방아쇠 구 전체를 치환 후보에 추가(통짜 매칭), (2) 긴 표현의 부분 조각인 유사
//            표현 제거(예 government budget), (3) 이미 치환한 영역 보호로 재치환·중복 차단.
//            기존 replaceKorean/replaceEnglish는 보존(미사용).
//    1.0.0 - 새 방식(번역쌍 매칭) 엔진. 원문 대조 후 타겟의 번역어를 표준표기로 교체.
//    1.4.0 - 자기 증식 차단: 한국어 치환을 정규식 1회 스캔으로 통합(조사 선택적 매칭).
//            표준표기가 번역어를 포함해도(집→우리집) 새로 삽입된 부분을 재처리하지 않음.
//    1.3.0 - 한국어 조사 자동 보정: 교체된 단어 받침 유무에 맞춰 뒤따르는 조사 교정
//            (은/는, 이/가, 을/를, 과/와, 으로/로 등). 예: 개가→멍멍멍멍이.
//    1.2.0 - 진단 로그 추가([BMG][PairGlossary]): 호출 여부·매칭 수·교체 결과 콘솔 출력.
//    1.1.0 - 양방향 매칭: pair의 두 단어(예 patient↔피험자) 중 "원문 언어와 같은 쪽"을
//            방아쇠로, 반대쪽을 표준표기로 사용(영한 구별 없음).
//            매칭 규칙: 영어는 대소문자 무관 + 단어 사이 공백 개수 무관 + 끝 단어 단·복수(s/es) 허용,
//            그 외 단어 구성·소유격('s)은 정확히 일치해야 함. 한국어는 단순 포함.
//

import Foundation

final class GlossaryPairEngine {

    private var pairs: [GlossaryPair] = []

    func update(pairs: [GlossaryPair]) {
        self.pairs = pairs
    }

    // 원문 + 타겟을 받아, 양방향으로 매칭해 타겟을 교정.
    //  - 원문 언어 판별 → pair에서 그 언어 쪽 단어를 방아쇠, 반대쪽을 표준표기로.
    //  - 원문에 방아쇠어가 (규칙대로) 있으면 → 타겟에서 번역어(learnedTargets)를 표준표기로 교체.
    func apply(source: String, target: String) -> String {
        guard !pairs.isEmpty, !target.isEmpty, !source.isEmpty else { return target }
        let srcIsKorean = containsHangul(source)

        var subs: [(from: String, to: String)] = []
        for p in pairs {
            let a = p.source.trimmingCharacters(in: .whitespaces)      // 예: patient
            let b = p.canonical.trimmingCharacters(in: .whitespaces)   // 예: 피험자
            guard !a.isEmpty, !b.isEmpty else { continue }

            // 원문 언어와 같은 쪽을 방아쇠(trigger), 반대쪽을 표준표기(replaceWith)로.
            let aIsKorean = containsHangul(a)
            let trigger: String
            let replaceWith: String
            if srcIsKorean {
                // 원문이 한국어 → 한국어 단어가 방아쇠
                trigger = aIsKorean ? a : b
                replaceWith = aIsKorean ? b : a
            } else {
                // 원문이 영어 → 영어 단어가 방아쇠
                trigger = aIsKorean ? b : a
                replaceWith = aIsKorean ? a : b
            }

            // 원문에 방아쇠어가 있나?
            guard sourceContains(source, phrase: trigger) else { continue }

            // 타겟에서 바꿀 번역어들: 학습된 유사 표현 + 방아쇠 구 자체(원문 구가 타겟에 안 번역돼 남은 경우 통째 치환)
            for t in p.learnedTargets {
                let from = t.trimmingCharacters(in: .whitespaces)
                guard !from.isEmpty, from != replaceWith else { continue }
                subs.append((from, replaceWith))
            }
            // 방아쇠 구 전체도 후보로(예: "government budget proposal"이 타겟에 그대로 남으면 → "정부 예산안")
            if trigger != replaceWith {
                subs.append((trigger, replaceWith))
            }
        }
        guard !subs.isEmpty else {
            print("[BMG][PairGlossary] 호출됨: pairs=\(pairs.count) src=\(source.prefix(25)) → 매칭 0 (변화 없음)")
            return target
        }

        // v1.5.0: 겹침/부분조각/자기간섭을 막는 통합 치환(전체 일치 + 영역 보호).
        let result = applySubstitutions(target, subs: subs)
        print("[BMG][PairGlossary] 교체: \(target.prefix(25)) → \(result.prefix(25))")
        return result
    }

    // v1.5.0: 모든 치환을 "전체 일치 + 이미 치환한 영역 보호"로 한 번에 수행.
    //  - 부분 조각 유사 표현(긴 표현의 일부)은 제거 → phrase는 통짜로만 매칭.
    //  - 한 번 바꾼 글자 위치는 다시 안 건드림 → 자기 간섭("정부 정부 예산안") 차단.
    //  - 영어는 단어경계+단복수, 한국어는 조사 보정 포함.
    private func applySubstitutions(_ text: String, subs rawSubs: [(from: String, to: String)]) -> String {
        // 1) 중복 제거
        var uniq: [(from: String, to: String)] = []
        var seenPairs = Set<String>()
        for s in rawSubs {
            let key = s.from + "→" + s.to
            if seenPairs.contains(key) { continue }
            seenPairs.insert(key); uniq.append(s)
        }
        // 2) 부분 조각 제거: from이 더 긴 다른 from의 (단어경계) 부분이면 제거.
        //    예: "government budget"는 "government budget proposal"의 부분 → 제거.
        var subs: [(from: String, to: String)] = []
        for s in uniq {
            let isFragment = uniq.contains { other in
                other.from.count > s.from.count && isSubPhrase(s.from, of: other.from)
            }
            if !isFragment { subs.append(s) }
        }
        // 3) 긴 from부터(긴 구 우선 매칭)
        subs.sort { $0.from.count > $1.from.count }

        let ns = text as NSString
        guard ns.length > 0 else { return text }
        var claimed = [Bool](repeating: false, count: ns.length)   // 이미 치환된 위치
        var edits: [(loc: Int, len: Int, rep: String)] = []

        for s in subs {
            let isEng = isEnglishWord(s.from)
            let pattern: String
            if isEng {
                pattern = englishPhrasePattern(s.from)
            } else {
                pattern = "\(NSRegularExpression.escapedPattern(for: s.from))(\(josaAlternationPattern()))?"
            }
            let opts: NSRegularExpression.Options = isEng ? [.caseInsensitive] : []
            guard let re = try? NSRegularExpression(pattern: pattern, options: opts) else { continue }

            for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let r = m.range
                // 이미 점유된 영역과 겹치면 건너뜀
                var overlap = false
                var i = r.location
                while i < r.location + r.length {
                    if claimed[i] { overlap = true; break }
                    i += 1
                }
                if overlap { continue }

                var rep = s.to
                // 한국어: 뒤따르는 조사 받침 보정
                if !isEng, m.numberOfRanges > 1, m.range(at: 1).location != NSNotFound {
                    let josa = ns.substring(with: m.range(at: 1))
                    rep = s.to + correctedJosa(josa, for: s.to)
                }
                edits.append((r.location, r.length, rep))
                var j = r.location
                while j < r.location + r.length { claimed[j] = true; j += 1 }
            }
        }
        guard !edits.isEmpty else { return text }

        // 위치순으로 한 번에 조립
        edits.sort { $0.loc < $1.loc }
        var out = ""
        var cursor = 0
        for e in edits {
            if e.loc < cursor { continue }   // 안전(겹침 방지됨)
            out += ns.substring(with: NSRange(location: cursor, length: e.loc - cursor))
            out += e.rep
            cursor = e.loc + e.len
        }
        out += ns.substring(from: cursor)
        return out
    }

    // 받침에 민감한 조사쌍 (받침있을때, 받침없을때)
    private static let josaPairs: [(String, String)] = [
        ("은","는"), ("이","가"), ("을","를"), ("과","와"),
        ("으로","로"), ("이나","나"), ("이란","란"), ("이며","며"),
        ("이에요","예요"), ("이라","라"), ("이랑","랑"), ("이야","야")
    ]

    // 조사 정규식 대안(긴 것 먼저)
    private func josaAlternationPattern() -> String {
        (Self.josaPairs.flatMap { [$0.0, $0.1] })
            .sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
    }

    // 바뀐 단어(to) 받침에 맞게 조사 교정
    private func correctedJosa(_ josa: String, for to: String) -> String {
        guard let toLast = to.last else { return josa }
        let toHasJong = hasJongseong(toLast)
        for (withJong, without) in Self.josaPairs where josa == withJong || josa == without {
            return toHasJong ? withJong : without
        }
        return josa
    }

    // a가 b의 (단어경계) 부분 구인지 — 영어는 단어 단위, 한국어는 어절 단위로 판단.
    private func isSubPhrase(_ a: String, of b: String) -> Bool {
        if a == b { return false }
        // 양쪽을 공백 기준 토큰으로
        let at = a.split(separator: " ").map(String.init)
        let bt = b.split(separator: " ").map(String.init)
        guard !at.isEmpty, at.count < bt.count else {
            // 토큰이 같은 수 이상이면 부분 구로 보지 않음(단, 단일 토큰이 다른 단일 토큰의 일부인 경우는 별도)
            return false
        }
        // bt 안에 at가 연속으로 등장하는지(대소문자 무관)
        let aLower = at.map { $0.lowercased() }
        let bLower = bt.map { $0.lowercased() }
        if aLower.count > bLower.count { return false }
        for start in 0...(bLower.count - aLower.count) {
            if Array(bLower[start..<start+aLower.count]) == aLower { return true }
        }
        return false
    }

    // 한국어 치환 + 조사 자동 보정.
    // 바뀐 단어(to) 뒤에 받침에 민감한 조사가 오면, to의 받침 유무에 맞게 조사를 교정.
    // 예: "개가"→"멍멍멍멍" 시, "가"를 to('멍'받침○)에 맞춰 "이"로 → "멍멍멍멍이"
    private func replaceKorean(in text: String, from: String, to: String) -> String {
        guard let toLast = to.last, !from.isEmpty else {
            return text
        }
        let toHasJong = hasJongseong(toLast)   // 바뀐 단어 끝 글자 받침 유무

        // 받침유무로 갈리는 조사쌍: (받침있을때, 받침없을때)
        let josaPairs: [(String, String)] = [
            ("은","는"), ("이","가"), ("을","를"), ("과","와"),
            ("으로","로"), ("이나","나"), ("이란","란"), ("이며","며"),
            ("이에요","예요"), ("이라","라"), ("이랑","랑"), ("이야","야")
        ]
        let escFrom = NSRegularExpression.escapedPattern(for: from)
        // 조사를 "선택적"으로 한 번에 잡음: from(조사)? → 조사 있으면 보정, 없으면 그냥 교체.
        // 핵심: 정규식이 원본을 한 번만 스캔하므로, 새로 삽입된 to는 재처리되지 않음(자기 증식 차단).
        let allJosa = (josaPairs.flatMap { [$0.0, $0.1] })
            .sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        let pattern = "\(escFrom)(\(allJosa))?"
        guard let re = try? NSRegularExpression(pattern: pattern) else {
            return text.replacingOccurrences(of: from, with: to)
        }
        let ns = text as NSString
        var out = ""
        var lastEnd = 0
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            // 매치 앞부분 그대로 복사
            out += ns.substring(with: NSRange(location: lastEnd, length: m.range.location - lastEnd))
            // 뒤따르는 조사(있으면) 받침에 맞게 보정
            var corrected = ""
            let josaRange = m.range(at: 1)
            if josaRange.location != NSNotFound {
                let josa = ns.substring(with: josaRange)
                corrected = josa
                for (withJong, without) in josaPairs where josa == withJong || josa == without {
                    corrected = toHasJong ? withJong : without
                    break
                }
            }
            out += to + corrected
            lastEnd = m.range.location + m.range.length
        }
        out += ns.substring(from: lastEnd)
        return out
    }

    // 한글 음절의 받침(종성) 유무
    private func hasJongseong(_ ch: Character) -> Bool {
        guard let scalar = ch.unicodeScalars.first?.value,
              scalar >= 0xAC00, scalar <= 0xD7A3 else { return false }
        return (scalar - 0xAC00) % 28 != 0   // 28로 나눈 나머지 0이면 받침 없음
    }

    // ── 원문에 방아쇠 구/단어가 있는지 ──
    // 영어: 대소문자 무관 + 단어 사이 공백 개수 무관 + 끝 단어 단·복수(s/es) 허용 + 단어경계.
    //       소유격('s)이나 다른 단어 구성은 불일치.
    // 한국어/기타: 단순 포함(공백 무관).
    private func sourceContains(_ text: String, phrase: String) -> Bool {
        if isEnglishWord(phrase) {
            let pattern = englishPhrasePattern(phrase)
            if let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let r = NSRange(text.startIndex..., in: text)
                return re.firstMatch(in: text, options: [], range: r) != nil
            }
            return text.range(of: phrase, options: [.caseInsensitive]) != nil
        } else {
            // 한국어: 공백 개수 무관하게 비교(등록 구의 공백을 유연하게)
            let words = phrase.split(whereSeparator: { $0 == " " }).map(String.init)
            if words.count <= 1 {
                return text.contains(phrase)
            }
            let pattern = words.map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "\\s*")
            if let re = try? NSRegularExpression(pattern: pattern) {
                let r = NSRange(text.startIndex..., in: text)
                return re.firstMatch(in: text, options: [], range: r) != nil
            }
            return text.contains(phrase)
        }
    }

    // 영어 구를 정규식으로: 단어 사이 \s+, 끝 단어에 (es|s)? , 앞뒤 단어경계.
    private func englishPhrasePattern(_ phrase: String) -> String {
        let words = phrase.split(whereSeparator: { $0 == " " }).map(String.init)
        guard !words.isEmpty else { return NSRegularExpression.escapedPattern(for: phrase) }
        var parts: [String] = []
        for (i, w) in words.enumerated() {
            let escaped = NSRegularExpression.escapedPattern(for: w)
            if i == words.count - 1 {
                parts.append("\(escaped)(?:es|s)?")   // 마지막 단어만 단·복수 허용
            } else {
                parts.append(escaped)
            }
        }
        let body = parts.joined(separator: "\\s+")
        return "(?<![A-Za-z])\(body)(?![A-Za-z])"
    }

    // 타겟에서 영어 단어를 단·복수 포함해 단어경계로 치환
    private func replaceEnglish(in text: String, word: String, with replacement: String) -> String {
        let pattern = englishPhrasePattern(word)
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text.replacingOccurrences(of: word, with: replacement, options: [.caseInsensitive])
        }
        let full = NSRange(text.startIndex..., in: text)
        let template = NSRegularExpression.escapedTemplate(for: replacement)
        return re.stringByReplacingMatches(in: text, options: [], range: full, withTemplate: template)
    }

    private func containsHangul(_ s: String) -> Bool {
        s.unicodeScalars.contains { $0.value >= 0xAC00 && $0.value <= 0xD7A3 }
    }

    // 한글이 없고 영문자가 있으면 영어로 간주
    private func isEnglishWord(_ s: String) -> Bool {
        let hasHangul = containsHangul(s)
        let hasLatin = s.unicodeScalars.contains {
            ($0.value >= 0x41 && $0.value <= 0x5A) || ($0.value >= 0x61 && $0.value <= 0x7A)
        }
        return !hasHangul && hasLatin
    }
}
