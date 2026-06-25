# BoothmateG 작업 규칙

BoothmateG는 macOS SwiftUI로 만든 실시간 통역 자막 앱입니다.
이 파일의 규칙은 **매 대화·매 작업마다 항상 적용**합니다.

## 코드 작성 규칙

1. **버전 헤더 + changelog 유지**
   - 모든 코드 파일 상단에 `Version: x.y.z` 헤더와 `Changelog:` 블록을 유지합니다.
   - 파일을 수정할 때마다 버전 번호를 **반드시 올리고**, changelog에 변경 내용을 한 줄 이상 추가합니다.
   - **버전 번호 재사용 금지** — 이전에 쓴 번호를 다시 쓰지 않습니다.

2. **기존 로직 보존**
   - 이미 잘 작동하는 로직은 건드리지 않습니다.
   - 사용자가 **명시한 부분만** 수정합니다.

3. **Append-only 원칙**
   - 기존 코드를 변경하기보다 새 코드를 **추가**하는 방식을 우선합니다.

4. **빌드 가능성 확인**
   - 수정 후 괄호 짝(`{}`, `()`, `[]`)이 맞는지 확인해 빌드 가능한 상태를 유지합니다.

## 응답 규칙

5. **답변은 항상 존댓말 한국어로** 합니다.

6. **사용자를 "교수님"이라고 부릅니다.**

---

## 프로젝트 구조 (참고)

- **진입점**: `BoothmateGApp.swift`
- **메인 화면·핵심 로직**: `ContentView.swift` (가장 활발히 수정)
- **전역 설정·영구저장**: `AppSettings.swift`
- **자막 오버레이**: `OverlayWindow.swift`, `MultiOverlayWindow.swift`, `Multiseparateoverlaycontroller.swift`, `SubtitleStore.swift`, `MultiSubtitleStore.swift`, `SubtitleWordEditor.swift`
- **STT·번역·음성 엔진**: `AudioEngine.swift`, `AudioDeviceManager.swift`, `GeminiLiveClient.swift`, `DualTranslateClient.swift`, `MultiTranslateClient.swift`, `FishAudioTTS.swift`, `TranslatedAudioPlayer.swift`, `AudioBroadcaster.swift`
- **용어집·후처리**: `GlossaryEngine.swift`, `GlossaryPairEngine.swift`, `GlossaryView.swift`, `Glossarypairview.swift`, `Geminiglossaryhelper.swift`, `Glossaryinstructionbuilder.swift`
- **UI·뷰**: `ConsoleSettingsView.swift`, `Eventinfoview.swift`, `HostLoginView.swift`, `InputSourceView.swift`, `AudienceLangView.swift`, `AudienceQRView.swift`
- **보조 기능**: `CurrencyConverter.swift`, `UnitConverter.swift`, `ReflectionLog.swift`, `TranscriptArchive.swift`, `FirebaseRelay.swift` (청중용 웹과 연동)
  - 청중용 웹(`sub.html`)은 **별도 레포 `dororok-me/LiveTranslate-audience`** 에서 관리·배포합니다(`~/LiveTranslate-audience`, Firebase Hosting → `qr.boothmate.co.kr`). 이 BoothmateG 레포에는 사본을 두지 않습니다(드리프트 방지).
