//
//  FirebaseRelay.swift
//  BoothmateG
//
//  Version: 2.8.0
//  Changelog:
//    2.8.0 - 행사용 글꼴 업로드(uploadFont) 추가: 호스트가 고른 글꼴(.ttf/.otf)을 Storage에 올리고
//            meta.fontUrl을 PATCH → 청중 sub.html이 자막에 그 글꼴을 적용. startBroadcast에 fontPath 추가.
//    2.7.0 - 구글 로그인 이메일을 키체인(googleEmail)에 저장 → 앱 재실행 자동복원 시에도
//            "Google 계정" 대신 실제 이메일을 표시. signOut에서 함께 삭제.
//    2.6.0 - [멀티유저 자막 경로 분리] 자막을 sessions/{sid} → sessions/{uid}/{sid}로 저장.
//            각 통역사가 자기 UID 칸에만 쓰므로 충돌 불가·남의 세션 덮어쓰기 방지(규칙과 함께).
//            authUID를 이메일/구글/자동복원 모든 로그인에서 일관되게 채움(localId·user_id).
//            송출 경로는 시작 시점 authUID를 캡처(sessionOwnerUID)해 사용. 관리(삭제)는 현재 authUID.
//            ※ 청중 QR 링크(?u=uid&s=sid)·sub.html·RTDB 규칙을 함께 새 구조로 바꿔야 작동.
//    2.5.0 - 구글 로그인 추가(signInWithGoogle). GoogleAuth가 받은 구글 id_token을
//            Firebase Identity Toolkit signInWithIdp로 교환해 기존 송출 토큰 흐름에 연결.
//            로그인 UID(authUID) 공개 + 구글 refreshToken 키체인 저장으로 자동 로그인.
//            기존 이메일/비번 로그인은 그대로 유지(append-only).
//    1.0.0 - 최초 작성. RTDB REST로 자막 실시간 송출.
//    1.1.0 - deleteSession 추가 (행사 종료 시 RTDB 세션 데이터 삭제).
//    2.0.0 - 보안: 호스트 로그인(Firebase Auth) + 모든 쓰기에 토큰 부착. 싱글톤화.
//    2.1.0 - 청중 음성(2단계): uploadAudioClip 추가. WAV 클립을 Storage에 올리고
//            RTDB /sessions/{id}/audioLive/{lang}에 {seq,url,ts} push.
//    2.2.0 - clearLive 추가.
//    2.3.0 - uploadLogo 추가: 행사 로고를 Storage(audio/{sid}/logo.ext)에 올리고
//            meta.logoUrl을 PATCH → 청중 페이지가 행사명 왼쪽에 로고 표시.
//            startBroadcast에 logoPath 파라미터(기본값 "") 추가.
//    2.4.0 - startBroadcast 시작 시 이전 라이브 자막·음성(live/audioLive) 자동 삭제.
//            같은 세션으로 다시 송출해도 청중 폰에 지난 자막이 남지 않음.
//

import Foundation
import Combine
import Security

