//
//  HostLoginView.swift
//  BoothmateG
//
//  Version: 1.0.0
//  호스트(송출자) 로그인 화면. Firebase Auth 이메일/비번으로 로그인하면
//  앱이 토큰으로 RTDB에 자막을 쓸 수 있다. 자격증명은 키체인에 저장돼 다음부터 자동 로그인.
//  청중은 로그인하지 않는다(읽기 전용).
//

import SwiftUI

struct HostLoginView: View {
    @ObservedObject private var relay = FirebaseRelay.shared
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("호스트 로그인").font(.title3).bold()
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }

            Text("자막을 서버로 송출하려면 호스트 계정으로 한 번 로그인하세요. 이후에는 자동으로 로그인됩니다. (청중은 로그인하지 않습니다.)")
                .font(.callout).foregroundStyle(.secondary)

            if relay.authReady {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text("로그인됨: \(relay.authEmail)").font(.callout)
                }
                Button(role: .destructive) { relay.signOut() } label: {
                    Text("로그아웃")
                }
                Spacer()
                Button { dismiss() } label: { Text("닫기").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
            } else {
                TextField("이메일", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                SecureField("비밀번호", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(login)

                if let err = relay.authError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }

                Button(action: login) {
                    Text("로그인").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty)

                Spacer()
            }
        }
        .padding(20)
        .frame(width: 380, height: 320)
        .onAppear { if email.isEmpty { email = relay.authEmail } }
    }

    private func login() {
        guard !email.isEmpty, !password.isEmpty else { return }
        relay.signIn(email: email, password: password)
    }
}
