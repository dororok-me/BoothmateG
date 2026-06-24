# 새 맥북에서 BoothmateG 작업 시작하기

맥북을 새로 바꿨을 때, 이 문서만 순서대로 따라 하면 앱 개발과 청중 페이지 배포를 다시 할 수 있습니다.
모든 코드는 GitHub에 백업돼 있어, 파일을 따로 USB로 옮길 필요가 없습니다.

> **핵심:** 이 프로젝트는 **두 개의 GitHub 저장소**로 나뉩니다.
> - **앱(맥 프로그램):** `github.com/dororok-me/BoothmateG`
> - **청중 웹페이지(배포용):** `github.com/dororok-me/LiveTranslate-audience`

---

## 1단계. 도구 설치 (한 번만)

1. **Xcode** — App Store에서 설치 (앱 빌드용)
2. **Firebase CLI** — 터미널에 아래 한 줄 붙여넣기 (청중 페이지 배포용)
   ```
   curl -sL https://firebase.tools | bash
   ```

## 2단계. GitHub에서 코드 받기 (clone)

터미널에서 (예: 바탕화면에 받기):
```
cd ~/Desktop
git clone https://github.com/dororok-me/BoothmateG.git
git clone https://github.com/dororok-me/LiveTranslate-audience.git
```

## 3단계. Firebase 로그인 (한 번만)

```
firebase login
```
브라우저가 열리면 `dororok@gmail.com` 계정으로 로그인.

## 4단계. 앱 빌드·실행

1. `BoothmateG/BoothmateG.xcodeproj`를 더블클릭해 Xcode로 열기
2. **⌘B**(빌드) → **⌘R**(실행)

## 5단계. 청중 페이지(sub.html) 수정·배포

- **수정할 파일:** `LiveTranslate-audience/public/sub.html` ← 청중 페이지의 **진짜 원본**
- **배포 명령:**
  ```
  cd ~/Desktop/LiveTranslate-audience
  firebase deploy --only hosting
  ```
- `✔ Deploy complete!` 가 뜨면 `https://dororokrealtimespeech.web.app` 에 반영됨

---

## 꼭 알아둘 메모

- **API 키·CLIENT_ID는 코드 안에 들어 있습니다.** (앱이 Firebase SDK 없이 REST로 동작) → `GoogleService-Info.plist` 같은 파일을 따로 챙길 필요 없음. clone만 하면 다 따라옵니다.
- **sub.html이 두 곳에 있습니다:**
  - `LiveTranslate-audience/public/sub.html` ← **배포되는 진짜 파일. 항상 여기를 기준으로 수정.**
  - `BoothmateG/public/sub.html` ← 참고용 사본. (헷갈리면 배포 레포 쪽이 정답)
- **Firebase 프로젝트:** `dororokrealtimespeech` (싱가포르 리전)
- **청중 링크 형식:** `https://dororokrealtimespeech.web.app/sub.html?u=<호스트UID>&s=<세션ID>`
- **작업 후에는 항상 `git push`** 로 GitHub에 백업하세요. 그래야 다음에 또 맥북을 바꿔도 안전합니다.

## 자주 막히는 곳

- `firebase: command not found` → 1단계 Firebase CLI 설치 다시
- 배포 시 `Not logged in` → `firebase login` 다시
- 앱 빌드 에러 → Xcode 최신 버전인지 확인 (이 프로젝트는 macOS 26.5 타깃)