// 호스트 자격증명 보관용 키체인 (맥 로컬, 평문 저장 안 함)
enum HostKeychain {
    static let service = "ai.dororok.BoothmateG.host"
    static func set(_ key: String, _ value: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = value.data(using: .utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
    static func get(_ key: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: key,
                                kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    static func clear(_ key: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: key]
        SecItemDelete(q as CFDictionary)
    }
}

final class FirebaseRelay: ObservableObject {
    static let shared = FirebaseRelay()

    // 자막용 새 RTDB 인스턴스 (기본 -default-rtdb 아님)
    static let dbURL = "https://dororokrealtimespeech.asia-southeast1.firebasedatabase.app"
    // 음성 클립 저장용 Storage 버킷
    static let storageBucket = "dororokrealtimespeech.firebasestorage.app"
    // Firebase 웹 API 키 (Auth REST용) — 클라이언트 키라 노출돼도 규칙으로 보호됨
    private let apiKey = "AIzaSyDFJUlehacd5sMAhr5MDkyFIgNXUCjdGAk"

    private(set) var sessionId: String?
    private(set) var active = false

    // 인증 상태 (UI 표시용)
    @Published var authReady = false
    @Published var authEmail = ""
    @Published var authError: String?
    // v2.5.0: 현재 로그인된 사용자 UID (멀티유저 자막 경로 분리에 사용)
    @Published var authUID = ""
    // v2.6.0: 송출 시작 시점에 캡처한 자막 경로 소유자 UID (sessions/{uid}/{sid})
    private var sessionOwnerUID = ""

    private var idToken: String?
    private var refreshToken: String?
    private var tokenExpiry: Date = .distantPast

    // 언어별 throttle (초당 약 3회로 제한)
    private let minInterval: TimeInterval = 0.35
    private var latest: [String: [String: Any]] = [:]
    private var lastSent: [String: Date] = [:]
    private var scheduled: Set<String> = []

    private init() {
        // 저장된 자격증명이 있으면 자동 로그인
        if let e = HostKeychain.get("email"), let p = HostKeychain.get("password"),
           !e.isEmpty, !p.isEmpty {
            authEmail = e
            signIn(email: e, password: p, save: false)
        }
        // v2.5.0: 구글 로그인 자동 복원 — 저장된 구글 refreshToken으로 토큰 갱신
        else if let grt = HostKeychain.get("googleRefresh"), !grt.isEmpty {
            self.refreshToken = grt
            // v2.7.0: 저장된 구글 이메일을 먼저 표시(없으면 폴백)
            let savedEmail = HostKeychain.get("googleEmail") ?? ""
            if !savedEmail.isEmpty { authEmail = savedEmail }
            withToken { [weak self] t in
                guard let self, let t, !t.isEmpty else { return }
                DispatchQueue.main.async {
                    self.authReady = true
                    if self.authEmail.isEmpty { self.authEmail = "Google 계정" }
                }
            }
        }
    }

    // MARK: - 인증

    /// 호스트 로그인. 성공 시 토큰 캐시 + (save=true면) 키체인에 자격증명 저장.
    func signIn(email: String, password: String, save: Bool = true) {
        guard !email.isEmpty, !password.isEmpty else { return }
        let urlStr = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(apiKey)"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "email": email, "password": password, "returnSecureToken": true
        ])
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self else { return }
            guard let data,
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { self.authReady = false; self.authError = "로그인 실패: 네트워크 오류" }
                return
            }
            if let tok = j["idToken"] as? String {
                self.idToken = tok
                self.refreshToken = j["refreshToken"] as? String
                let secs = Double(j["expiresIn"] as? String ?? "3600") ?? 3600
                self.tokenExpiry = Date().addingTimeInterval(secs)
                if save {
                    HostKeychain.set("email", email)
                    HostKeychain.set("password", password)
                }
                let uid = (j["localId"] as? String) ?? ""   // v2.6.0: 이메일 로그인도 UID 채움
                DispatchQueue.main.async {
                    self.authReady = true; self.authEmail = email; self.authUID = uid; self.authError = nil
                }
            } else {
                let msg = ((j["error"] as? [String: Any])?["message"] as? String) ?? "이메일/비밀번호 확인"
                DispatchQueue.main.async { self.authReady = false; self.authError = "로그인 실패: \(msg)" }
            }
        }.resume()
    }

    func signOut() {
        idToken = nil; refreshToken = nil; tokenExpiry = .distantPast
        HostKeychain.clear("email"); HostKeychain.clear("password")
        HostKeychain.clear("googleRefresh")   // v2.5.0: 구글 자동 로그인도 해제
        HostKeychain.clear("googleEmail")     // v2.7.0: 저장된 구글 이메일도 삭제
        DispatchQueue.main.async {
            self.authReady = false; self.authEmail = ""; self.authUID = ""; self.authError = nil
        }
    }

    // MARK: - 구글 로그인 (v2.5.0)

    /// 구글 로그인 시작 → 구글 id_token을 Firebase 인증 토큰으로 교환.
    func signInWithGoogle() {
        GoogleAuth.shared.signIn { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let e):
                DispatchQueue.main.async {
                    self.authReady = false
                    self.authError = "구글 로그인 실패: \(e.localizedDescription)"
                }
            case .success(let googleIDToken):
                self.exchangeGoogleToken(googleIDToken)
            }
        }
    }

    /// 구글 id_token → Firebase(Identity Toolkit signInWithIdp) 토큰 교환.
    private func exchangeGoogleToken(_ googleIDToken: String) {
        let urlStr = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=\(apiKey)"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "postBody": "id_token=\(googleIDToken)&providerId=google.com",
            "requestUri": "http://localhost",
            "returnIdpCredential": true,
            "returnSecureToken": true
        ])
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self else { return }
            guard let data,
                  let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tok = j["idToken"] as? String else {
                DispatchQueue.main.async {
                    self.authReady = false; self.authError = "구글 인증 교환 실패"
                }
                return
            }
            self.idToken = tok
            self.refreshToken = j["refreshToken"] as? String
            let secs = Double(j["expiresIn"] as? String ?? "3600") ?? 3600
            self.tokenExpiry = Date().addingTimeInterval(secs)
            // 구글 자동 로그인을 위해 refreshToken을 키체인에 저장
            if let rt = self.refreshToken, !rt.isEmpty { HostKeychain.set("googleRefresh", rt) }
            let email = (j["email"] as? String) ?? "Google 계정"
            // v2.7.0: 자동복원 시에도 실제 이메일을 표시하도록 키체인에 저장
            if email != "Google 계정" { HostKeychain.set("googleEmail", email) }
            let uid = (j["localId"] as? String) ?? ""
            DispatchQueue.main.async {
                self.authReady = true; self.authEmail = email
                self.authUID = uid; self.authError = nil
            }
        }.resume()
    }

    /// 유효한 토큰을 보장(필요 시 갱신)하고 콜백으로 전달. 없으면 nil.
    private func withToken(_ done: @escaping (String?) -> Void) {
        if let t = idToken, tokenExpiry.timeIntervalSinceNow > 300 { done(t); return }
        guard let rt = refreshToken else { done(idToken); return }
        let urlStr = "https://securetoken.googleapis.com/v1/token?key=\(apiKey)"
        guard let url = URL(string: urlStr) else { done(idToken); return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "grant_type=refresh_token&refresh_token=\(rt)".data(using: .utf8)
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self else { done(nil); return }
            if let data,
               let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let t = j["id_token"] as? String {
                self.idToken = t
                self.refreshToken = (j["refresh_token"] as? String) ?? self.refreshToken
                let secs = Double(j["expires_in"] as? String ?? "3600") ?? 3600
                self.tokenExpiry = Date().addingTimeInterval(secs)
                // v2.6.0: 자동 복원/갱신 시에도 UID 채움(refresh 응답의 user_id)
                if let uid = j["user_id"] as? String, !uid.isEmpty {
                    DispatchQueue.main.async { self.authUID = uid }
                }
                done(t)
            } else {
                done(self.idToken)
            }
        }.resume()
    }

    // MARK: - 송출 (기존 API 유지)

    func startBroadcast(sessionId: String, eventName: String, sessionName: String,
                        mode: String, langs: [String: String], logoPath: String = "", fontPath: String = "") {
        self.sessionId = sessionId
        self.sessionOwnerUID = authUID   // v2.6.0: 송출 경로 소유자 UID 캡처
        self.active = true
        latest.removeAll(); lastSent.removeAll(); scheduled.removeAll()
        let uid = sessionOwnerUID
        // v2.4.0: 송출 시작 시 이전 라이브 자막·음성을 먼저 삭제 → 청중 폰에 지난 자막이 남지 않음
        send("DELETE", "sessions/\(uid)/\(sessionId)/live", nil)
        send("DELETE", "sessions/\(uid)/\(sessionId)/audioLive", nil)
        let meta: [String: Any] = [
            "eventName": eventName,
            "sessionName": sessionName,
            "mode": mode,
            "langs": langs,
            "active": true
        ]
        send("PUT", "sessions/\(uid)/\(sessionId)/meta", meta)
        // 행사 로고가 있으면 Storage에 올리고 meta.logoUrl을 채움(완료되면 청중 화면에 표시)
        if !logoPath.isEmpty {
            uploadLogo(sessionId: sessionId, path: logoPath)
        }
        // v2.8.0: 행사용 글꼴이 지정돼 있으면 Storage에 올리고 meta.fontUrl을 채움
        if !fontPath.isEmpty {
            uploadFont(sessionId: sessionId, path: fontPath)
        }
    }

    func stopBroadcast() {
        guard active, let sid = sessionId else { active = false; return }
        active = false
        send("PATCH", "sessions/\(sessionOwnerUID)/\(sid)/meta", ["active": false])
    }

    /// 세션 데이터 전체 삭제 (RTDB에서 /sessions/{uid}/{id} 제거 → 청중 링크 무효화)
    func deleteSession(_ sessionId: String) {
        guard !sessionId.isEmpty, !authUID.isEmpty else { return }
        send("DELETE", "sessions/\(authUID)/\(sessionId)", nil)
    }

    /// 라이브 자막·음성만 삭제 (meta·QR은 유지 → 링크 살아있음)
        func clearLive(_ sessionId: String) {
            guard !sessionId.isEmpty, !authUID.isEmpty else { return }
            send("DELETE", "sessions/\(authUID)/\(sessionId)/live", nil)
            send("DELETE", "sessions/\(authUID)/\(sessionId)/audioLive", nil)
        }
    
    func updateLive(lang: String, current: String, lines: [String]) {
        guard active, sessionId != nil, !lang.isEmpty else { return }
        latest[lang] = ["current": current, "lines": lines]
        let elapsed = Date().timeIntervalSince(lastSent[lang] ?? .distantPast)
        if elapsed >= minInterval {
            flush(lang)
        } else if !scheduled.contains(lang) {
            scheduled.insert(lang)
            DispatchQueue.main.asyncAfter(deadline: .now() + (minInterval - elapsed)) { [weak self] in
                self?.scheduled.remove(lang)
                self?.flush(lang)
            }
        }
    }

    private func flush(_ lang: String) {
        guard active, let sid = sessionId, let body = latest[lang] else { return }
        lastSent[lang] = Date()
        send("PUT", "sessions/\(sessionOwnerUID)/\(sid)/live/\(lang)", body)
    }

    // MARK: - 음성 클립 업로드 (2단계)
    // WAV 클립을 Storage(audio/{sid}/{lang}/{seq}.wav)에 올리고,
    // 성공하면 RTDB /sessions/{sid}/audioLive/{lang} 에 {seq,url,ts}를 push.
    func uploadAudioClip(sessionId: String, lang: String, seq: Int, wav: Data) {
        guard !sessionId.isEmpty, !lang.isEmpty, !wav.isEmpty else { return }
        let objectPath = "audio/\(sessionId)/\(lang)/\(seq).wav"
        let enc = objectPath.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? objectPath
        withToken { token in
            guard let token else { return }
            let up = "https://firebasestorage.googleapis.com/v0/b/\(Self.storageBucket)/o?uploadType=media&name=\(enc)"
            guard let url = URL(string: up) else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Firebase \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
            req.httpBody = wav
            URLSession.shared.dataTask(with: req) { data, _, _ in
                guard let data,
                      let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                var dl = "https://firebasestorage.googleapis.com/v0/b/\(Self.storageBucket)/o/\(enc)?alt=media"
                if let dtoken = (j["downloadTokens"] as? String)?.components(separatedBy: ",").first,
                   !dtoken.isEmpty {
                    dl += "&token=\(dtoken)"
                }
                let body: [String: Any] = ["seq": seq, "url": dl, "ts": Int(Date().timeIntervalSince1970 * 1000)]
                self.send("POST", "sessions/\(self.sessionOwnerUID)/\(sessionId)/audioLive/\(lang)", body)
            }.resume()
        }
    }

    // MARK: - 행사 로고 업로드
    // 로컬 로고 파일을 Storage(audio/{sid}/logo.ext)에 올리고, 성공하면
    // meta.logoUrl을 PATCH → 청중 페이지가 행사명 왼쪽에 로고를 표시.
    // ※ 기존 Storage 규칙(/audio/**)을 그대로 쓰기 위해 audio 경로 아래에 저장.
    func uploadLogo(sessionId: String, path: String) {
        guard !sessionId.isEmpty, !path.isEmpty else { return }
        guard let imgData = try? Data(contentsOf: URL(fileURLWithPath: path)), !imgData.isEmpty else { return }

        let ext = (path as NSString).pathExtension.lowercased()
        let mime: String
        switch ext {
        case "jpg", "jpeg": mime = "image/jpeg"
        case "gif":         mime = "image/gif"
        case "heic":        mime = "image/heic"
        case "webp":        mime = "image/webp"
        default:            mime = "image/png"
        }
        let safeExt = ext.isEmpty ? "png" : ext
        let objectPath = "audio/\(sessionId)/logo.\(safeExt)"
        let enc = objectPath.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? objectPath

        withToken { token in
            guard let token else { return }
            let up = "https://firebasestorage.googleapis.com/v0/b/\(Self.storageBucket)/o?uploadType=media&name=\(enc)"
            guard let url = URL(string: up) else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Firebase \(token)", forHTTPHeaderField: "Authorization")
            req.setValue(mime, forHTTPHeaderField: "Content-Type")
            req.httpBody = imgData
            URLSession.shared.dataTask(with: req) { data, _, _ in
                guard let data,
                      let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                var dl = "https://firebasestorage.googleapis.com/v0/b/\(Self.storageBucket)/o/\(enc)?alt=media"
                if let dtoken = (j["downloadTokens"] as? String)?.components(separatedBy: ",").first,
                   !dtoken.isEmpty {
                    dl += "&token=\(dtoken)"
                }
                self.send("PATCH", "sessions/\(self.sessionOwnerUID)/\(sessionId)/meta", ["logoUrl": dl])
            }.resume()
        }
    }

    // MARK: - 행사용 글꼴 업로드 (v2.8.0)
    // 호스트가 고른 글꼴(.ttf/.otf)을 Storage(audio/{sid}/font.ext)에 올리고,
    // 성공하면 meta.fontUrl을 PATCH → 청중 sub.html이 자막에 그 글꼴을 적용.
    func uploadFont(sessionId: String, path: String) {
        guard !sessionId.isEmpty, !path.isEmpty else { return }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)), !data.isEmpty else { return }

        let ext = (path as NSString).pathExtension.lowercased()
        let mime: String
        switch ext {
        case "otf":   mime = "font/otf"
        case "ttc":   mime = "font/collection"
        case "woff":  mime = "font/woff"
        case "woff2": mime = "font/woff2"
        default:      mime = "font/ttf"
        }
        let safeExt = ext.isEmpty ? "ttf" : ext
        let objectPath = "audio/\(sessionId)/font.\(safeExt)"
        let enc = objectPath.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? objectPath

        withToken { token in
            guard let token else { return }
            let up = "https://firebasestorage.googleapis.com/v0/b/\(Self.storageBucket)/o?uploadType=media&name=\(enc)"
            guard let url = URL(string: up) else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Firebase \(token)", forHTTPHeaderField: "Authorization")
            req.setValue(mime, forHTTPHeaderField: "Content-Type")
            req.httpBody = data
            URLSession.shared.dataTask(with: req) { data, _, _ in
                guard let data,
                      let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                var dl = "https://firebasestorage.googleapis.com/v0/b/\(Self.storageBucket)/o/\(enc)?alt=media"
                if let dtoken = (j["downloadTokens"] as? String)?.components(separatedBy: ",").first,
                   !dtoken.isEmpty {
                    dl += "&token=\(dtoken)"
                }
                self.send("PATCH", "sessions/\(self.sessionOwnerUID)/\(sessionId)/meta", ["fontUrl": dl])
            }.resume()
        }
    }

    // 모든 쓰기는 유효 토큰을 받아 ?auth=...로 붙여 전송
    private func send(_ method: String, _ path: String, _ json: [String: Any]?) {
        withToken { token in
            var s = "\(Self.dbURL)/\(path).json"
            if let token { s += "?auth=\(token)" }
            guard let url = URL(string: s) else { return }
            var req = URLRequest(url: url)
            req.httpMethod = method
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let json { req.httpBody = try? JSONSerialization.data(withJSONObject: json) }
            URLSession.shared.dataTask(with: req).resume()
        }
    }
}
