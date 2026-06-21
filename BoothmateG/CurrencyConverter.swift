import Foundation
import Combine

@MainActor
class CurrencyConverter: ObservableObject {

    // MARK: - Properties

    @Published var rates: [String: Double] = [
        "USD": 1340.0,
        "EUR": 1460.0,
        "GBP": 1700.0,
        "JPY": 9.0,
        "CNY": 185.0
    ]
    @Published var lastUpdated: Date?
    @Published var isLoading = false

    private let symbolToCode: [(String, String, String)] = [
        ("$", "USD", #"\$"#),
        ("€", "EUR", "€"),
        ("£", "GBP", "£"),
        ("¥", "JPY", "¥"),
        ("元", "CNY", "元"),
    ]

    // MARK: - Fetch Rates

    func fetchRates() {
        guard !isLoading else { return }
        isLoading = true

        Task {
            do {
                let url = URL(string: "https://open.er-api.com/v6/latest/KRW")!
                let (data, _) = try await URLSession.shared.data(from: url)

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ratesDict = json["rates"] as? [String: Double] {
                    var newRates: [String: Double] = [:]
                    for code in ["USD", "EUR", "GBP", "JPY", "CNY"] {
                        if let rate = ratesDict[code], rate > 0 {
                            newRates[code] = 1.0 / rate
                        }
                    }
                    if !newRates.isEmpty {
                        self.rates = newRates
                        self.lastUpdated = Date()
                        print("💱 환율 업데이트 완료: \(newRates)")
                    }
                }
            } catch {
                print("환율 가져오기 실패: \(error.localizedDescription)")
            }
            self.isLoading = false
        }
    }

    // MARK: - Apply Currency Conversion

    func applyConversion(to text: String) -> String {
            var output = text

            // 1. $숫자억/조 패턴 먼저 (한국어에서 $24억 같은 것)
            output = convertDollarKoreanUnit(in: output)

            // 2. 원화 → 달러
            output = convertKRWtoUSD(in: output)

            // 3. 한국어 달러 표현
            output = convertKoreanDollar(in: output)

            // 4. million/billion/trillion
            output = convertLargeAmount(in: output)

            // 5. 영어 원화 표현 → 달러 ("20 million won" → "$13,540")
            output = convertEnglishWon(in: output)

            // 6. 일반 외화 → 원화
            output = convertForeignToKRW(in: output)

            return output
        }

    // MARK: - 영어: 외화 → 원화

    private func convertForeignToKRW(in text: String) -> String {
        var output = text

        for (_, code, regexSymbol) in symbolToCode {
            guard let rate = rates[code] else { continue }

            let pattern = "\(regexSymbol)\\s*(\\d+(?:,\\d+)*(?:\\.\\d+)?)"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }

            let nsText = output as NSString
            let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

            for match in matches.reversed() {
                let fullMatch = nsText.substring(with: match.range)
                let afterIndex = match.range.location + match.range.length

                if afterIndex < nsText.length && nsText.character(at: afterIndex) == Character("(").asciiValue! { continue }

                if afterIndex < nsText.length {
                                    let remaining = min(9, nsText.length - afterIndex)
                                    let afterText = nsText.substring(with: NSRange(location: afterIndex, length: remaining))
                                    let afterLower = afterText.lowercased()
                                    if afterLower.hasPrefix(" million") || afterLower.hasPrefix(" billion") || afterLower.hasPrefix(" trillio") { continue }
                                    // 한국어: $24억, $24 억 등 건너뛰기
                                    if afterText.hasPrefix("억") || afterText.hasPrefix("조") || afterText.hasPrefix("만") ||
                                       afterText.hasPrefix(" 억") || afterText.hasPrefix(" 조") || afterText.hasPrefix(" 만") { continue }
                                }

                let beforeText = nsText.substring(to: match.range.location)
                let openCount = beforeText.filter({ $0 == "(" }).count
                let closeCount = beforeText.filter({ $0 == ")" }).count
                if openCount > closeCount { continue }

                let numberStr = nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
                guard let amount = Double(numberStr) else { continue }

                let krw = amount * rate
                let krwText = formatKRW(krw)
                output = (output as NSString).replacingCharacters(in: match.range, with: "\(fullMatch)(\(krwText))")
            }
        }

        return output
    }

