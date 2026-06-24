//
//  GoogleAuth.swift
//  BoothmateG
//
//  Version: 1.0.0
//  Changelog:
//    1.0.0 - 최초 작성. ASWebAuthenticationSession 기반 구글 로그인(OAuth 2.0 + PKCE).
//            구글 id_token을 받아 FirebaseRelay가 Firebase 인증 토큰으로 교환하도록 넘긴다.
//            Firebase SDK 의존성 없이 REST만 사용(기존 FirebaseRelay 구조와 일관).
//            CLIENT_ID/REVERSED_CLIENT_ID는 GoogleService-Info.plist의 공개 식별자(비밀 아님).
//

import Foundation
import AuthenticationServices
import CryptoKit
import AppKit

final class GoogleAuth: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleAuth()

    // GoogleService-Info.plist에서 가져온 공개 클라이언트 식별자 (앱에 임베드되는 값, 비밀 아님)
    private let clientID = "405462508977-spnst4cvgdjlf7oem8141682jrabksjh.apps.googleusercontent.com"
    private let reversedClientID = "com.googleusercontent.apps.405462508977-spnst4cvgdjlf7oem8141682jrabksjh"

    private var session: ASWebAuthenticationSession?

    // ASWebAuthenticationSession이 로그인 창을 띄울 기준 윈도우
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
    }

    /// 구글 로그인 시작. 성공 시 구글 id_token 문자열을 completion으로 전달.
    func signIn(completion: @escaping (Result<String, Error>) -> Void) {
        let verifier = Self.makeCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)
        let redirectURI = "\(reversedClientID):/oauth2redirect"

        var comp = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        comp.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256")
        ]
        guard let authURL = comp.url else {
            completion(.failure(GoogleAuthError.badURL)); return
        }

        let s = ASWebAuthenticationSession(url: authURL, callbackURLScheme: reversedClientID) { [weak self] callbackURL, error in
            guard let self else { return }
            if let error { completion(.failure(error)); return }
            guard let callbackURL,
                  let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "code" })?.value else {
                completion(.failure(GoogleAuthError.noCode)); return
            }
            self.exchangeCodeForIDToken(code: code, verifier: verifier,
                                        redirectURI: redirectURI, completion: completion)
        }
        s.presentationContextProvider = self
        s.prefersEphemeralWebBrowserSession = false   // 구글 세션 유지(매번 재로그인 방지)
        self.session = s
        s.start()
    }

    // 인증 코드 → 토큰 교환 (id_token 추출)
    private func exchangeCodeForIDToken(code: String, verifier: String, redirectURI: String,
                                        completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://oauth2.googleapis.com/token") else {
            completion(.failure(GoogleAuthError.badURL)); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let form = [
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        req.httpBody = form
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error { completion(.failure(error)); return }
            guard let data,
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let idToken = j["id_token"] as? String else {
                completion(.failure(GoogleAuthError.noIDToken)); return
            }
            completion(.success(idToken))
        }.resume()
    }

    // MARK: - PKCE 유틸
    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).googleBase64URLString()
    }
    private static func codeChallenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).googleBase64URLString()
    }
}

enum GoogleAuthError: LocalizedError {
    case badURL, noCode, noIDToken
    var errorDescription: String? {
        switch self {
        case .badURL:    return "구글 인증 주소 생성 실패"
        case .noCode:    return "구글 인증 코드를 받지 못했습니다"
        case .noIDToken: return "구글 토큰 교환에 실패했습니다"
        }
    }
}

private extension Data {
    // base64url (PKCE용): +/= 를 -_ 와 제거로 치환
    func googleBase64URLString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
