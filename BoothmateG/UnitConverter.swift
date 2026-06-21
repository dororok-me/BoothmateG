//
//  UnitConverter.swift
//  BoothmateG
//
//  Version: 2.0.0
//  Changelog:
//    1.x   - (구) 길이/무게/온도/부피/면적 다방향 변환. 면적이 큰 숫자·쉼표에서 깨지는 문제 있었음.
//    2.0.0 - 면적 전용으로 단순화(양방향). 나머지(길이/무게/온도/부피) 제거.
//            · 제곱미터/㎡/m²/square meter(s) → 평 환산 괄호 추가
//            · square feet/sqft → 평
//            · acre(s) → 평
//            · 평 → 제곱미터(m²)
//            · 쉼표 든 큰 숫자 정확 처리(예: 200,000 / 5,000), 이미 괄호 뒤엔 중복 변환 안 함
//            표시 방식은 환율과 동일: 원문 뒤 괄호로 환산값. 예) "200,000 제곱미터(약 6만 평)"
//

import Foundation

struct UnitConverter {

    // MARK: - Main (면적 전용 양방향)
    static func applyConversion(to text: String) -> String {
        var output = text
        // 변환으로 새로 만든 환산 구간을 잠그기 위한 보호 저장소.
        // 변환 결과를 자리표시자로 치환 → 이후 다른 규칙이 그 안을 다시 변환하지 못하게 함.
        var vault: [String] = []

        func protect(_ converted: String) -> String {
            let token = "\u{E000}\(vault.count)\u{E001}"   // 사적 사용 영역 문자로 토큰화
            vault.append("(\(converted))")
            return token
        }

        // ── 영어 면적 → 평 ──
        output = convert(in: output,
                         pattern: #"(\d[\d,]*(?:\.\d+)?)\s*(?:square\s*feet|sq\.?\s*ft|sqft)"#,
                         protector: protect) { sqft in
            formatArea(sqft * 0.0281) + "평"
        }
        output = convert(in: output,
                         pattern: #"(\d[\d,]*(?:\.\d+)?)\s*(?:acres|acre)\b"#,
                         protector: protect) { acre in
            formatArea(acre * 1224.17) + "평"
        }
        output = convert(in: output,
                         pattern: #"(\d[\d,]*(?:\.\d+)?)\s*(?:square\s*meters?|sq\.?\s*m|m²|㎡|제곱\s*미터|제곱미터)"#,
                         protector: protect) { sqm in
            formatArea(sqm * 0.3025) + "평"
        }

        // ── 평 → 제곱미터 ── (위에서 만든 평은 이미 토큰으로 잠겨 있어 다시 안 걸림)
        output = convert(in: output,
                         pattern: #"(\d[\d,]*(?:\.\d+)?)\s*만\s*평"#,
                         protector: protect) { manPyeong in
            formatArea(manPyeong * 10000 * 3.3058) + "m²"
        }
        output = convert(in: output,
                         pattern: #"(\d[\d,]*(?:\.\d+)?)\s*평"#,
                         protector: protect) { pyeong in
            formatArea(pyeong * 3.3058) + "m²"
        }

        // 잠근 구간 복원
        for (i, val) in vault.enumerated() {
            output = output.replacingOccurrences(of: "\u{E000}\(i)\u{E001}", with: val)
        }
        return output
    }

    // MARK: - Generic Converter
    // 숫자(쉼표 포함)+단위를 찾아 원문 뒤에 환산을 붙이는 형태로 치환.
    // 환산 부분은 protector로 잠가, 이후 다른 규칙이 그 안을 재변환하지 못하게 함.
    private static func convert(in text: String,
                               pattern: String,
                               protector: (String) -> String,
                               converter: (Double) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return text
        }
        var output = text
        let nsText = output as NSString
        let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsText.length))

        for match in matches.reversed() {
            let fullMatch = nsText.substring(with: match.range)

            // 바로 뒤가 '(' 이면 이미 환산된 것 → 건너뜀
            let afterIndex = match.range.location + match.range.length
            if afterIndex < nsText.length {
                let nextChar = nsText.character(at: afterIndex)
                if let paren = Character("(").asciiValue, nextChar == UInt16(paren) {
                    continue
                }
            }

            // 숫자 추출(쉼표 제거)
            let numberStr = nsText.substring(with: match.range(at: 1))
                .replacingOccurrences(of: ",", with: "")
            guard let value = Double(numberStr) else { continue }

            let converted = converter(value)
            let token = protector(converted)                 // 환산부를 잠금
            let replacement = "\(fullMatch)\(token)"
            output = (output as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return output
    }

    // MARK: - Number Formatting
    // 면적은 큰 값이 많아 한국식으로: 1만 이상은 "약 N만 평", 그 외는 천단위 쉼표.
    private static func formatArea(_ value: Double) -> String {
        let rounded = value.rounded()

        if rounded >= 10000 {
            let man = rounded / 10000.0
            if abs(man - man.rounded()) < 0.05 {
                return "약 " + decimalString(man.rounded(), maxFrac: 0) + "만 "
            } else {
                return "약 " + decimalString(man, maxFrac: 1) + "만 "
            }
        }
        if rounded != value && value < 10 {
            return decimalString(value, maxFrac: 1)
        }
        return decimalString(rounded, maxFrac: 0)
    }

    private static func decimalString(_ value: Double, maxFrac: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.maximumFractionDigits = maxFrac
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.\(maxFrac)f", value)
    }
}