    // MARK: - 영어: Million/Billion/Trillion

    private func convertLargeAmount(in text: String) -> String {
        var output = text

        let patterns: [(String, String, Double)] = [
            (#"\$\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*trillion"#, "USD", 1_000_000_000_000),
            (#"\$\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*billion"#, "USD", 1_000_000_000),
            (#"\$\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*million"#, "USD", 1_000_000),
            (#"€\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*trillion"#, "EUR", 1_000_000_000_000),
            (#"€\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*billion"#, "EUR", 1_000_000_000),
            (#"€\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*million"#, "EUR", 1_000_000),
            (#"£\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*trillion"#, "GBP", 1_000_000_000_000),
            (#"£\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*billion"#, "GBP", 1_000_000_000),
            (#"£\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*million"#, "GBP", 1_000_000),
        ]

        for (pattern, code, multiplier) in patterns {
            guard let rate = rates[code],
                  let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }

            let nsText = output as NSString
            let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

            for match in matches.reversed() {
                let fullMatch = nsText.substring(with: match.range)
                let afterIndex = match.range.location + match.range.length
                if afterIndex < nsText.length && nsText.character(at: afterIndex) == Character("(").asciiValue! { continue }

                let beforeText = nsText.substring(to: match.range.location)
                let openCount = beforeText.filter({ $0 == "(" }).count
                let closeCount = beforeText.filter({ $0 == ")" }).count
                if openCount > closeCount { continue }

                let numberStr = nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
                guard let amount = Double(numberStr) else { continue }

                let krw = amount * multiplier * rate
                let krwText = formatKRW(krw)
                output = (output as NSString).replacingCharacters(in: match.range, with: "\(fullMatch)(\(krwText))")
            }
        }

        // v3.6.0: "200 million dollars" / "2 billion dollars" 패턴 (기호 없이 뒤에 dollars/euros/pounds)
        let wordPatterns: [(String, String, Double)] = [
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*trillion\s*dollars"#, "USD", 1_000_000_000_000),
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*billion\s*dollars"#, "USD", 1_000_000_000),
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*million\s*dollars"#, "USD", 1_000_000),
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*trillion\s*euros"#, "EUR", 1_000_000_000_000),
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*billion\s*euros"#, "EUR", 1_000_000_000),
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*million\s*euros"#, "EUR", 1_000_000),
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*trillion\s*pounds"#, "GBP", 1_000_000_000_000),
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*billion\s*pounds"#, "GBP", 1_000_000_000),
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*million\s*pounds"#, "GBP", 1_000_000),
        ]

        for (wdPattern, wdCode, wdMultiplier) in wordPatterns {
            guard let wdRate = rates[wdCode],
                  let wdRegex = try? NSRegularExpression(pattern: wdPattern, options: .caseInsensitive) else { continue }

            let nsText2 = output as NSString
            let wdMatches = wdRegex.matches(in: output, range: NSRange(location: 0, length: nsText2.length))

            for match in wdMatches.reversed() {
                let fullMatch = nsText2.substring(with: match.range)
                let afterIndex = match.range.location + match.range.length
                if afterIndex < nsText2.length && nsText2.character(at: afterIndex) == Character("(").asciiValue! { continue }

                let beforeText = nsText2.substring(to: match.range.location)
                if beforeText.filter({ $0 == "(" }).count > beforeText.filter({ $0 == ")" }).count { continue }

                let numberStr = nsText2.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
                guard let amount = Double(numberStr) else { continue }

                let krw = amount * wdMultiplier * wdRate
                let krwText = formatKRW(krw)
                output = (output as NSString).replacingCharacters(in: match.range, with: "\(fullMatch)(\(krwText))")
            }
        }

        // v3.6.0: "2,000 dollars" / "100,000 dollars" (million/billion 없는 일반 숫자 + dollars)
        let plainDollarPatterns: [(String, String)] = [
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*dollars"#, "USD"),
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*euros"#, "EUR"),
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*pounds"#, "GBP"),
        ]

        for (pdPattern, pdCode) in plainDollarPatterns {
            guard let pdRate = rates[pdCode],
                  let pdRegex = try? NSRegularExpression(pattern: pdPattern, options: .caseInsensitive) else { continue }

            let nsText3 = output as NSString
            let pdMatches = pdRegex.matches(in: output, range: NSRange(location: 0, length: nsText3.length))

            for match in pdMatches.reversed() {
                let fullMatch = nsText3.substring(with: match.range)
                let afterIndex = match.range.location + match.range.length
                if afterIndex < nsText3.length && nsText3.character(at: afterIndex) == Character("(").asciiValue! { continue }

                let beforeText = nsText3.substring(to: match.range.location)
                if beforeText.filter({ $0 == "(" }).count > beforeText.filter({ $0 == ")" }).count { continue }
                // million/billion 패턴에서 이미 처리됐으면 스킵
                let beforeLower = beforeText.lowercased()
                if beforeLower.hasSuffix("million ") || beforeLower.hasSuffix("billion ") || beforeLower.hasSuffix("trillion ") { continue }

                let numberStr = nsText3.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
                guard let amount = Double(numberStr) else { continue }

                let krw = amount * pdRate
                let krwText = formatKRW(krw)
                output = (output as NSString).replacingCharacters(in: match.range, with: "\(fullMatch)(\(krwText))")
            }
        }

        return output
    }

    // MARK: - 한국어: 원화 → 달러

    private func convertKRWtoUSD(in text: String) -> String {
        var output = text
        guard let usdRate = rates["USD"], usdRate > 0 else { return output }

        // 한글 숫자 + 조/억/만원
        let koreanUnits: [(String, Double)] = [
            ("조원", 1_0000_0000_0000), ("조 원", 1_0000_0000_0000),
            ("억원", 1_0000_0000), ("억 원", 1_0000_0000),
            ("만원", 10000), ("만 원", 10000),
        ]
        let koreanDigits: [(String, Double)] = [
            ("일", 1), ("이", 2), ("삼", 3), ("사", 4), ("오", 5),
            ("육", 6), ("칠", 7), ("팔", 8), ("구", 9), ("십", 10),
        ]

        for (unit, multiplier) in koreanUnits {
            for (kDigit, kValue) in koreanDigits {
                let escaped = NSRegularExpression.escapedPattern(for: unit)
                let pattern = "\(kDigit)\\s*\(escaped)"
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }

                let nsText = output as NSString
                let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

                for match in matches.reversed() {
                    let fullMatch = nsText.substring(with: match.range)
                    let afterIndex = match.range.location + match.range.length
                    if afterIndex < nsText.length && nsText.character(at: afterIndex) == Character("(").asciiValue! { continue }

                    let krw = kValue * multiplier
                    let usd = krw / usdRate
                    let usdText = formatUSDsimple(usd)
                    output = (output as NSString).replacingCharacters(in: match.range, with: "\(fullMatch)(\(usdText))")
                }
            }
        }

        // 숫자 + 조원/억원/만원/천원
        output = convertKRWUnit(in: output, pattern: #"₩?\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*조\s*원"#, multiplier: 1_0000_0000_0000, usdRate: usdRate)
        output = convertKRWUnit(in: output, pattern: #"₩?\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*억\s*원"#, multiplier: 1_0000_0000, usdRate: usdRate)
        output = convertKRWUnit(in: output, pattern: #"₩?\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*만\s*원"#, multiplier: 10000, usdRate: usdRate)
        output = convertKRWUnit(in: output, pattern: #"₩?\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*천\s*원"#, multiplier: 1000, usdRate: usdRate)

        // ₩ + 숫자
        output = convertKRWUnit(in: output, pattern: #"₩\s*(\d+(?:,\d+)*(?:\.\d+)?)"#, multiplier: 1, usdRate: usdRate)

        // 큰 숫자 + 원 → 한글 단위로 변환
        if let regex = try? NSRegularExpression(pattern: #"(\d{1,3}(?:,\d{3})+)\s*원"#, options: []) {
            let nsText = output as NSString
            let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

            for match in matches.reversed() {
                let fullMatch = nsText.substring(with: match.range)
                let afterIndex = match.range.location + match.range.length
                if afterIndex < nsText.length && nsText.character(at: afterIndex) == Character("(").asciiValue! { continue }

                let beforeText = nsText.substring(to: match.range.location)
                let openCount = beforeText.filter({ $0 == "(" }).count
                let closeCount = beforeText.filter({ $0 == ")" }).count
                if openCount > closeCount { continue }

                let numberStr = nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
                guard let krw = Double(numberStr) else { continue }

                let usd = krw / usdRate
                let krwKorean = formatKRWkorean(krw)
                let usdText = formatUSDsimple(usd)
                let replacement = "\(krwKorean)(\(usdText))"
                output = (output as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }

        return output
    }
    // MARK: - $숫자 + 억/조/만 (한국어 모드)

        private func convertDollarKoreanUnit(in text: String) -> String {
            var output = text
            guard let usdRate = rates["USD"], usdRate > 0 else { return output }

            let patterns: [(String, Double)] = [
                (#"\$\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*조"#, 1_000_000_000_000),
                (#"\$\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*억"#, 100_000_000),
                (#"\$\s*(\d+(?:,\d+)*(?:\.\d+)?)\s*만"#, 10000),
            ]

            for (pattern, multiplier) in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }

                let nsText = output as NSString
                let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

                for match in matches.reversed() {
                    let fullMatch = nsText.substring(with: match.range)
                    let afterIndex = match.range.location + match.range.length
                    if afterIndex < nsText.length && nsText.character(at: afterIndex) == Character("(").asciiValue! { continue }

                    let beforeText = nsText.substring(to: match.range.location)
                    let openCount = beforeText.filter({ $0 == "(" }).count
                    let closeCount = beforeText.filter({ $0 == ")" }).count
                    if openCount > closeCount { continue }

                    let numberStr = nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
                    guard let amount = Double(numberStr) else { continue }

                    let usd = amount * multiplier
                    let krw = usd * usdRate
                    let dollarKorean = formatDollarKorean(usd)
                    let krwText = formatKRW(krw)
                    let replacement = "\(dollarKorean)(\(krwText))"
                    output = (output as NSString).replacingCharacters(in: match.range, with: replacement)
                }
            }

            return output
        }
    
    // MARK: - 한국어: 달러 표현 → 한글 단위 + 원화 환산

    private func convertKoreanDollar(in text: String) -> String {
        var output = text
        guard let usdRate = rates["USD"], usdRate > 0 else { return output }

        // 숫자 + 조/억/만/천 달러
        let unitPatterns: [(String, Double)] = [
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*조\s*달러"#, 1_000_000_000_000),
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*억\s*달러"#, 100_000_000),
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*만\s*달러"#, 10000),
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*천\s*달러"#, 1000),
        ]

        for (pattern, multiplier) in unitPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }

            let nsText = output as NSString
            let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

            for match in matches.reversed() {
                let fullMatch = nsText.substring(with: match.range)
                let afterIndex = match.range.location + match.range.length
                if afterIndex < nsText.length && nsText.character(at: afterIndex) == Character("(").asciiValue! { continue }

                let numberStr = nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
                guard let amount = Double(numberStr) else { continue }

                let usd = amount * multiplier
                let krw = usd * usdRate
                let krwText = formatKRW(krw)
                output = (output as NSString).replacingCharacters(in: match.range, with: "\(fullMatch)(\(krwText))")
            }
        }

        // 큰 숫자 + 달러 (쉼표 포함) → 한글 단위 변환
        if let regex = try? NSRegularExpression(pattern: #"(\d{1,3}(?:,\d{3})+)\s*달러"#, options: []) {
            let nsText = output as NSString
            let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

            for match in matches.reversed() {
                let fullMatch = nsText.substring(with: match.range)
                let afterIndex = match.range.location + match.range.length
                if afterIndex < nsText.length && nsText.character(at: afterIndex) == Character("(").asciiValue! { continue }

                let beforeText = nsText.substring(to: match.range.location)
                let openCount = beforeText.filter({ $0 == "(" }).count
                let closeCount = beforeText.filter({ $0 == ")" }).count
                if openCount > closeCount { continue }

                let numberStr = nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
                guard let usd = Double(numberStr) else { continue }

                let krw = usd * usdRate
                let dollarKorean = formatDollarKorean(usd)
                let krwText = formatKRW(krw)
                output = (output as NSString).replacingCharacters(in: match.range, with: "\(dollarKorean)(\(krwText))")
            }
        }

        // 작은 숫자 + 달러 (쉼표 없는 것)
                if let regex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*달러"#, options: []) {
                    let nsText = output as NSString
                    let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

                    for match in matches.reversed() {
                        let fullMatch = nsText.substring(with: match.range)
                        let afterIndex = match.range.location + match.range.length
                        if afterIndex < nsText.length && nsText.character(at: afterIndex) == Character("(").asciiValue! { continue }

                        let beforeText = nsText.substring(to: match.range.location)
                        let openCount = beforeText.filter({ $0 == "(" }).count
                        let closeCount = beforeText.filter({ $0 == ")" }).count
                        if openCount > closeCount { continue }

                        let numberStr = nsText.substring(with: match.range(at: 1))
                        guard let usd = Double(numberStr) else { continue }

                        let krw = usd * usdRate
                        let krwText = formatKRW(krw)
                        output = (output as NSString).replacingCharacters(in: match.range, with: "\(fullMatch)(\(krwText))")
                    }
                }
        
        // 한글 숫자 + 조/억/만 달러
        let koreanDigits: [(String, Double)] = [
            ("일", 1), ("이", 2), ("삼", 3), ("사", 4), ("오", 5),
            ("육", 6), ("칠", 7), ("팔", 8), ("구", 9), ("십", 10),
        ]

        for (kDigit, kValue) in koreanDigits {
            for (unit, multiplier) in [("조 달러", 1_000_000_000_000.0), ("조달러", 1_000_000_000_000.0),
                                        ("억 달러", 100_000_000.0), ("억달러", 100_000_000.0),
                                        ("만 달러", 10000.0), ("만달러", 10000.0)] {
                let escaped = NSRegularExpression.escapedPattern(for: unit)
                let pattern = "\(kDigit)\\s*\(escaped)"
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }

                let nsText = output as NSString
                let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

                for match in matches.reversed() {
                    let fullMatch = nsText.substring(with: match.range)
                    let afterIndex = match.range.location + match.range.length
                    if afterIndex < nsText.length && nsText.character(at: afterIndex) == Character("(").asciiValue! { continue }

                    let usd = kValue * multiplier
                    let krw = usd * usdRate
                    let krwText = formatKRW(krw)
                    output = (output as NSString).replacingCharacters(in: match.range, with: "\(fullMatch)(\(krwText))")
                }
            }
        }

        return output
    }

    // MARK: - Helper: KRW Unit → USD

    private func convertKRWUnit(in text: String, pattern: String, multiplier: Double, usdRate: Double) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }

        var output = text
        let nsText = output as NSString
        let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

        for match in matches.reversed() {
            let fullMatch = nsText.substring(with: match.range)
            let afterIndex = match.range.location + match.range.length
            if afterIndex < nsText.length && nsText.character(at: afterIndex) == Character("(").asciiValue! { continue }

            let beforeText = nsText.substring(to: match.range.location)
            let openCount = beforeText.filter({ $0 == "(" }).count
            let closeCount = beforeText.filter({ $0 == ")" }).count
            if openCount > closeCount { continue }

            let numberStr = nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
            guard let amount = Double(numberStr) else { continue }

            let krw = amount * multiplier
            let usd = krw / usdRate
            let usdText = formatUSDsimple(usd)
            output = (output as NSString).replacingCharacters(in: match.range, with: "\(fullMatch)(\(usdText))")
        }

        return output
    }

    // MARK: - Formatting: KRW (외화→원화, 영어용)

    private func formatKRW(_ value: Double) -> String {
        if value < 10000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.maximumFractionDigits = 0
            let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
            return "₩\(formatted)"
        } else {
            return "₩약 \(koreanNumber(value))"
        }
    }

    // MARK: - Formatting: 원화를 한글 단위로 (10,000,000 → ₩1,000만원)

    private func formatKRWkorean(_ value: Double) -> String {
        let eok = 100_000_000.0
        let man = 10000.0

        if value >= eok {
            let e = Int(value / eok)
            let m = Int((value.truncatingRemainder(dividingBy: eok)) / man)
            let cheon = m / 1000
            if cheon > 0 {
                return "₩\(e)억\(cheon)천만원"
            }
            return "₩\(e)억원"
        } else if value >= man {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.maximumFractionDigits = 0
            let m = Int(value / man)
            let formatted = formatter.string(from: NSNumber(value: m)) ?? "\(m)"
            return "₩\(formatted)만원"
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.maximumFractionDigits = 0
            let formatted = formatter.string(from: NSNumber(value: Int(value))) ?? "\(Int(value))"
            return "₩\(formatted)원"
        }
    }

    // MARK: - Formatting: USD 심플 (원화→달러)

    private func formatUSDsimple(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return String(format: "$%.1f billion", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "$%.1f million", value / 1_000_000)
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.maximumFractionDigits = 0
            let formatted = formatter.string(from: NSNumber(value: Int(value))) ?? "\(Int(value))"
            return "$\(formatted)"
        }
    }

    // MARK: - Formatting: 달러를 한글 단위로 (20,000,000 → $2,000만)

    private func formatDollarKorean(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "$%.1f조", value / 1_000_000_000_000)
        } else if value >= 100_000_000 {
            let eok = Int(value / 100_000_000)
            let man = Int(value.truncatingRemainder(dividingBy: 100_000_000) / 10000)
            let cheon = man / 1000
            if cheon > 0 {
                return "$\(eok)억\(cheon)천만"
            }
            return "$\(eok)억"
        } else if value >= 10000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.maximumFractionDigits = 0
            let man = Int(value / 10000)
            let formatted = formatter.string(from: NSNumber(value: man)) ?? "\(man)"
            return "$\(formatted)만"
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.maximumFractionDigits = 0
            let formatted = formatter.string(from: NSNumber(value: Int(value))) ?? "\(Int(value))"
            return "$\(formatted)"
        }
    }

    // MARK: - Korean Number (Double)

    private func koreanNumber(_ value: Double) -> String {
        let gyeong = 10000_0000_0000_0000.0
        let jo = 10000_0000_0000.0
        let eok = 10000_0000.0
        let man = 10000.0

        if value >= gyeong {
            let g = Int(value / gyeong)
            let j = Int(value.truncatingRemainder(dividingBy: gyeong) / jo)
            if j > 0 {
                return "\(g)경\(subUnit4(j))조원"
            }
            return "\(g)경원"
        } else if value >= jo {
            let j = Int(value / jo)
            let e = Int(value.truncatingRemainder(dividingBy: jo) / eok)
            if e > 0 {
                return "\(j)조\(subUnit4(e))억원"
            }
            return "\(j)조원"
        } else if value >= eok {
            let e = Int(value / eok)
            let m = Int(value.truncatingRemainder(dividingBy: eok) / man)
            if m > 0 {
                return "\(e)억\(subUnit4Full(m))만원"
            }
            return "\(e)억원"
        } else if value >= man {
            let m = Int(value / man)
            return "\(subUnit4Full(m))만원"
        } else {
            return "\(Int(value))원"
        }
    }

    // 4자리: 천백 (억 이상 하위)
    private func subUnit4(_ value: Int) -> String {
        if value == 0 { return "" }
        var result = ""
        let cheon = value / 1000
        let baek = (value % 1000) / 100
        if cheon > 0 { result += "\(cheon)천" }
        if baek > 0 { result += "\(baek)백" }
        return result
    }

    // 4자리: 천백십일 모두 (만 단위용)
    // 4자리: 숫자+쉼표로 표시 (만 단위용)
        private func subUnit4Full(_ value: Int) -> String {
            if value == 0 { return "" }
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }

    // MARK: - 영어: 원화 표현 → 달러 ("20 million won" → "$13,540")

    private func convertEnglishWon(in text: String) -> String {
        var output = text
        guard let usdRate = rates["USD"], usdRate > 0 else { return output }

        // "20 million won", "1.5 billion won", "500 trillion won"
        let patterns: [(String, Double)] = [
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*trillion\s*won"#, 1_000_000_000_000),
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*billion\s*won"#, 1_000_000_000),
            (#"(\d+(?:,\d+)*(?:\.\d+)?)\s*million\s*won"#, 1_000_000),
        ]

        for (pattern, multiplier) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }

            let nsText = output as NSString
            let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

            for match in matches.reversed() {
                let fullMatch = nsText.substring(with: match.range)
                let afterIndex = match.range.location + match.range.length
                if afterIndex < nsText.length && nsText.character(at: afterIndex) == Character("(").asciiValue! { continue }

                let beforeText = nsText.substring(to: match.range.location)
                let openCount = beforeText.filter({ $0 == "(" }).count
                let closeCount = beforeText.filter({ $0 == ")" }).count
                if openCount > closeCount { continue }

                let numberStr = nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
                guard let amount = Double(numberStr) else { continue }

                let krw = amount * multiplier
                let usd = krw / usdRate
                let usdText = formatUSDsimple(usd)
                output = (output as NSString).replacingCharacters(in: match.range, with: "\(fullMatch)(\(usdText))")
            }
        }

        // 단순 "숫자 won" (큰 단위 없는 경우, 쉼표 있는 숫자만)
        if let regex = try? NSRegularExpression(pattern: #"(\d{1,3}(?:,\d{3})+)\s*won"#, options: .caseInsensitive) {
            let nsText = output as NSString
            let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

            for match in matches.reversed() {
                let fullMatch = nsText.substring(with: match.range)
                let afterIndex = match.range.location + match.range.length
                if afterIndex < nsText.length && nsText.character(at: afterIndex) == Character("(").asciiValue! { continue }

                let beforeText = nsText.substring(to: match.range.location)
                let openCount = beforeText.filter({ $0 == "(" }).count
                let closeCount = beforeText.filter({ $0 == ")" }).count
                if openCount > closeCount { continue }

                let numberStr = nsText.substring(with: match.range(at: 1)).replacingOccurrences(of: ",", with: "")
                guard let amount = Double(numberStr) else { continue }

                let usd = amount / usdRate
                let usdText = formatUSDsimple(usd)
                output = (output as NSString).replacingCharacters(in: match.range, with: "\(fullMatch)(\(usdText))")
            }
        }

        return output
    }
}
