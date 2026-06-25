//
//  ContentView.swift
//  BoothmateG
//
//  Version: 2.95.0
//  Changelog:
//    2.95.0 - [통역 지침 최우선 주입] 통역 지침(interpretGuide)을 용어집 빌더에서 분리해
//             connect(interpretGuide:)로 직접 전달 → systemInstruction "맨 앞"에 ★최우선 강력 규칙★으로 주입
//             (단일·다국어 공통, GeminiLiveClient v1.10.0 / Dual·Multi v1.4.0). 빌더 guide는 ""로 비워 중복 방지.
//             통역 지침 칸으로 번역 조각화·어순·자연스러움을 직접 제어 가능.
//    2.94.0 - 헤더 앱 버전 표기 "Ver. 1.0" → "Ver. 1.0.3".
//    2.93.0 - [환율 변환 다국어 적용] 다국어 청중 송출(relayMulti)을 glossary.normalize → polish로 통일.
//             단일 모드(relaySingle)처럼 환율 변환 포함. 다국어 모드에서 환율 변환이 안 되던 문제 해결(청중).
//    2.92.0 - 줄바꿈 보호용으로 행사정보를 GlossaryEngine에 동기화(setEventInfo). 등록 용어·직책을 한 단위로.
//    2.91.0 - 송출 시작 시 오버레이 행사용 글꼴(ov_fontFile)을 청중에게도 업로드(startBroadcast fontPath).
//    2.90.0 - 앱 시작(onAppear) 시 저장된 행사용 글꼴 재등록(CustomFont.register) — 오버레이 커스텀 글꼴 유지.
//    2.89.0 - 우측 하단 로그인 표시 형식을 "'{이메일}'으로 로그인됨"으로 변경(이메일을 작은따옴표로 강조).
//    2.88.0 - 하단 "호스트"/"로그인" 버튼을 우측 하단으로 이동 + 로그인 시 "{이메일}으로 로그인 됨" 표시
//             (로그인된 계정을 한눈에 확인. 클릭 시 로그인/로그아웃 창은 그대로). 멀티유저 대비.
//    2.87.0 - 상단 라벨 "번역 언어" → "번역 언어 선택", 언어 선택 버튼의 "변경" 표기 → "리스트"로 변경(빈 상태는 "선택" 유지).
//    2.86.0 - 헤더 로고 아래에 앱 버전 표기("Ver. 1.0") 추가. 로고를 VStack으로 감싸 하단에 작은 회색 텍스트로 표시.
//    2.85.0 - 행사정보 창에 중간 저장 연결(onSave). 저장 눌러도 창 유지·즉시 영구저장.
//    2.84.0 - 행사정보 영구저장 연동(onAppear에 settings.loadEventInfo, 행사정보 창 닫을 때 saveEventInfo).
//             앱 설정의 환경 가져오기 후 행사정보를 다시 로드하도록 onDataImported 콜백 연결.
//    2.83.0 - 용어집 '이 방식 사용' 토글 제거 → 용어집·통역 지침·블랙리스트를 항상 적용(단일·다국어 공통).
//    2.82.0 - [후처리 카테고리 추가] 반영 로그에 "후처리"(청록) 카테고리 신설. 후처리 엔진(GlossaryPairEngine)이
//             AI 의역을 용어집 표준표기로 강제 교체하면 그 내역(예: "가소성 → 침묵성")을 로그에 남김.
//             그동안 후처리 교체는 AI 번역 이후에 일어나 용어집 매칭(화살표)에 안 잡히던 것을 명시적으로 표시.
//    2.81.0 - [영한 반영 로그 안 뜸 수정] 용어집·행사·연사 매칭을 번역문(target)만 검사 → 원문+번역문 합쳐 검사.
//             영한 통역 시 한국어 번역의 음역이 등록값과 달라 매칭 실패하던 문제 해결.
//             (영어 원문에는 등록한 영어 이름·직책이 그대로 있으므로 원문도 함께 검사. 생략어는 원문 검사 유지.)
//    2.80.0 - [호스트 로그인 창 안 뜸 수정] showHostLogin용 .sheet 연결이 누락돼 있어, 로그인 버튼을 눌러도
//             창이 안 떴음(키체인에 자격증명이 저장된 기존 맥은 자동 로그인이라 드러나지 않던 버그).
//             .sheet(isPresented: $showHostLogin) { HostLoginView() } 추가 → 새 기기/타인 맥에서 호스트 로그인 가능.
//    2.79.0 - [반영 로그 다국어 지원] 그동안 logReflections가 단일 모드(subtitles)에서만 호출돼
//             다국어 통역 시 반영 로그가 항상 비어 있었음. multiStore.onSegmentCommitted(문장 확정 콜백)에서도
//             원문+모든 언어 번역을 합쳐 logReflections를 호출하도록 추가.
//    2.78.0 - [영어 칸 사라짐 수정] 확정 다국어 자막에서 입력=칸 언어이면 그 칸에 원문(전사)을 항상 표시.
//             기존엔 seg.targets[lang]이 비면 칸을 통째로 안 그려, 영어 입력 시 English 칸이 사라졌음.
//             이제 원문=타겟어 칸은 전사, 다른 언어 입력 시 그 칸이 번역으로 전환. (편집도 isSrc면 updateSource)
//    2.77.0 - [무지개 결정타] 다국어 자막의 LazyVStack → VStack. 스택 추적 결과 무지개의 공통 지점이
//             LazyVStack의 배치 재계산(LazySubviewPlacements.updateValue/updatePrefetchPhases/arrayDestroy)
//             이었음. 표시 줄이 15줄로 적으므로 VStack이 그 경로 자체를 없애 안정적.
//    2.76.0 - [헤더 잘림 수정] multiColumn 고정폭(520/300) 제거 → 선택 언어 박스 수만큼 헤더가
//             자연스럽게 늘어나 우측이 잘리지 않음(fixedSize). 언어 박스 줄의 가로 스크롤은 불필요해져 제거.
//    2.75.0 - [무지개 완화] 다국어 콘솔 표시 자막을 80→15줄로 축소. 입력 언어 전환(일→영 등)이나
//             조작 순간 SwiftUI 무효화(AG propagate_dirty/flushTransactions/compare)가 폭발하던 것을,
//             화면 뷰 트리를 줄여 완화. 전체 기록은 전사문에 그대로 저장됨.
//    2.74.0 - [상단 UI 동작] 언어 박스를 1줄 가로 배열로(2열 폐기, 넘치면 가로 스크롤) /
//             국기+언어명 탭 시 그 언어를 번역 언어에서 해제(removeLang) /
//             오버레이 토글은 모양 고정하고 켜짐=초록·꺼짐=회색 색으로만 구별(아이콘 변형 제거).
//    2.73.0 - [상단 UI 레이아웃 보정] 언어 박스가 폭에 따라 줄어/잘리던 것 방지(fixedSize) /
//             국기·언어명·오버레이 아이콘 크기 키움 / 언어 2개 이하 1줄·3개 이상 2열 배치(langBoxesGrid) /
//             "번역 언어"·"변경" 버튼 글자 키움 / 언어명을 네이티브 표기로(langName).
//    2.72.0 - [상단 UI 개편] 지구본 "다국어" 줄 삭제 / "선택 언어:" → "번역 언어"(+선택·변경 버튼) /
//             선택한 언어를 국기+언어명 박스로 나열하고 박스마다 오버레이 개별 토글(언어별 창 ON/OFF) /
//             음성 메뉴 삭제. flagEmoji(국기)·langOverlayBox 추가, overlayOnLangs 상태 추가.
//             (오버레이 언어별 제어는 MultiSeparateOverlayController v1.3.0)
//    2.71.0 - [CPU 폭주 해결] 마이크 RMS를 @State(lastAudioRMS)로 갱신하던 것 제거. 이 값은 화면에
//             안 쓰이는데도 초당 십수 회 전체 뷰를 재렌더시켜 CPU 100%·조작 다운을 유발했음.
//             이제 audio.lastRMS(AudioEngine v2.4.0)를 무음 타이머가 직접 읽음. onAudioRMS 콜백 제거.
//    2.70.0 - 동시 세션(번역어) 상한 4개: startMulti에서 초과 저장분은 앞 4개만 사용(과부하·다운 방지).
//             선택 UI 제한은 AudienceLangView v1.4.0.
//    2.69.0 - [통합] 단일 언어 모드 화면 숨김(#if false로 코드 보존). 상단 헤더의 단일 영역과
//             subtitleScroll의 단일 분기를 비활성화 → 화면은 다국어로 일원화. 되살리려면 #if false→#if true.
//             (단일 관련 함수/뷰는 그대로 남아 미사용 경고가 날 수 있으나 빌드엔 지장 없음)
//    2.68.0 - [통합] 화자(multiSourceLang) 개념 제거. 고른 언어가 곧 번역어(targets).
//             화자 picker 삭제 / audienceLangs에서 화자 빼던 필터 3곳 제거 / startMulti targets=audienceLangs /
//             sourceIsKorean 설정 제거(입력 자동 감지로 대체) / 공유정보 "화자:" 줄 제거·"청중 언어"→"번역어".
//             (AppSettings.multiSourceLang 프로퍼티는 connect 호환 위해 잔존, 동작상 미사용)
//    2.67.0 - [통합 3단계] 다국어 오버레이에 용어집 음역 교정 적용(청중 자막 = 메인 콘솔 일치).
//             multiOverlay.toggle 호출에 pairEngine 전달(MultiSeparateOverlayController v1.2.0).
//    2.66.0 - [통합 2단계] 입력 언어가 바뀌는 지점에 가는 회색 구분선 추가(화자 전환 시각 표시).
//             확정 세그먼트를 순회하며 이전 세그먼트와 입력 언어(detectLang)가 다르면 1px 선 삽입.
//             세로 공간을 거의 안 먹어 화면이 넓어지지 않음.
//    2.65.0 - [통합 1단계] 다국어 양방향에서 입력 언어와 같은 칸에는 용어집 교정을 적용하지 않음.
//             입력 텍스트 언어 판별(detectLang) 추가 → 한국어 입력→한국어 칸에 한영 교정이 거꾸로
//             걸려 "천궁2호"가 "SKY Pierce II"로 바뀌던 문제 해결. 입력≠칸 언어일 때만 apply.
//    2.64.0 - [다국어 용어집/정지유지] 단일에서 쓰던 용어집 후처리를 다국어에 그대로 적용.
//             (1) startMulti에서 pairEngine.update로 용어집 로드(단일 start와 동일, 빠져 있었음).
//             (2) multiSegmentRow 각 언어 칸에 pairEngine.apply(원문 대조 음역 교정) — 단일 패턴 그대로.
//             (3) 정지 후에도 다국어 자막 유지(세그먼트 남으면 multiSourceScroll, 자막 리셋 전까지).
//    2.63.0 - [다국어 양방향 검증] startMulti에서 화자 언어도 번역어(targets)에 포함.
//             각 세션은 입력을 자동 감지하므로(GeminiLiveClient sendSetup이 sourceLang을 안 씀),
//             입력=그 언어면 원문(echo), 아니면 번역. 선택한 모든 언어가 서로 양방향이 됨.
//             1303행 한 곳만 변경(화면 칸·multiStore는 targets를 따라 자동 반영).
//    2.62.0 - [한영 음역 교정] 새 방식 용어집을 코드 후처리로 연결(GlossaryPairEngine).
//             확정 자막(SegmentRow.finishedTarget)에서 원문 대조로 AI가 놓친 음역(예: Cheongung-2)을
//             표준표기(SKY Pierce II)로 교정. '이 방식 사용' ON일 때만. 진행 중 자막은 다음 단계.
//    2.61.0 - 메인 콘솔 우측에 "반영 로그" 패널 추가(폭 조절 가능, 위→아래 누적).
//             문장 확정 시 용어집(파랑)·생략어(주황)·행사(초록)·연사(보라) 반영을 색깔 박스로 표시.
//             용어집·행사·연사는 번역문에서 추정, 생략어는 원문 패턴 기준. 최근 100개. ReflectionLog.swift 신규.
//    2.60.0 - 다국어 오버레이를 언어별 독립 창으로 완전 전환(MultiSeparateOverlayController).
//             청중 언어 수만큼 단일 오버레이 창이 떠 각자 배치·위치 저장. 메뉴·호버 동작 단일과 동일.
//             다국어 시작 시 자동 표시 제거(버튼으로 켜기). 기존 MultiOverlayController 미사용.
//    2.59.0 - 상단 단일/다국어 박스 크기 동적화 + 시작 맥동 붉은색 강화.
//    2.58.0 - 블랙리스트 후처리 제거: 등록된 필러 패턴("어, " "음, " 등 쉼표·공백 포함)을
//             자막에서 글자 그대로 삭제(applyBlacklist). polish·polishForArchive·SegmentRow에
//             적용 → 콘솔·청중·오버레이·전사문 일관. "마음"·"먹음"의 "음"은 패턴이 달라 안전.
//             (AI systemInstruction 지시와 별개의 확실한 2차 제거. 필러는 줄바꿈 구분 저장)
//    2.57.6 - 단어 수정 후 자동 스크롤 멈춤 회복(편집 종료 시 스크롤 트리거).
//    2.57.5 - [치명 버그 수정] 진행 중 자막 편집을 저장 없이 닫으면 editingHold가 true로 남아
//             자동 확정이 영구 보류되며 콘솔 번역이 멈추던 문제 수정.
//    2.57.4 - 정지 시 드문 다운 방지(isStopping)·면적 제거, 환율만 유지.
//    2.57.0 - 단위·환율 자동 변환(단일 언어 모드): polish() 헬퍼로 용어집+단위+환율 통합.
//             콘솔 확정/진행 자막, 청중 송출, 전사문에 적용. 시작 시 환율 API 갱신.
//             settings.convertUnitsCurrency 토글 ON일 때만. 다국어 모드는 미적용(영한 전용).
//    2.56.2 - 메인 콘솔 정리: '용어집'(구버전) 버튼 숨김(#if false로 코드 보존, 되살리기 대비).
//             '용어집2' → '글로서리 & 통역 세팅'으로 명칭 변경.
//    2.56.1 - 행사 정보 버튼/시트 추가: 하단 1줄 '용어집2' 옆에 '행사 정보' 버튼.
//             showEventInfo 토글 + EventInfoView 시트 연결.
//    2.56.0 - 행사 정보 기능 추가: @State eventInfo + start/startMulti에서 connect()에 eventInfo 전달.
//             GeminiLiveClient v1.7.0 + GlossaryEngine v1.4.0 + Dual/MultiTranslateClient v1.3.0과 통합.
//             EventInfoView로 행사명/장소/일시/참석자 입력. 번역 시 행사 용어 자동 강제 적용.
//    2.55.3 - 통역 지침·블랙리스트를 systemInstruction 빌더에 전달(단일·다국어).
//    2.55.2 - 다국어 모드(multiClient)에도 용어집 systemInstruction 주입.
//    2.55.1 - 시작 시 용어집(새 방식)을 GlossaryInstructionBuilder로 변환해 connect에 주입(번역 단계 강제).
//    2.31.0 - 다국어 화자를 단일 소스와 분리(multiSourceLang). 헤더에 화자 선택 picker.
//    2.32.0 - 청중 송출: QR 세션 선택 + 송출 토글. 자막을 FirebaseRelay로 실시간 송출.
//    2.33.0 - 송출 버튼 문구 '송출/송출 중' → '자막 송출 시작/자막 송출 중'.
//    2.34.0 - 송출 옆에 ‘QR 보기’ 버튼 추가(선택 세션의 QR을 바로 띄움, BroadcastQRView).
//    2.35.0 - 청중 송출 텍스트에도 용어집 적용(relaySingle/relayMulti에 glossary.normalize).
//             콘솔·오버레이·청중이 동일한 용어로 통일됨.
//    2.36.0 - 음성 입력 없을 때 자동 중지 기능(setupAudioTimeout/stopAudioTimeout).
//             AudioEngine.onAudioRMS로 무음 감지, secondsWithoutAudio(초) 경과 시 stop/stopMulti.
//    2.37.0 - 상·하단 메뉴 순서 변경.
//             상단(단일/다국어): 시작 · 오버레이 · 음성지원 · 자막리셋 · 카운터.
//             하단 1줄: 앱 설정 · 입력 소스 · 용어집. 하단 2줄: 청중 QR · 세션 자막 선택 ·
//             QR 보기 · 호스트 · 자막 송출 시작 · 자막 리셋.
//    2.38.0 - 다국어 전사문 자동 저장 개선: 모든 청중 언어 포함, 언어 코드→라벨 표시,
//             화자/청중 언어 헤더 추가, 용어집 normalize 적용. (stopMulti의 autoSave로 자동 .txt 저장)
//    2.39.0 - 전사문이 헤더만 저장되던 문제 수정: 정지 직전 finalizeTurn으로 진행 중 자막 확정 +
//             transcriptText가 미확정 current* 내용도 출력. 내용 없으면 빈 파일 저장 안 함.
//    2.40.0 - 상단 음성 버튼 라벨 통일: 단일 언어 '음성지원' → '음성' (다국어와 동일하게).
//    2.41.0 - 단일 음성 버튼 스타일을 다국어 음성 메뉴와 동일하게(.borderless + .fixedSize) 통일.
//    2.42.0 - 중지(stop/stopMulti) 시 오버레이 창도 함께 닫기(overlayController/multiOverlay.hide()).
//             단일·다국어 음성 버튼 아이콘 크기 통일(.imageScale(.small)).
//    2.44.0 - 메인 콘솔의 진행 중 자막 수정 시트 완전 제거(잘못 들어간 v2.43 되돌림).
//             메인 콘솔 진행 중 자막은 탭해도 아무 창도 뜨지 않음. 오버레이 창 편집은 OverlayWindow에서 처리.
//    2.45.0 - 메인 콘솔 진행 중(회색) 번역 자막도 단어 더블클릭으로 바로 수정(확정 자막과 동일).
//             더블클릭 순간 내부 확정(글자 튐 없음), 수정 시 청중 송출도 갱신.
//             (EditableSubtitleText.onBeginEdit + SubtitleStore.commitCurrentForEditing 사용)
//    2.46.0 - 진행 중 자막 더블클릭 시 수정창이 즉시 닫히던 문제 수정.
//             더블클릭 시점에 확정하지 않고 텍스트만 고정(frozenCurrentText) → 뷰 유지 → 팝오버 안 닫힘.
//             확정은 저장(onCommit) 시점에 수행.
//    2.47.0 - 다국어 메인 콘솔 표시 형식 변경: 원문 + 각 언어 번역(KR/JP/CH...)을 함께 표시.
//             각 언어 줄의 단어를 더블클릭하면 단일 언어와 동일하게 바로 수정(확정/진행 중 모두).
//             진행 중 자막은 더블클릭 시 내용 고정(frozenMulti*) → 저장 시 확정.
//             (MultiSubtitleStore.updateTarget/commitCurrentForEditing 필요)
//    2.48.0 - 다국어 문장 확정 기준을 한국어로 설정(startMulti에서 sourceIsKorean 전달).
//             다국어 콘솔이 한국어 문장 단위로 끊겨 누적되지 않음.
//    2.49.0 - Fish Audio TTS 연결: 지정 언어 1개만 Fish 음성, 나머지는 Gemini.
//             Fish 언어는 Gemini 음성을 청중 송출에서 제외하고, 자막 텍스트를 Fish로 보내 클립 생성.
//    2.50.0 - Fish 호출을 turnComplete 대신 '문장 확정 콜백'(onSegmentCommitted)으로 변경.
//             Gemini가 turnComplete를 거의 안 보내 Fish가 호출 안 되던 문제 수정. 진단 로그 추가.
//    2.51.0 - 자동 중지 무음 판정 RMS 기준 500→50. 외부 오디오 인터페이스의 낮은 입력 레벨에서
//             발화 중에도 무음으로 오판해 중지되던 문제 수정.
//    2.52.0 - 정지 시 크래시 방지: 정지 시작 시 Fish 콜백(onSegmentCommitted) 먼저 차단,
//             Fish 합성 콜백은 메인에서 active 재확인 후에만 업로드(정지 후 늦은 도착 무시).
//
//    2.53.0 - 정지 시 다운(5분+ 누적 후) 대응: 전사문 파일 저장을 백그라운드로(메인 멈춤 방지),
//             콘솔은 최근 80개 세그먼트만 렌더(자막 누적 시 렌더 부하/스크롤 끊김 완화). 생성시간 로그.
//
//    2.55.0 - 새 방식(번역쌍 매칭) 용어집 버튼/시트 추가(GlossaryPairView). UI 뼈대만(로직 미연결).
//    2.54.0 - 수정 창 중복 해결: 수정 중(editingHold)에는 문장 자동 확정을 보류해
//             수정하던 진행 자막이 segments로 넘어가 중복 표시되던 문제 수정. 엔터 시 확정 재개.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var settings = AppSettings()
    @StateObject private var subtitles = SubtitleStore()
    @StateObject private var multiStore = MultiSubtitleStore()

    @State private var audio = AudioEngine()
    @State private var client = DualTranslateClient()
    @State private var multiClient = MultiTranslateClient()
    @State private var glossary = GlossaryEngine()
    // v2.62.0: 새 방식 용어집(번역쌍·유사어) 코드 후처리 엔진. AI가 놓친 음역을 표준표기로 교정.
    @State private var pairEngine = GlossaryPairEngine()
    @State private var audioPlayer = TranslatedAudioPlayer()
    // v2.57.0: 단위·환율 변환(단일 언어 모드). 환율은 앱 시작 시 API로 갱신.
    @StateObject private var currencyConverter = CurrencyConverter()
    // v2.57.4: 정지 진행 중 표시. 정지 직후 잔여 화면 갱신에서 환율 변환을 건너뛰어
    //          @MainActor 변환과 정지 정리 작업이 겹치며 나는 드문 다운을 방지.
    @State private var isStopping = false
    @ObservedObject private var relay = FirebaseRelay.shared
    @State private var audioBroadcaster = AudioBroadcaster()
    @State private var showHostLogin = false
    
    @State private var overlayController = OverlayWindowController()
    @State private var multiOverlay = MultiSeparateOverlayController()   // v2.60.0: 언어별 독립 창
    // v2.72.0: 언어별 오버레이가 켜져 있는지 UI 추적용(헤더 박스 토글 표시).
    @State private var overlayOnLangs: Set<String> = []

    // v2.61.0: 반영 로그(콘솔 우측 패널) — 용어집·생략어·행사·연사 반영 내역
    @StateObject private var reflectionLog = ReflectionLogStore()
    @AppStorage("reflog_show")  private var reflogShow: Bool = true     // 패널 표시 여부
    @AppStorage("reflog_width") private var reflogWidth: Double = 260   // 패널 폭(드래그 조절)
    
    // v2.36.0 추가: 음성 입력 자동 중지
    @State private var audioTimeoutTimer: Timer?
    @State private var audioSilenceTime: Double = 0
    // v2.71.0: lastAudioRMS @State 제거 — RMS는 audio.lastRMS로 읽음(전체 뷰 재렌더 폭주 차단)


    @State private var isRunning: Bool = false
    @State private var isMultiRunning: Bool = false
    @State private var statusMessage: String = "대기 중"
    @State private var showGlossary: Bool = false
    // v2.55.0: 새 방식(번역쌍) 용어집 창
    @State private var showGlossaryPair: Bool = false
    @State private var showSettings: Bool = false
    @State private var showInputSource: Bool = false
    @State private var showAudienceLangs: Bool = false
    @State private var showAudienceQR: Bool = false
    
    // v2.56.0: 행사 정보 상태
    @State private var eventInfo = EventInfo()
    @State private var showEventInfo: Bool = false

    @State private var isEditing: Bool = false
    @State private var frozenCurrentText: String? = nil  // v2.46.0: 편집 중 진행 자막 고정 스냅샷(단일)
    @State private var frozenMultiText: [String: String]? = nil  // v2.47.0: 다국어 진행 자막 번역 고정
    @State private var frozenMultiSource: String? = nil          // v2.47.0: 다국어 진행 자막 원문 고정
    @State private var currentInputName: String = ""
    @State private var audienceLangs: [String] = []

    // 청중 송출
    @AppStorage("audienceQREventJSON") private var audienceQREventJSON: String = ""
    @State private var broadcastSessionId: String = ""
    @State private var broadcasting: Bool = false
    @State private var showBroadcastQR: Bool = false

    @State private var sessionStart: Date? = nil
    @State private var multiSessionStart: Date? = nil

    @AppStorage("console_targetFont") private var targetFont: Double = 18
    @AppStorage("console_sourceFont") private var sourceFont: Double = 14
    @AppStorage("console_night")      private var night: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerArea
            Divider()
            // v2.61.0: 자막(왼쪽) + 반영 로그 패널(오른쪽, 폭 조절 가능)
            HStack(spacing: 0) {
                subtitleScroll
                    .frame(maxWidth: .infinity)
                if reflogShow {
                    reflogDragHandle
                    reflectionPanel
                        .frame(width: reflogWidth)
                } else {
                    // 패널 숨김 상태: 얇은 세로 버튼으로 다시 열기
                    Button { reflogShow = true } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "checklist").font(.caption2)
                            Text("로그").font(.system(size: 9))
                        }
                        .foregroundStyle(.secondary)
                        .frame(width: 22)
                        .frame(maxHeight: .infinity)
                        .background(Color.gray.opacity(0.12))
                    }
                    .buttonStyle(.plain)
                    .help("반영 로그 패널 열기")
                }
            }
            Divider()
            inputSourceBar
        }
        .padding(20)
        .frame(minWidth: 1000, minHeight: 540)
        .background(consoleBackground)
        .preferredColorScheme(night ? .dark : nil)
        .onAppear {
            glossary.update(items: settings.loadGlossary())
            refreshInputName()
            migrateLanguageCodes()
            // v2.71.0: onAudioRMS 콜백 제거 — RMS는 audio.lastRMS로 직접 읽음(@State 재렌더 폭주 차단)
            audienceLangs = settings.loadAudienceLangs()   // v2.68.0: [통합] 화자 제외 필터 폐기
            multiStore.setLanguages(audienceLangs)
            eventInfo = settings.loadEventInfo()   // v2.84.0: 행사정보 영구저장본 불러오기
            // v2.90.0: 저장된 행사용 글꼴 재등록(런타임 등록은 앱 재시작 시 사라지므로)
            CustomFont.register(path: UserDefaults.standard.string(forKey: "ov_fontFile") ?? "")
            glossary.setEventInfo(eventInfo)   // v2.92.0: 줄바꿈 보호 구절용 행사정보 동기화
        }
        .onChange(of: eventInfo) { _, ev in glossary.setEventInfo(ev) }   // v2.92.0
        .onChange(of: settings.playTranslatedAudio) { _, on in
            if on && isRunning { audioPlayer.start() } else { audioPlayer.stop() }
        }
        .onChange(of: settings.multiAudioLang) { _, lang in
            guard isMultiRunning else { return }
            if lang.isEmpty { audioPlayer.stop() } else { audioPlayer.start() }
        }
        .sheet(isPresented: $showGlossary) {
            GlossaryView(settings: settings) { items in glossary.update(items: items) }
        }
        // v2.55.0: 새 방식(번역쌍) 용어집 시트 (로직은 다음 단계에서 연결)
        .sheet(isPresented: $showGlossaryPair) {
            GlossaryPairView(settings: settings) { pairs in
                settings.saveGlossaryPairs(pairs)
            }
        }
        // v2.56.0: 행사 정보 시트
        .sheet(isPresented: $showEventInfo, onDismiss: { settings.saveEventInfo(eventInfo) }) {
            EventInfoView(eventInfo: $eventInfo, onSave: { settings.saveEventInfo(eventInfo) })
        }
        .sheet(isPresented: $showSettings) {
            ConsoleSettingsView(settings: settings,
                                onExportTranscript: { exportCurrentTranscript() },
                                onDataImported: { eventInfo = settings.loadEventInfo() })
        }
        .sheet(isPresented: $showInputSource) {
            InputSourceView { dev in
                currentInputName = dev.name
                if isRunning || isMultiRunning { restartAudio() }
            }
        }
        .sheet(isPresented: $showAudienceLangs) {
            AudienceLangView(settings: settings) { langs in
                audienceLangs = langs   // v2.68.0: [통합] 화자 제외 필터 폐기
                multiStore.setLanguages(audienceLangs)
            }
        }
        .sheet(isPresented: $showAudienceQR) {
            AudienceQRView()
        }
        .sheet(isPresented: $showBroadcastQR) {
            BroadcastQRView(sessionId: broadcastSessionId)

        }
        // v2.80.0: 호스트 로그인 시트 연결 누락 수정. showHostLogin이 true가 돼도 이 .sheet가 없어
        //   로그인 창이 안 떴음(키체인에 자격증명이 있던 기존 맥은 자동 로그인이라 드러나지 않던 버그).
        //   새 기기/타인 맥 배포 시 호스트 로그인이 가능해짐.
        .sheet(isPresented: $showHostLogin) {
            HostLoginView()
        }
    }

    // ═══════════════ 헤더 ═══════════════
    private var headerArea: some View {
        HStack(alignment: .center, spacing: 14) {
            // v2.86.0: 로고 + 그 아래 앱 버전 표기
            VStack(spacing: 4) {
                Image("BoothmateG_logo_512")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text("Ver. 1.0.3")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 80)
            // v2.69.0: [통합] 단일 모드 화면 숨김(코드 보존). 되살리려면 #if false → #if true
            #if false
            singleColumn
                .frame(width: isRunning ? 520 : 300, alignment: .topLeading)
                .padding(10)
                .background(ActivePulseBox(active: isRunning))
                .animation(.easeInOut(duration: 0.35), value: isRunning)
            Divider().frame(height: 80)
            #endif
            multiColumn
                // v2.76.0: 고정폭(520/300) 제거 → 선택 언어 박스 수만큼 자연스럽게 늘어남(우측 잘림 방지).
                .fixedSize(horizontal: true, vertical: false)
                .padding(10)
                .background(ActivePulseBox(active: isMultiRunning))
                .animation(.easeInOut(duration: 0.35), value: isMultiRunning)
            Spacer()
        }
    }

    // 모니터(오버레이) 토글 버튼 — 켜짐=색 채움, 꺼짐=회색
    private func overlayToggleButton(isOn: Bool, color: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "display")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isOn ? .white : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isOn ? color : Color.gray.opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isOn ? color : Color.gray.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help + (isOn ? " (켜짐)" : " (꺼짐)"))
    }

    // ── 왼쪽: 단일 언어 ──
    private var singleColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("단일 언어").font(.caption.bold()).foregroundStyle(.secondary)

            HStack(spacing: 6) {
                compactLangPicker($settings.sourceLang)
                Button { swapLanguages() } label: {
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .disabled(isRunning || isMultiRunning)
                compactLangPicker($settings.targetLang)
            }

            HStack(spacing: 6) {
                Button {
                    if isRunning { stop() } else { start() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isRunning ? "stop.fill" : "play.fill")
                        Text(isRunning ? "정지" : "시작")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isRunning ? .red : .green)
                .frame(width: 92)
                .disabled(isMultiRunning)

                // v2.37.0: 순서 변경 — 시작 · 오버레이 · 음성지원 · 자막리셋 · 카운터
                overlayToggleButton(isOn: overlayController.isVisible, color: .green, help: "오버레이") {
                    overlayController.toggle(store: subtitles, glossary: glossary, mainWindow: NSApp.keyWindow, displayPolish: { polish($0) })
                }

                audioSupportButton

                resetButton(disabled: subtitles.segments.isEmpty && subtitles.currentSource.isEmpty) {
                    subtitles.clear()
                }

                timerLabel(sessionStart)
            }
        }
    }

    // 모니터 아이콘 옆 '음성' 토글 버튼 (설정 안 들어가도 바로 전환)
    // 켜짐=파랑, 꺼짐=회색. 켜진 상태로 번역 중이면 '음성 지원 중' 깜빡임.
    // v2.41.0: 다국어 음성 메뉴와 동일한 테두리 없는 스타일·크기로 통일.
    private var audioSupportButton: some View {
        Button {
            settings.playTranslatedAudio.toggle()
        } label: {
            if settings.playTranslatedAudio && isRunning {
                AudioSupportBadge()
            } else {
                HStack(spacing: 3) {
                    Image(systemName: settings.playTranslatedAudio ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    Text("음성")
                }
                .font(.caption)
                .imageScale(.small)
            }
        }
        .buttonStyle(.borderless)
        .fixedSize()
        .tint(settings.playTranslatedAudio ? .blue : .gray)
        .disabled(isMultiRunning)
        .help("번역 음성 재생 켜기/끄기")
    }

    // ── 오른쪽: 다국어 (v2.73.0 UI 개편) ──
    //  지구본 "다국어" 줄 삭제 / "선택 언어" → "번역 언어" / 선택 언어를 국기 박스로 나열(폭에 따라 줄지 않음) +
    //  박스마다 오버레이 개별 토글 / 음성 메뉴 삭제 / 2개 이하 1줄·3개 이상 2열.
    private var multiColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 줄1: 번역 언어 라벨 + 선택/변경 버튼
            HStack(spacing: 8) {
                Text("번역 언어 선택").font(.headline).foregroundStyle(.secondary)
                Button { showAudienceLangs = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text(audienceLangs.isEmpty ? "선택" : "리스트")
                    }
                    .font(.callout)
                }
                .buttonStyle(.bordered)
                .disabled(isRunning || isMultiRunning)
            }

            // 줄2: 시작/정지 · 자막리셋 · 타이머
            HStack(spacing: 8) {
                Button {
                    if isMultiRunning { stopMulti() } else { startMulti() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isMultiRunning ? "stop.fill" : "play.fill")
                        Text(isMultiRunning ? "정지" : "시작")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isMultiRunning ? .red : .blue)
                .frame(width: 92)
                .disabled(audienceLangs.isEmpty || isRunning)

                resetButton(disabled: multiStore.segments.isEmpty && multiStore.currentSource.isEmpty) {
                    multiStore.clear()
                }

                timerLabel(multiSessionStart)
            }

            // 줄3+: 선택 언어 박스 (2개 이하 1줄, 3개 이상 2열). 폭에 따라 줄어들지 않음.
            if audienceLangs.isEmpty {
                Text("언어를 선택하세요").font(.callout).foregroundStyle(.secondary)
            } else {
                langBoxesGrid
            }
        }
    }

    // v2.76.0: 언어 박스 1줄 가로 배열. 헤더 고정폭을 없앴으므로 박스 수만큼 자연스럽게 늘어남.
    @ViewBuilder
    private var langBoxesGrid: some View {
        HStack(spacing: 8) {
            ForEach(audienceLangs, id: \.self) { langOverlayBox($0) }
        }
    }

    // v2.73.0: 박스에 표시할 언어명(네이티브 표기). 매핑에 없으면 langShort 폴백.
    private func langName(_ code: String) -> String {
        let map: [String: String] = [
            "ko":"한국어", "en":"English", "ja":"日本語",
            "zh-Hans":"简体中文", "zh-Hant":"繁體中文",
            "fr":"Français", "de":"Deutsch", "es":"Español", "it":"Italiano",
            "pt-BR":"Português", "pt-PT":"Português", "ru":"Русский",
            "ar":"العربية", "hi":"हिन्दी", "th":"ไทย", "vi":"Tiếng Việt",
            "id":"Indonesia", "ms":"Melayu", "tr":"Türkçe", "pl":"Polski",
            "nl":"Nederlands", "sv":"Svenska", "uk":"Українська", "vi-VN":"Tiếng Việt"
        ]
        return map[code] ?? langShort(code)
    }

    // v2.74.0: 박스의 언어명을 탭하면 그 언어를 번역 언어에서 해제(토글 끄듯 박스 사라짐).
    //  통역 중에는 변경 금지(시작 전에만). 그 언어 오버레이가 떠 있으면 함께 닫는다.
    private func removeLang(_ code: String) {
        guard !isRunning, !isMultiRunning else { return }
        var langs = audienceLangs
        langs.removeAll { $0 == code }
        audienceLangs = langs
        settings.saveAudienceLangs(langs)
        multiStore.setLanguages(langs)
        if overlayOnLangs.contains(code) {
            multiOverlay.hideLang(code)
            overlayOnLangs.remove(code)
        }
    }

    // v2.74.0: 언어 1개 박스 [국기 언어명(탭=해제) | 오버레이토글(색으로 on/off)].
    //  - 국기+언어명 탭: 번역 언어에서 해제(removeLang)
    //  - 오버레이 버튼: 모양 고정("display"), 켜짐=초록/꺼짐=회색 색으로만 구별
    @ViewBuilder
    private func langOverlayBox(_ code: String) -> some View {
        let isOn = overlayOnLangs.contains(code)
        HStack(spacing: 8) {
            // 국기 + 언어명 — 탭하면 번역 언어에서 해제
            HStack(spacing: 8) {
                Text(flagEmoji(code)).font(.system(size: 18))
                Text(langName(code))
                    .font(.body)
                    .fixedSize()                 // 글자가 폭에 따라 줄거나 잘리지 않게
            }
            .contentShape(Rectangle())
            .onTapGesture { removeLang(code) }
            .help("탭하면 번역 언어에서 제외")

            // 오버레이 토글 — 모양은 고정, 켜짐=초록 / 꺼짐=회색 (색으로만 구별)
            Button {
                if multiStore.langs.isEmpty { multiStore.setLanguages(audienceLangs) }
                multiOverlay.toggleLang(code, store: multiStore, glossary: glossary,
                                        pairEngine: pairEngine, mainWindow: NSApp.keyWindow,
                                        displayPolish: { polish($0) })   // v2.93.0: 다국어 오버레이도 환율 변환
                if multiOverlay.isVisible(lang: code) { overlayOnLangs.insert(code) }
                else { overlayOnLangs.remove(code) }
            } label: {
                Image(systemName: "display")          // 모양 고정(변하지 않음)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isOn ? .white : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isOn ? Color.green : Color.gray.opacity(0.16))
                    )
            }
            .buttonStyle(.plain)
            .help(langName(code) + " 오버레이 " + (isOn ? "켜짐" : "꺼짐"))
        }
        .fixedSize(horizontal: true, vertical: false)   // 박스 전체가 폭에 따라 압축되지 않게
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }

    // v2.72.0: 언어 코드(BCP-47) → 국기 이모지. 매핑에 없으면 🌐.
    //  (영어는 미국기 기준. 다른 깃발을 원하면 아래 map에서 바꾸면 됨.)
    private func flagEmoji(_ langCode: String) -> String {
        let map: [String: String] = [
            "ko":"KR", "en":"US", "ja":"JP", "zh-Hans":"CN", "zh-Hant":"TW",
            "fr":"FR", "de":"DE", "es":"ES", "it":"IT", "pt-BR":"BR", "pt-PT":"PT",
            "ru":"RU", "ar":"SA", "hi":"IN", "th":"TH", "vi":"VN", "id":"ID",
            "ms":"MY", "tr":"TR", "pl":"PL", "nl":"NL", "sv":"SE", "da":"DK",
            "no":"NO", "fi":"FI", "el":"GR", "cs":"CZ", "uk":"UA", "he":"IL",
            "fa":"IR", "ro":"RO", "hu":"HU", "bg":"BG", "hr":"HR", "sk":"SK",
            "sl":"SI", "sr":"RS", "fil":"PH", "bn":"BD", "ur":"PK", "sw":"KE",
            "am":"ET", "my":"MM", "km":"KH", "lo":"LA", "ne":"NP", "si":"LK",
            "ka":"GE", "hy":"AM", "az":"AZ", "kk":"KZ", "uz":"UZ", "mn":"MN",
            "sq":"AL", "mk":"MK", "be":"BY", "et":"EE", "lv":"LV", "lt":"LT",
            "is":"IS", "af":"ZA", "zu":"ZA", "ha":"NG", "rw":"RW", "su":"ID",
            "jv":"ID", "sd":"PK", "ta":"IN", "te":"IN", "mr":"IN", "gu":"IN",
            "kn":"IN", "ml":"IN", "pa":"IN", "ca":"ES", "eu":"ES", "gl":"ES"
        ]
        guard let country = map[langCode] else { return "🌐" }
        let base: UInt32 = 0x1F1E6   // regional indicator 'A'
        var s = ""
        for scalar in country.unicodeScalars {
            if let u = UnicodeScalar(base + (scalar.value - 65)) {
                s.unicodeScalars.append(u)
            }
        }
        return s.isEmpty ? "🌐" : s
    }

    // ── 맨 오른쪽: 전역 메뉴 ── (v2.25.0: 하단 입력 소스 줄로 이동, 제거됨)

    // 다국어 모드 음성: 청중 언어 중 하나만 골라 그 음성만 재생 (v2.28.0)
    private var multiAudioMenu: some View {
        Menu {
            Button("음성 끄기") { settings.multiAudioLang = "" }
            ForEach(audienceLangs, id: \.self) { code in
                Button(langShort(code)) { settings.multiAudioLang = code }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: multiAudioActive ? "speaker.wave.2.fill" : "speaker.slash.fill")
                Text(multiAudioActive ? langShort(settings.multiAudioLang) : "음성")
            }
            .font(.caption)
            .imageScale(.small)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .tint(multiAudioActive ? .blue : .gray)
        .disabled(audienceLangs.isEmpty)
        .help("재생할 번역 음성 언어 선택 (한 언어만)")
    }

    // 선택된 음성 언어가 현재 청중 언어 목록에 실제로 있는지
    private var multiAudioActive: Bool {
        !settings.multiAudioLang.isEmpty && audienceLangs.contains(settings.multiAudioLang)
    }

    // 언어 코드 → 짧은 표기
    private func langShort(_ code: String) -> String {
        supportedLanguages.first { $0.id == code }.map { String($0.label.prefix(6)) } ?? code
    }

    // v2.65.0: 입력 텍스트의 주 언어 코드 추정. 입력 언어와 같은 칸에는 용어집 교정을 건너뛰기 위함
    //          (한국어 입력→한국어 칸에 한영 교정이 거꾸로 걸려 천궁2호→SKY Pierce II 되던 문제 방지).
    private func detectLang(_ text: String) -> String {
        for ch in text.unicodeScalars {
            if (0xAC00...0xD7A3).contains(ch.value) { return "ko" }   // 한글
            if (0x3040...0x30FF).contains(ch.value) { return "ja" }   // 히라가나/가타카나
        }
        for ch in text.unicodeScalars {
            if (0x4E00...0x9FFF).contains(ch.value) { return "zh" }   // CJK 한자(가나 없으면 중국어로 추정)
        }
        return "en"
    }

    // v2.65.0: 입력 언어와 표시 칸 언어가 같은 언어인지(중국어 간/번체는 같은 언어로 취급).
    private func isSourceLang(_ srcLang: String, _ lang: String) -> Bool {
        srcLang == lang || (srcLang == "zh" && lang.hasPrefix("zh"))
    }

    // 경과 타이머 (줄바꿈 방지: fixedSize). start가 nil이면 00:00:00 회색.
    private func timerLabel(_ start: Date?) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let e = start.map { max(0, context.date.timeIntervalSince($0)) } ?? 0
            Text(formatElapsed(e))
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(start != nil ? .primary : .secondary)
        }
    }

    // '자막리셋' 버튼 (텍스트형)
    private func resetButton(disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("자막리셋").font(.caption)
        }
        .buttonStyle(.bordered)
        .disabled(disabled)
        .help("자막 리셋")
    }

    private var sourceShort: String {
        let label = supportedLanguages.first { $0.id == settings.sourceLang }?.label ?? settings.sourceLang
        return String(label.prefix(12))
    }

    private var audienceTagList: String {
        audienceLangs.map { code in
            supportedLanguages.first { $0.id == code }.map { String($0.label.prefix(6)) } ?? code
        }.joined(separator: ", ")
    }

    private func compactLangPicker(_ selection: Binding<String>) -> some View {
        Picker("", selection: selection) {
            ForEach(supportedLanguages) { lang in
                Text(lang.label).tag(lang.id)
            }
        }
        .labelsHidden()
        .frame(width: 130)
        .disabled(isRunning || isMultiRunning)
    }

    private func formatElapsed(_ t: TimeInterval) -> String {
        let total = Int(t)
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    // ═══════════════ 콘솔 자막 ═══════════════
    @ViewBuilder
    private var subtitleScroll: some View {
        // v2.69.0: [통합] 단일 모드 숨김에 따라 자막도 다국어로 일원화(pairScroll 분기 제거).
        multiSourceScroll
    }

    // v2.61.0: 패널 폭 조절용 드래그 구분선
    private var reflogDragHandle: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.001))
            .frame(width: 8)
            .overlay(Rectangle().fill(Color.gray.opacity(0.25)).frame(width: 1))
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // 왼쪽으로 끌면 패널이 넓어지므로 부호 반전
                        let newW = reflogWidth - Double(value.translation.width)
                        reflogWidth = min(560, max(180, newW))
                    }
            )
    }

    // v2.61.0: 반영 로그 패널 — 용어집·생략어·행사·연사 반영 내역을 색깔별 박스로 나열
    private var reflectionPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "checklist").font(.caption)
                Text("반영 로그").font(.caption.bold())
                Spacer()
                if !reflectionLog.entries.isEmpty {
                    Button { reflectionLog.clear() } label: {
                        Image(systemName: "trash").font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("로그 지우기")
                }
                Button { reflogShow = false } label: {
                    Image(systemName: "xmark").font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("패널 숨기기")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(reflectionLog.entries) { entry in
                            reflectionRow(entry).id(entry.id)
                        }
                    }
                    .padding(10)
                }
                .onChange(of: reflectionLog.entries.count) { _, _ in
                    if let last = reflectionLog.entries.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            if reflectionLog.entries.isEmpty {
                Spacer()
                Text("반영된 용어·생략어·행사·연사\n정보가 여기 표시됩니다")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
            }
        }
        .background(consoleBackground.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // 로그 한 줄: 종류 색 태그 + 내용
    @ViewBuilder
    private func reflectionRow(_ entry: ReflectionEntry) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(entry.kind.label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(entry.kind.color))
            Text(entry.text)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(entry.kind.color.opacity(0.10))
        )
    }

    private var multiSourceScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // v2.77.0: LazyVStack → VStack. 표시 줄이 15줄로 적은데 LazyVStack을 쓰면
                //   자막 갱신마다 prefetch·배치 재계산·옛 배치 대량 해제(LazySubviewPlacements.updateValue,
                //   updatePrefetchPhases, arrayDestroy)가 폭발해 메인 멈춤(무지개)을 유발. 적은 줄수엔 VStack이 안정적.
                VStack(alignment: .leading, spacing: 10) {
                    // 확정된 세그먼트: 원문 + 각 언어 번역
                    // v2.75.0: 표시 줄 수 80→15. 화면 자막 줄이 많으면 입력 언어 전환·조작 순간
                    //   SwiftUI 무효화(AG propagate_dirty/flushTransactions)가 폭발해 메인 멈춤(무지개)을
                    //   유발 → 표시 줄 수 축소(전체 기록은 전사문에 저장됨).
                    // v2.66.0: 입력 언어가 바뀌는 지점에 가는 구분선(화자 전환을 시각적으로 표시).
                    let recentSegs = Array(multiStore.segments.suffix(15))
                    ForEach(Array(recentSegs.enumerated()), id: \.element.id) { idx, seg in
                        if idx > 0 && detectLang(recentSegs[idx - 1].source) != detectLang(seg.source) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.25))
                                .frame(height: 1)
                                .padding(.vertical, 2)
                        }
                        multiSegmentRow(seg)
                    }
                    // 진행 중(회색) 자막: 원문 + 각 언어 번역
                    multiCurrentRow
                }
                .padding(.vertical, 8)
            }
            .onChange(of: multiStore.currentSource) { _, _ in
                if !isEditing { proxy.scrollTo("msrc", anchor: .bottom) }
            }
            .onChange(of: multiStore.segments.count) { _, _ in
                if !isEditing { withAnimation { proxy.scrollTo("msrc", anchor: .bottom) } }
            }
            // v2.57.6: 편집 종료 시 자동 스크롤 회복(단일과 동일).
            .onChange(of: isEditing) { _, editing in
                if !editing { withAnimation { proxy.scrollTo("msrc", anchor: .bottom) } }
            }
        }
        .frame(minHeight: 260)
    }

    // 확정된 다국어 세그먼트 한 줄: 원문 + 각 언어 번역(단어 더블클릭 수정)
    @ViewBuilder
    private func multiSegmentRow(_ seg: MultiSegment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !seg.source.isEmpty {
                Text("원문: \(seg.source)")
                    .font(.system(size: CGFloat(sourceFont)))
                    .foregroundStyle(.secondary)
            }
            ForEach(multiStore.langs, id: \.self) { lang in
                // v2.78.0: 입력=칸 언어면 그 칸에 원문(전사)을 항상 표시(번역 데이터가 없어도 라벨이 사라지지 않게).
                //   입력≠칸 언어면 그 언어 번역을 표시. → 영어 입력 시 English 칸이 비어 사라지던 문제 해결.
                //   (원문=타겟어인 칸은 전사, 다른 언어가 들어오면 그 칸이 번역으로 전환된다.)
                let isSrc = isSourceLang(detectLang(seg.source), lang)
                let raw = isSrc ? seg.source : (seg.targets[lang] ?? "")
                if !raw.isEmpty {
                    let normalized = glossary.normalize(raw)
                    let base0 = isSrc ? normalized : pairEngine.apply(source: seg.source, target: normalized)
                    let displayed = withCurrency(base0)   // v2.93.0: 확정 자막에도 환율 변환
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(langShort(lang)):")
                            .font(.system(size: CGFloat(targetFont) * 0.7, weight: .semibold))
                            .foregroundStyle(.blue.opacity(0.7))
                            .padding(.top, 2)
                        EditableSubtitleText(
                            text: displayed,
                            fontSize: CGFloat(targetFont),
                            bold: false,
                            color: .primary,
                            isEditing: $isEditing,
                            onCommit: { newText in
                                if isSrc { multiStore.updateSource(id: seg.id, newText: newText) }
                                else { multiStore.updateTarget(id: seg.id, lang: lang, newText: newText) }
                                relayMulti(lang)
                            }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(6)
    }

    // 진행 중(회색) 다국어 자막: 원문 + 각 언어 번역(단어 더블클릭 수정)
    @ViewBuilder
    private var multiCurrentRow: some View {
        let hasContent = !multiStore.currentSource.isEmpty
            || multiStore.currentTargets.values.contains { !$0.isEmpty }
        if hasContent || frozenMultiText != nil {
            VStack(alignment: .leading, spacing: 4) {
                let srcShown = frozenMultiSource ?? multiStore.currentSource
                if !srcShown.isEmpty {
                    Text("원문: \(srcShown)")
                        .font(.system(size: CGFloat(sourceFont)))
                        .foregroundStyle(.secondary)
                }
                ForEach(multiStore.langs, id: \.self) { lang in
                    let live = multiStore.currentTargets[lang] ?? ""
                    let shown = (frozenMultiText?[lang]) ?? live
                    if !shown.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(langShort(lang)):")
                                .font(.system(size: CGFloat(targetFont) * 0.7, weight: .semibold))
                                .foregroundStyle(.blue.opacity(0.5))
                                .padding(.top, 2)
                            EditableSubtitleText(
                                text: polish(shown),   // v2.93.0: 다국어 표시에도 환율 변환 적용
                                fontSize: CGFloat(targetFont),
                                bold: false,
                                color: .secondary.opacity(0.7),
                                isEditing: $isEditing,
                                onCommit: { newText in
                                    if let id = multiStore.commitCurrentForEditing() {
                                        multiStore.updateTarget(id: id, lang: lang, newText: newText)
                                        relayMulti(lang)
                                    }
                                    frozenMultiText = nil
                                    frozenMultiSource = nil
                                    multiStore.editingHold = false   // v2.54.0: 확정 보류 해제
                                },
                                onBeginEdit: {
                                    // 더블클릭 순간: 확정하지 않고 현재 내용만 고정(뷰 유지 → 팝오버 안 닫힘)
                                    frozenMultiText = multiStore.currentTargets
                                    frozenMultiSource = multiStore.currentSource
                                    multiStore.editingHold = true    // v2.54.0: 수정 중 자동 확정 보류(중복 방지)
                                }
                            )
                            .italic()
                            // v2.57.5: 다국어도 동일 — 저장 없이 편집 닫아도 보류 해제(번역 멈춤 방지)
                            .onChange(of: isEditing) { _, editing in
                                if !editing {
                                    multiStore.editingHold = false
                                    frozenMultiText = nil
                                    frozenMultiSource = nil
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(6)
            .id("msrc")
        }
    }

    private var pairScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // v2.53.0: 최근 80개만 렌더(자막이 많이 쌓여도 화면이 무거워지지 않게).
                    //          전체 기록은 전사문에 저장됨.
                    ForEach(subtitles.segments.suffix(80)) { segment in segmentRow(segment) }
                    currentProgressView
                }
                .padding(.vertical, 8)
            }
            .onChange(of: subtitles.segments.count) { _, _ in
                if !isEditing { withAnimation { proxy.scrollTo("current", anchor: .bottom) } }
            }
            .onChange(of: subtitles.currentTarget) { _, _ in
                if !isEditing { proxy.scrollTo("current", anchor: .bottom) }
            }
            // v2.57.6: 단어 수정을 마쳐 편집이 끝나는 순간(isEditing=false) 자동 스크롤을 즉시 회복.
            //          여러 SegmentRow가 isEditing을 공유해 생기던 "수정 후 스크롤 멈춤" 증상 대응.
            .onChange(of: isEditing) { _, editing in
                if !editing { withAnimation { proxy.scrollTo("current", anchor: .bottom) } }
            }
        }
        .frame(minHeight: 260)
    }

    @ViewBuilder
    private func segmentRow(_ segment: SubtitleSegment) -> some View {
        SegmentRow(
            segment: segment,
            glossary: glossary,
            pairEngine: pairEngine,
            fontSize: CGFloat(targetFont),
            srcFontSize: CGFloat(sourceFont),
            isEditing: $isEditing,
            onCommitSource: { subtitles.updateSource(id: segment.id, newText: $0) },
            onCommitTarget: { subtitles.updateTarget(id: segment.id, newText: $0) },
            convert: settings.convertUnitsCurrency,
            currencyConverter: isStopping ? nil : currencyConverter,
            blacklist: settings.blacklistWords
        )
        .id(segment.id)
    }

    @ViewBuilder
    private var currentProgressView: some View {
        if !subtitles.currentSource.isEmpty || !subtitles.currentTarget.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if !subtitles.currentSource.isEmpty {
                    Text(subtitles.currentSource)
                        .font(.system(size: CGFloat(sourceFont)))
                        .foregroundStyle(.secondary)
                }
                if !subtitles.currentTarget.isEmpty || frozenCurrentText != nil {
                    // v2.46.0: 진행 중(회색) 번역 단어를 더블클릭하면 그 단어가 블록 선택된 채 바로 수정.
                    // 더블클릭 시점 텍스트를 고정(frozen)해 백그라운드 인식이 계속돼도 수정창이 흔들리지 않게 함.
                    // 확정은 저장(onCommit) 시점에 수행 → 더블클릭 직후 뷰가 사라져 팝오버가 닫히는 문제 방지.
                    EditableSubtitleText(
                        text: polish(frozenCurrentText ?? subtitles.currentTarget),
                        fontSize: CGFloat(targetFont),
                        bold: false,
                        color: .secondary.opacity(0.7),
                        isEditing: $isEditing,
                        onCommit: { newText in
                            // 저장 시점에 진행 중 자막을 확정하고 수정 내용 반영
                            if let id = subtitles.commitCurrentForEditing() {
                                subtitles.updateTarget(id: id, newText: newText)
                                relaySingle()   // 청중 송출 중이면 즉시 반영
                            }
                            frozenCurrentText = nil
                            subtitles.editingHold = false   // v2.54.0: 확정 보류 해제
                        },
                        onBeginEdit: {
                            // 더블클릭 순간: 확정하지 않고 현재 텍스트만 고정(뷰 유지 → 팝오버 안 닫힘)
                            frozenCurrentText = subtitles.currentTarget
                            subtitles.editingHold = true    // v2.54.0: 수정 중 자동 확정 보류(중복 방지)
                        }
                    )
                    .italic()
                    // v2.57.5: 진행 중 자막 편집을 저장 없이 닫아도(팝오버 외부 클릭 등)
                    //          editingHold가 true로 남아 자동 확정이 영구 보류되며 콘솔 번역이
                    //          멈추던 치명 버그 수정. 편집 종료(isEditing=false) 시 보류·고정 해제.
                    .onChange(of: isEditing) { _, editing in
                        if !editing {
                            subtitles.editingHold = false
                            frozenCurrentText = nil
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(6)
            .id("current")
        }
    }

    // ── 하단: 입력 소스 + 설정/용어집 + 청중 송출 (2줄·크게) ──
        private var inputSourceBar: some View {
            VStack(alignment: .leading, spacing: 8) {
                // 1줄: 앱 설정 · 입력 소스 · 용어집  (v2.37.0 순서 변경)
                HStack(spacing: 12) {
                    Button { showSettings = true } label: {
                        HStack(spacing: 5) { Image(systemName: "gearshape"); Text("앱 설정") }.font(.body)
                    }
                    .buttonStyle(.plain)

                    Divider().frame(height: 20)

                    Image(systemName: "mic").foregroundStyle(.secondary)
                    Button { showInputSource = true } label: {
                        HStack(spacing: 4) {
                            Text("입력 소스: \(currentInputName.isEmpty ? "기본 장치" : currentInputName)")
                            Image(systemName: "chevron.up.chevron.down").foregroundStyle(.secondary)
                        }.font(.body)
                    }
                    .buttonStyle(.plain)

                    Divider().frame(height: 20)

                    // v2.56.2: '용어집'(구버전) 버튼 숨김. 코드는 보존(나중에 되살릴 때 #if false → #if true).
                    #if false
                    Button { showGlossary = true } label: {
                        HStack(spacing: 5) { Image(systemName: "character.book.closed"); Text("용어집") }.font(.body)
                    }
                    .buttonStyle(.plain)
                    #endif

                    // v2.55.0: 새 방식(번역쌍 매칭) 용어집 버튼
                    // v2.56.2: 명칭 '용어집2' → '글로서리 & 통역 세팅'
                    Button { showGlossaryPair = true } label: {
                        HStack(spacing: 5) { Image(systemName: "character.book.closed.fill"); Text("글로서리 & 통역 세팅") }.font(.body)
                    }
                    .buttonStyle(.plain)
                    .help("새 방식: 원문어=표준표기 (예: patient=피험자). 원문 대조로 번역어를 통일")

                    // v2.56.0: 행사 정보 버튼
                    Button { showEventInfo = true } label: {
                        HStack(spacing: 5) { Image(systemName: "calendar.badge.clock"); Text("행사 정보") }.font(.body)
                    }
                    .buttonStyle(.plain)
                    .help("행사명/장소/일시/참석자(직책·이름·발표제목)를 등록. 번역 시 정확한 직책·이름으로 강제 반영")

                    Spacer()
                }
                .imageScale(.large)

                // 2줄: 청중 QR · 세션 자막 선택 · QR 보기 · (호스트) · 자막 송출 시작 · 자막 리셋  (v2.37.0 순서 변경)
                HStack(spacing: 10) {
                    Button { showAudienceQR = true } label: {
                        HStack(spacing: 4) { Image(systemName: "qrcode"); Text("청중 QR") }.font(.body)
                    }
                    .buttonStyle(.bordered).controlSize(.large)

                    Image(systemName: broadcasting ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right")
                        .font(.body).foregroundStyle(broadcasting ? .red : .secondary)
                    Picker("", selection: $broadcastSessionId) {
                        Text("세션 자막 선택").tag("")
                        ForEach(qrSessions) { s in Text(sessionLabel(s)).tag(s.id) }
                    }
                    .labelsHidden().pickerStyle(.menu).controlSize(.large).fixedSize()
                    .disabled(broadcasting)

                    Button { showBroadcastQR = true } label: {
                        HStack(spacing: 4) { Image(systemName: "qrcode.viewfinder"); Text("QR 보기") }.font(.body)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    .disabled(broadcastSessionId.isEmpty)

                    // v2.88.0: 호스트 로그인 버튼은 우측 하단(statusMessage 옆)으로 이동함

                    Button {
                        broadcasting.toggle()
                        if broadcasting { beginBroadcastIfNeeded() }
                        else { relay.stopBroadcast(); audioBroadcaster.stop(); statusMessage = "송출 중지" }
                    } label: {
                        Text(broadcasting ? "자막 송출 중" : "자막 송출 시작").font(.body)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    .tint(broadcasting ? .red : .blue)
                    .disabled(broadcastSessionId.isEmpty || !relay.authReady)

                    Button { resetSubtitles() } label: {
                        HStack(spacing: 4) { Image(systemName: "trash"); Text("자막 리셋") }.font(.body)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    .tint(.orange)
                    .disabled(broadcastSessionId.isEmpty)

                    Spacer()

                    Text(statusMessage).font(.callout).foregroundStyle(.secondary)

                    // v2.88.0: 로그인 상태를 우측 하단에 표시. 로그인 시 "{이메일}으로 로그인 됨".
                    // 클릭하면 로그인/로그아웃 창(HostLoginView)이 열림.
                    Button { showHostLogin = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: relay.authReady ? "checkmark.seal.fill" : "person.crop.circle.badge.exclamationmark")
                            Text(relay.authReady ? "'\(relay.authEmail)'으로 로그인됨" : "로그인")
                        }.font(.callout)
                    }
                    .buttonStyle(.bordered).controlSize(.large)
                    .tint(relay.authReady ? .green : .orange)
                }
            }
        }
    
    private func refreshInputName() {
        if let id = AudioDeviceManager.defaultInputDevice() {
            currentInputName = AudioDeviceManager.deviceName(id) ?? ""
        }
    }

    private func migrateLanguageCodes() {
        let ids = Set(supportedLanguages.map { $0.id })
        if !ids.contains(settings.sourceLang) { settings.sourceLang = "ko" }
        if !ids.contains(settings.targetLang) { settings.targetLang = "en" }
        if !ids.contains(settings.multiSourceLang) { settings.multiSourceLang = "ko" }
    }

    // ── 청중 송출 ──
    private var qrSessions: [QRSession] {
        guard let d = audienceQREventJSON.data(using: .utf8),
              let ev = try? JSONDecoder().decode(QREvent.self, from: d) else { return [] }
        return ev.sessions
    }
    private var currentEventLogoPath: String {
            guard let d = audienceQREventJSON.data(using: .utf8),
                  let ev = try? JSONDecoder().decode(QREvent.self, from: d) else { return "" }
            return ev.logoPath
        }
    private func sessionLabel(_ s: QRSession) -> String {
        let l = [s.date, s.name].filter { !$0.isEmpty }.joined(separator: " · ")
        return l.isEmpty ? "세션" : l
    }
    private func qrSessionInfo(_ id: String) -> (event: String, session: String)? {
        guard let d = audienceQREventJSON.data(using: .utf8),
              let ev = try? JSONDecoder().decode(QREvent.self, from: d),
              let s = ev.sessions.first(where: { $0.id == id }) else { return nil }
        return (ev.name, sessionLabel(s))
    }
    private func langLabel(_ code: String) -> String {
        supportedLanguages.first { $0.id == code }?.label ?? code
    }

    // 송출 시작 (실행 중 + 송출 ON + 세션 선택돼 있을 때만 meta 기록)
    private func resetSubtitles() {
            subtitles.clear()                      // 단일 자막 비우기
            multiStore.clear()                     // 다국어 자막 비우기
            relay.clearLive(broadcastSessionId)    // RTDB 라이브 자막·음성 삭제
            audioBroadcaster.reset()               // 진행 중 음성 버퍼 폐기
            statusMessage = "자막 초기화됨"
        }
    
    private func beginBroadcastIfNeeded() {
        guard broadcasting, !broadcastSessionId.isEmpty, (isRunning || isMultiRunning) else { return }
        guard let info = qrSessionInfo(broadcastSessionId) else {
            statusMessage = "❌ 송출할 세션을 선택하세요"; return
        }
        var langs: [String: String] = [:]
        let mode: String
        if isMultiRunning {
            mode = "multi"
            for c in audienceLangs { langs[c] = langLabel(c) }
        } else {
            mode = "single"
            langs[settings.targetLang] = langLabel(settings.targetLang)
        }
        relay.startBroadcast(sessionId: broadcastSessionId, eventName: info.event,
                                     sessionName: info.session, mode: mode, langs: langs,
                                     logoPath: currentEventLogoPath,
                                     fontPath: UserDefaults.standard.string(forKey: "ov_fontFile") ?? "")
        audioBroadcaster.start(sessionId: broadcastSessionId)
        statusMessage = "📡 청중 송출 중"
    }

    // 단일 모드 자막 후처리. 용어집 정규화 후, 토글이 켜져 있으면 환율 변환을 덧붙임.
    // v2.57.3: 면적(UnitConverter) 제거 — 한글 큰 숫자 번역(2백만 제곱미터 등) 미지원 이슈로 보류.
    //          환율(CurrencyConverter)만 유지. UnitConverter는 호출 안 함(파일은 보존).
    //          (CurrencyConverter는 @MainActor → 메인에서 호출되는 경로에서만 사용)
    // v2.58.0: 블랙리스트 후처리 제거. 등록된 패턴(예: "어, " "음, ")을 자막에서 글자 그대로 삭제.
    //          쉼표·공백까지 패턴에 포함되므로 "마음"·"먹음" 속 "음"은 매칭 안 됨(안전).
    //          줄바꿈(\n) 구분으로 저장된 필러 목록을 순회. AI 지시(systemInstruction)와 별개의 2차 안전장치.
    private func applyBlacklist(_ text: String) -> String {
        let raw = settings.blacklistWords
        guard !raw.isEmpty else { return text }
        let fillers = raw.contains("\n")
            ? raw.components(separatedBy: "\n")
            : raw.components(separatedBy: ",")   // 구버전 호환
        var out = text
        for f in fillers where !f.isEmpty {
            out = out.replacingOccurrences(of: f, with: "")
        }
        return out
    }

    private func polish(_ text: String) -> String {
        let normalized = applyBlacklist(glossary.normalize(text))
        guard settings.convertUnitsCurrency else { return normalized }
        // v2.57.4: 정지 정리 중에는 @MainActor 환율 변환을 건너뜀(겹침 다운 방지).
        if isStopping { return normalized }
        return currencyConverter.applyConversion(to: normalized)
    }

    // v2.93.0: 환율 변환만 적용(토글 ON + 정지중 아님). 다국어 확정 자막처럼 이미 정규화·후처리된
    //          텍스트에 환율만 덧붙일 때 사용. @MainActor 안전(표시는 메인 렌더 경로).
    private func withCurrency(_ text: String) -> String {
        guard settings.convertUnitsCurrency, !isStopping else { return text }
        return currencyConverter.applyConversion(to: text)
    }

    // v2.61.0: 반영 로그 수집. 문장 확정 시 호출.
    //  - 용어집(파랑): 등록된 canonical/유사어가 번역문(target)에 나타나면 추정 표시
    //  - 생략어(주황): 등록된 필러 패턴이 원문(source)에 있었으면 제거된 것으로 표시
    //  - 행사(초록): 행사명·장소가 번역문에 나타나면 추정 표시
    //  - 연사(보라): 연사 이름·직책이 번역문에 나타나면 추정 표시
    private func logReflections(source: String, target: String) {
        guard reflogShow else { return }   // 패널 꺼져 있으면 수집 안 함
        var found: [(ReflectionKind, String)] = []
        // v2.81.0: 용어집·행사·연사는 원문+번역문 양쪽에서 검사.
        //   영한일 때 한국어 번역의 음역이 등록값과 달라 매칭 실패하던 문제 해결
        //   (영어 원문에는 등록한 영어 이름·직책이 그대로 들어 있으므로 원문도 함께 검사).
        let haystack = source + " " + target

        // ── 용어집(새 방식) ──
        for pair in settings.loadGlossaryPairs() {
            let canon = pair.canonical.trimmingCharacters(in: .whitespaces)
            let src = pair.source.trimmingCharacters(in: .whitespaces)
            guard !canon.isEmpty || !src.isEmpty else { continue }
            // 번역문에 canonical 또는 source가 나타나면 반영된 것으로 추정
            if !canon.isEmpty, haystack.localizedCaseInsensitiveContains(canon) {
                let arrow = src.isEmpty ? canon : "\(src) → \(canon)"
                found.append((.glossary, arrow))
            } else if !src.isEmpty, haystack.localizedCaseInsensitiveContains(src) {
                found.append((.glossary, src))
            }
        }

        // ── 생략어(필러) ──
        let raw = settings.blacklistWords
        if !raw.isEmpty {
            let fillers = raw.contains("\n")
                ? raw.components(separatedBy: "\n")
                : raw.components(separatedBy: ",")
            for f in fillers where !f.isEmpty {
                if source.contains(f) {
                    let shown = f.trimmingCharacters(in: .whitespaces)
                    found.append((.omission, "\(shown) 생략"))
                }
            }
        }

        // ── 행사 정보 ──
        let ev = eventInfo
        for name in [ev.eventName.ko, ev.eventName.en, ev.venue.ko, ev.venue.en] {
            let n = name.trimmingCharacters(in: .whitespaces)
            guard n.count >= 2 else { continue }
            if haystack.localizedCaseInsensitiveContains(n) {
                found.append((.event, n))
            }
        }

        // ── 연사 정보 ──
        for sp in ev.speakers {
            for name in [sp.name.ko, sp.name.en, sp.position.ko, sp.position.en] {
                let n = name.trimmingCharacters(in: .whitespaces)
                guard n.count >= 2 else { continue }
                if haystack.localizedCaseInsensitiveContains(n) {
                    found.append((.speaker, n))
                }
            }
        }

        // ── 후처리 교정 (AI 의역 → 용어집 표준표기로 강제 교체된 내역) ──
        // v2.82.0: pairEngine 후처리를 적용해 실제 교체가 일어났으면 그 내역을 "후처리"로 기록.
        //   예: AI가 mutability를 "가소성"으로 의역 → 후처리가 "침묵성"으로 교체 → "가소성 → 침묵성" 표시.
        _ = pairEngine.apply(source: source, target: target)
        for c in pairEngine.lastCorrections {
            found.append((.correction, "\(c.from) → \(c.to)"))
        }

        if !found.isEmpty { reflectionLog.addMany(found) }
    }

    // v2.57.3: 전사문 저장 전용. 백그라운드 저장과 @MainActor 충돌을 피하려 환율 제외.
    //          면적(UnitConverter)도 보류로 제거 → 전사문은 용어집 정규화 + 블랙리스트만 적용.
    private func polishForArchive(_ text: String) -> String {
        return applyBlacklist(glossary.normalize(text))
    }

    private func relaySingle() {
        guard relay.active else { return }
        // 청중에게도 용어집 적용된 텍스트를 보냄 (오버레이/콘솔과 동일하게 통일)
        let lines = Array(subtitles.segments.map { polish($0.targetText) }.suffix(60))
        relay.updateLive(lang: settings.targetLang,
                         current: polish(subtitles.currentTarget),
                         lines: lines)
    }
    // 다국어 모드 자막 송출 (언어 1개)
    private func relayMulti(_ lang: String) {
        guard relay.active else { return }
        // v2.93.0: 청중에게도 단일 모드와 동일하게 polish 적용(용어집+블랙리스트+환율 변환)
        let lines = Array(multiStore.segments.compactMap { $0.targets[lang] }.map { polish($0) }.suffix(60))
        relay.updateLive(lang: lang,
                         current: polish(multiStore.currentTargets[lang] ?? ""),
                         lines: lines)
    }
    private func relayMultiAll() {
        guard relay.active else { return }
        for lang in audienceLangs { relayMulti(lang) }
    }

    // ───────────── Fish Audio TTS (v2.49.0) ─────────────
    // 특정 언어 1개만 Fish 음성으로 송출, 나머지는 Gemini. Fish는 자막(번역 텍스트)만 읽음.

    // 해당 언어가 Fish 송출 대상인지
    private func isFishLang(_ lang: String) -> Bool {
        settings.fishEnabled && !settings.fishLang.isEmpty && lang == settings.fishLang
    }

    // 확정된 번역 텍스트를 Fish TTS로 보내 음성 클립을 청중에게 송출
    // v2.50.0: turnComplete 대신 '문장 확정 콜백'에서 호출 (Gemini가 turnComplete를 거의 안 보냄)
    private func sendTextToFish(lang: String, text: String) {
        guard relay.active, settings.fishEnabled, !settings.fishApiKey.isEmpty else { return }
        let trimmed = glossary.normalize(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let config = FishAudioTTS.Config(
            apiKey: settings.fishApiKey,
            referenceId: settings.fishReferenceId,
            model: settings.fishModel,
            sampleRate: 24000
        )
        print("[BMG][Fish] 합성 요청: \(lang) \"\(trimmed.prefix(20))...\"")
        FishAudioTTS.synthesize(text: trimmed, config: config) { pcm in
            guard let pcm = pcm else { print("[BMG][Fish] 합성 실패"); return }
            // v2.52.0: 정지 후 늦게 도착한 콜백은 무시 (정지 중 pushClip 충돌 방지).
            //          콜백은 백그라운드 스레드이므로 메인에서 상태 재확인.
            DispatchQueue.main.async {
                guard self.relay.active, (self.isRunning || self.isMultiRunning) else {
                    print("[BMG][Fish] 정지됨 → 업로드 건너뜀")
                    return
                }
                print("[BMG][Fish] 합성 성공: \(pcm.count) bytes → 업로드")
                self.audioBroadcaster.pushClip(lang: lang, pcm16: pcm)
            }
        }
    }

    private func swapLanguages() {
        let s = settings.sourceLang
        settings.sourceLang = settings.targetLang
        settings.targetLang = s
        if isRunning { stop(); start() }
    }

    private func restartAudio() {
        audio.stop()
        do { try audio.start() } catch {
            statusMessage = "❌ 입력 장치 전환 실패: \(error.localizedDescription)"
        }
    }

    // ── 양방향 시작/정지 ──
    private func start() {
        if isMultiRunning { stopMulti() }
        guard !settings.geminiApiKey.isEmpty else {
            statusMessage = "❌ 설정에서 API 키를 입력하세요"; return
        }
        // v2.57.0: 단위·환율 변환이 켜져 있으면 최신 환율을 받아옴(시작 때 1회).
        if settings.convertUnitsCurrency { currencyConverter.fetchRates() }
        statusMessage = "연결 중..."

        client.onConnected = { DispatchQueue.main.async { self.statusMessage = "✅ 연결됨" } }
        // v2.50.0: 문장이 확정될 때마다 Fish 언어면 그 텍스트를 Fish로 송출
        subtitles.onSegmentCommitted = { target in
            if self.isFishLang(self.settings.targetLang) {
                self.sendTextToFish(lang: self.settings.targetLang, text: target)
            }
            // v2.61.0: 반영 로그 — 방금 확정된 원문+번역 검사
            let lastSrc = self.subtitles.segments.last?.sourceText ?? ""
            self.logReflections(source: lastSrc, target: target)
        }
        client.onInputTranscript = { t in DispatchQueue.main.async { self.subtitles.appendSource(t) } }
        client.onOutputTranscript = { t in DispatchQueue.main.async { self.subtitles.appendTarget(t); self.relaySingle() } }
        client.onAudio = { [audioPlayer] d in
                    audioPlayer.enqueue(pcm16: d)
                    // v2.49.0: Fish 대상 언어면 Gemini 음성을 청중 송출에서 제외(Fish로 대체)
                    if !self.isFishLang(self.settings.targetLang) {
                        self.audioBroadcaster.append(lang: self.settings.targetLang, pcm16: d)
                    }
                }
        client.onTurnComplete = { DispatchQueue.main.async {
            self.subtitles.finalizeTurn()
            self.relaySingle()
            // Fish 언어가 아니면 Gemini 누적분 마감 (Fish 언어는 문장 확정 콜백에서 처리)
            if !self.isFishLang(self.settings.targetLang) {
                self.audioBroadcaster.flushBoundary()
            }
        } }
        client.onError = { m in DispatchQueue.main.async { self.statusMessage = "❌ \(m)" } }
        client.onClosed = {
            DispatchQueue.main.async { if self.isRunning { self.statusMessage = "연결 종료됨" } }
        }

        audio.onAudioData = { [client] d in client.sendAudio(d) }

        // 용어집(새 방식) → systemInstruction 변환. '이 방식 사용' ON이고 등록 용어가 있으면 주입.
        // v2.83.0: '이 방식 사용' 토글 제거 → 용어집·지침·블랙리스트 항상 적용.
        // v2.95.0: 통역 지침은 빌더에 넣지 않고(guide:"") connect로 분리 전달 → systemInstruction 맨 앞 최우선 주입.
        let glossaryInstruction: String = GlossaryInstructionBuilder.build(
            pairs: settings.loadGlossaryPairs(),
            guide: "",
            blacklist: settings.blacklistWords)
        // 코드 후처리 엔진에도 같은 용어집 주입. AI가 놓친 음역을 교정.
        pairEngine.update(pairs: settings.loadGlossaryPairs())
        client.connect(apiKey: settings.geminiApiKey, langA: settings.targetLang, langB: settings.sourceLang, glossaryInstruction: glossaryInstruction, eventInfo: eventInfo, interpretGuide: settings.interpretGuide)

        do {
            try audio.start()
            isRunning = true
            sessionStart = Date()
            audioSilenceTime = 0          // v2.36.0
            setupAudioTimeout()           // v2.36.0
            if settings.playTranslatedAudio { audioPlayer.start() }
            beginBroadcastIfNeeded()
        } catch {
            statusMessage = "❌ 마이크 시작 실패: \(error.localizedDescription)"
            client.disconnect()
        }
    }

    private func stop() {
        // v2.57.4: 정지 정리 동안 환율 변환 차단(겹침 다운 방지). 끝에서 해제.
        isStopping = true
        // v2.52.0: 정지 시작 시 Fish 콜백 먼저 끊기 (finalizeTurn이 새 Fish 호출을 트리거하지 않게)
        subtitles.onSegmentCommitted = nil
        isRunning = false
        // v2.39.0: 저장 직전, 아직 확정 안 된 진행 중 자막을 강제 확정 (전사문 누락 방지)
        subtitles.finalizeTurn()
        // 내용이 있을 때만 저장 (헤더만 있는 빈 전사문 방지)
        // v2.53.0: 전사문 생성 시간 측정 + 파일 저장은 백그라운드로(메인 스레드 멈춤 방지)
        if hasAnyTranscriptContent() {
            let t0 = Date()
            let text = transcriptText(started: sessionStart)
            let dt = Date().timeIntervalSince(t0)
            print("[BMG] 전사문 생성 \(String(format: "%.2f", dt))초, \(subtitles.segments.count)개 세그먼트")
            let started = sessionStart
            DispatchQueue.global(qos: .utility).async {
                TranscriptArchive.autoSave(text, started: started)
            }
        }
        audio.stop()
        client.disconnect()
        audioPlayer.stop()
        relay.stopBroadcast()
        audioBroadcaster.stop()
        overlayController.hide()      // v2.42.0: 중지 시 오버레이 창도 닫기
        stopAudioTimeout()            // v2.36.0
        sessionStart = nil
        statusMessage = "정지됨"
        // v2.57.4: 정지 정리 완료 후 다음 런루프에 환율 변환 재개(잔여 화면 갱신 보호)
        DispatchQueue.main.async { self.isStopping = false }
    }

    // ── 다국어 시작/정지 ──
    private func startMulti() {
        if isRunning { stop() }
        guard !settings.geminiApiKey.isEmpty else {
            statusMessage = "❌ 설정에서 API 키를 입력하세요"; return
        }
        guard !audienceLangs.isEmpty else {
            statusMessage = "❌ 번역어를 먼저 선택하세요"; return
        }

        // v2.68.0: [통합] 화자 개념 제거 — 고른 언어가 곧 번역어(targets).
        //   입력 언어는 자동 감지(MultiSubtitleStore v1.7.0: 원문 문장부호로 끊음).
        // v2.70.0: 동시 세션 상한 4(과부하·다운 방지). 예전에 저장된 초과분은 앞 4개만 사용.
        var targets = audienceLangs
        if targets.count > 4 {
            print("[BMG] 번역어 \(targets.count)개 → 4개로 제한(과부하 방지)")
            targets = Array(targets.prefix(4))
            audienceLangs = targets
        }

        multiStore.setLanguages(targets)
        statusMessage = "다국어 연결 중..."

        multiClient.onConnected = {
            DispatchQueue.main.async { self.statusMessage = "✅ 다국어 연결됨 (\(self.audienceLangs.count)개)" }
        }
        // v2.50.0: 문장이 확정될 때마다 Fish 언어가 청중 언어에 있으면 그 언어 번역을 Fish로 송출
        multiStore.onSegmentCommitted = { targets in
            // v2.79.0: [반영 로그 다국어 지원] 다국어 모드에서도 문장 확정 시 반영 로그 수집.
            //   원문 + 모든 언어 번역을 합쳐 검사(용어집 canonical은 한국어, source는 영어 등 어느 칸에서든 매칭).
            let src = self.multiStore.segments.last?.source ?? ""
            let tgt = targets.values.joined(separator: " ")
            self.logReflections(source: src, target: tgt)

            // Fish TTS 송출
            guard self.settings.fishEnabled, !self.settings.fishLang.isEmpty else { return }
            let fl = self.settings.fishLang
            if self.audienceLangs.contains(fl), let t = targets[fl], !t.isEmpty {
                self.sendTextToFish(lang: fl, text: t)
            }
        }
        multiClient.onSource = { t in DispatchQueue.main.async { self.multiStore.appendSource(t) } }
        multiClient.onTarget = { lang, t in DispatchQueue.main.async { self.multiStore.appendTarget(lang, t); self.relayMulti(lang) } }
        multiClient.onAudio = { [audioPlayer] lang, d in
                    if lang == self.settings.multiAudioLang { audioPlayer.enqueue(pcm16: d) }
                    // v2.49.0: Fish 대상 언어면 Gemini 음성을 청중 송출에서 제외(Fish로 대체)
                    if !self.isFishLang(lang) {
                        self.audioBroadcaster.append(lang: lang, pcm16: d)
                    }
                }
        multiClient.onTurnComplete = { DispatchQueue.main.async {
            self.multiStore.finalizeTurn()
            self.relayMultiAll()
            self.audioBroadcaster.flushBoundary()
        } }
        multiClient.onError = { m in DispatchQueue.main.async { self.statusMessage = "❌ \(m)" } }

        audio.onAudioData = { [multiClient] d in multiClient.sendAudio(d) }

        // 용어집(새 방식) → systemInstruction. 다국어도 동일 주입(영↔한 쌍 기반, AI가 타 언어에도 참고).
        // v2.83.0: '이 방식 사용' 토글 제거 → 항상 적용.
        // v2.95.0: 통역 지침은 빌더에 넣지 않고(guide:"") connect로 분리 전달 → systemInstruction 맨 앞 최우선 주입.
        let multiGlossary: String = GlossaryInstructionBuilder.build(
            pairs: settings.loadGlossaryPairs(),
            guide: "",
            blacklist: settings.blacklistWords)
        // 다국어도 단일과 동일하게 용어집 후처리 엔진 로드(각 언어 칸에 apply 적용 위함).
        pairEngine.update(pairs: settings.loadGlossaryPairs())
        multiClient.connect(apiKey: settings.geminiApiKey, sourceLang: settings.multiSourceLang, targets: targets, glossaryInstruction: multiGlossary, eventInfo: eventInfo, interpretGuide: settings.interpretGuide)

        do {
            try audio.start()
            isMultiRunning = true
            multiSessionStart = Date()
            audioSilenceTime = 0          // v2.36.0
            setupAudioTimeout()           // v2.36.0
            if !settings.multiAudioLang.isEmpty { audioPlayer.start() }
            // v2.60.0: 분리형 오버레이는 언어 수만큼 창이 뜨므로 시작 시 자동 표시하지 않음.
            //          상단 '다국어 오버레이' 버튼으로 켠다(단일 모드와 동일한 흐름).
            beginBroadcastIfNeeded()
        } catch {
            statusMessage = "❌ 마이크 시작 실패: \(error.localizedDescription)"
            multiClient.disconnect()
        }
    }

    private func stopMulti() {
        // v2.52.0: 정지 시작 시 Fish 콜백 먼저 끊기
        multiStore.onSegmentCommitted = nil
        isMultiRunning = false
        // v2.39.0: 저장 직전, 아직 확정 안 된 진행 중 자막을 강제 확정 (전사문 누락 방지)
        multiStore.finalizeTurn()
        // 내용이 있을 때만 저장 (헤더만 있는 빈 전사문 방지)
        // v2.53.0: 전사문 생성 시간 측정 + 파일 저장은 백그라운드로
        if hasAnyTranscriptContent() {
            let t0 = Date()
            let text = transcriptText(started: multiSessionStart)
            let dt = Date().timeIntervalSince(t0)
            print("[BMG] 전사문 생성 \(String(format: "%.2f", dt))초, \(multiStore.segments.count)개 세그먼트")
            let started = multiSessionStart
            DispatchQueue.global(qos: .utility).async {
                TranscriptArchive.autoSave(text, started: started)
            }
        }
        audio.stop()
        multiClient.disconnect()
        audioPlayer.stop()
        relay.stopBroadcast()
        audioBroadcaster.stop()
        multiOverlay.hide()           // v2.42.0: 중지 시 다국어 오버레이 창도 닫기
        overlayOnLangs.removeAll()    // v2.72.0: 헤더 언어 박스 토글 표시도 함께 끔
        stopAudioTimeout()            // v2.36.0
        multiSessionStart = nil
        statusMessage = "정지됨"
    }

    // v2.36.0 추가: 음성 입력이 일정 시간 없으면 통역 자동 중지
    private func setupAudioTimeout() {
        stopAudioTimeout()  // 기존 타이머 정리
        guard settings.secondsWithoutAudio > 0 else { return }
        audioTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            guard self.isRunning || self.isMultiRunning else { return }
            // v2.51.0: 무음 판정 기준 500 → 50. 외부 오디오 인터페이스는 입력 레벨이 낮게
            //          들어와 발화 중에도 RMS가 500 미만인 경우가 많아 오작동하던 문제 수정.
            //          진짜 무음은 RMS 한 자리수~십 단위라 50이면 발화와 잘 구분됨.
            if audio.lastRMS < 50 {   // v2.71.0: @State 대신 엔진의 lastRMS 직접 읽기
                self.audioSilenceTime += 0.5
            } else {
                self.audioSilenceTime = 0
            }
            let timeout = Double(self.settings.secondsWithoutAudio)
            if self.audioSilenceTime >= timeout {
                print("[BMG] 음성 입력 없음(\(Int(timeout))초) → 통역 자동 중지")
                if self.isRunning { self.stop() }
                if self.isMultiRunning { self.stopMulti() }
                self.statusMessage = "음성 입력이 없어 자동 중지됨"
            }
        }
    }

    private func stopAudioTimeout() {
        audioTimeoutTimer?.invalidate()
        audioTimeoutTimer = nil
        audioSilenceTime = 0
    }

    // ── 전사문에 저장할 내용이 하나라도 있는지 (v2.39.0) ──
    private func hasAnyTranscriptContent() -> Bool {
        if !subtitles.segments.isEmpty { return true }
        if !subtitles.currentSource.isEmpty || !subtitles.currentTarget.isEmpty { return true }
        if !multiStore.segments.isEmpty { return true }
        if !multiStore.currentSource.isEmpty { return true }
        if multiStore.currentTargets.values.contains(where: { !$0.isEmpty }) { return true }
        return false
    }

    // ── 전사문 텍스트 생성 (v2.20.0, v2.24.0: 시작 시각 매개변수화) ──
    // 다국어 세션 내용이 있으면 다국어 형식, 아니면 단일 언어 형식으로 구성.
    // v2.39.0: 아직 확정되지 않은 진행 중 자막(current*)도 함께 출력 → 짧은 세션 누락 방지.
    private func transcriptText(started: Date?) -> String {
        var lines: [String] = []
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        lines.append("BoothmateG 전사문 — \(f.string(from: started ?? Date()))")
        lines.append(String(repeating: "─", count: 24))
        lines.append("")

        // 다국어/단일 판단: 확정된 세그먼트 또는 진행 중 내용이 있으면 그 모드로 간주
        let hasMulti = !multiStore.segments.isEmpty
            || !multiStore.currentSource.isEmpty
            || multiStore.currentTargets.values.contains { !$0.isEmpty }

        if hasMulti {
            // 이 세션에 실제로 번역문이 담긴 언어 목록 (확정 + 진행 중 모두 고려)
            var usedLangs: [String] = []
            for lang in multiStore.langs {
                let inSegments = multiStore.segments.contains { ($0.targets[lang]?.isEmpty == false) }
                let inCurrent = (multiStore.currentTargets[lang]?.isEmpty == false)
                if inSegments || inCurrent { usedLangs.append(lang) }
            }
            // langs에 없지만 데이터에 존재하는 언어도 누락 없이 포함
            for seg in multiStore.segments {
                for lang in seg.targets.keys where !(seg.targets[lang]?.isEmpty ?? true) {
                    if !usedLangs.contains(lang) { usedLangs.append(lang) }
                }
            }
            for lang in multiStore.currentTargets.keys where !(multiStore.currentTargets[lang]?.isEmpty ?? true) {
                if !usedLangs.contains(lang) { usedLangs.append(lang) }
            }

            if !usedLangs.isEmpty {
                lines.append("번역어: \(usedLangs.map { langLabel($0) }.joined(separator: ", "))")
                lines.append("")
            }

            // 확정된 세그먼트
            for seg in multiStore.segments {
                if !seg.source.isEmpty { lines.append("· \(seg.source)") }
                for lang in usedLangs {
                    if let t = seg.targets[lang], !t.isEmpty {
                        lines.append("[\(langLabel(lang))] \(glossary.normalize(t))")
                    }
                }
                lines.append("")
            }
            // 아직 확정 안 된 진행 중 자막
            let curHasContent = !multiStore.currentSource.isEmpty
                || multiStore.currentTargets.values.contains { !$0.isEmpty }
            if curHasContent {
                if !multiStore.currentSource.isEmpty { lines.append("· \(multiStore.currentSource)") }
                for lang in usedLangs {
                    if let t = multiStore.currentTargets[lang], !t.isEmpty {
                        lines.append("[\(langLabel(lang))] \(glossary.normalize(t))")
                    }
                }
                lines.append("")
            }
        } else {
            // 확정된 세그먼트
            for seg in subtitles.segments {
                if !seg.sourceText.isEmpty { lines.append("· \(seg.sourceText)") }
                if !seg.targetText.isEmpty { lines.append(polishForArchive(seg.targetText)) }
                lines.append("")
            }
            // 아직 확정 안 된 진행 중 자막
            if !subtitles.currentSource.isEmpty || !subtitles.currentTarget.isEmpty {
                if !subtitles.currentSource.isEmpty { lines.append("· \(subtitles.currentSource)") }
                if !subtitles.currentTarget.isEmpty { lines.append(polishForArchive(subtitles.currentTarget)) }
                lines.append("")
            }
        }
        return lines.joined(separator: "\n")
    }

    // ── 전사문 내보내기 (설정 메뉴 버튼) ──
    private func exportCurrentTranscript() {
        if subtitles.segments.isEmpty && multiStore.segments.isEmpty {
            statusMessage = "내보낼 전사문이 없습니다"
            return
        }
        let started = multiStore.segments.isEmpty ? sessionStart : multiSessionStart
        TranscriptArchive.export(transcriptText(started: started), started: started)
    }

    // ── 메인 콘솔 배경 (v2.19.0) ──
    // 파스텔 옅은 푸른 계열 그라데이션. 야간 모드는 기존대로 검정 유지.
    @ViewBuilder
    private var consoleBackground: some View {
        if night {
            Color.black
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.96, blue: 1.00),
                    Color(red: 0.84, green: 0.91, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// ─────────────────────────────────────────────────
struct SegmentRow: View {
    let segment: SubtitleSegment
    let glossary: GlossaryEngine
    // v2.62.0: 새 방식 용어집 코드 후처리 엔진(옵션). 있으면 원문 대조로 음역 교정.
    var pairEngine: GlossaryPairEngine? = nil
    var fontSize: CGFloat = 18
    var srcFontSize: CGFloat = 14
    @Binding var isEditing: Bool
    var onCommitSource: (String) -> Void = { _ in }
    var onCommitTarget: (String) -> Void = { _ in }
    // v2.57.0: 단위·환율 변환(단일 언어 모드 전용, 기본 꺼짐). convert=true일 때만 적용.
    var convert: Bool = false
    var currencyConverter: CurrencyConverter? = nil
    // v2.58.0: 블랙리스트 패턴(줄바꿈 구분). 확정 자막에서도 필러 제거.
    var blacklist: String = ""

    // 용어집 정규화 + 블랙리스트 제거 + (옵션) 환율 변환
    // v2.57.4: 면적(UnitConverter) 제거 — 환율만 적용.
    private func finishedTarget(_ text: String) -> String {
        var normalized = glossary.normalize(text)
        // v2.62.0: 새 방식 용어집 코드 후처리 — 원문(sourceText) 대조로 AI가 놓친 음역을 표준표기로 교정.
        if let pe = pairEngine {
            normalized = pe.apply(source: segment.sourceText, target: normalized)
        }
        // v2.58.0: 블랙리스트 필러 제거(쉼표·공백 포함 패턴 그대로)
        if !blacklist.isEmpty {
            let fillers = blacklist.contains("\n")
                ? blacklist.components(separatedBy: "\n")
                : blacklist.components(separatedBy: ",")
            for f in fillers where !f.isEmpty {
                normalized = normalized.replacingOccurrences(of: f, with: "")
            }
        }
        guard convert else { return normalized }
        if let cc = currencyConverter {
            return cc.applyConversion(to: normalized)
        }
        return normalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !segment.sourceText.isEmpty {
                EditableSubtitleText(
                    text: segment.sourceText,
                    fontSize: srcFontSize, bold: false, color: .secondary,
                    isEditing: $isEditing, onCommit: onCommitSource
                )
            }
            if !segment.targetText.isEmpty {
                EditableSubtitleText(
                    text: finishedTarget(segment.targetText),
                    fontSize: fontSize, bold: true, color: .primary,
                    isEditing: $isEditing, onCommit: onCommitTarget
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(6)
    }
}

// ─────────────────────────────────────────────────
// 번역 진행 중 표시 박스 (v2.23.0)
// active일 때 칼럼 뒤에 은은한 색을 깔고, 숨 쉬듯(밝아졌다 흐려졌다) 천천히 변화.
// idle일 때는 투명(박스 없음).
struct ActivePulseBox: View {
    var active: Bool
    var color: Color = .red   // v2.59.0: 색 구별 없이 항상 붉은색 사용(인자는 호환용으로 유지)
    @State private var pulse = false

    var body: some View {
        // v2.59.0: 시작(녹화) 중임을 확실히 알리는 붉은 맥동.
        //  진해졌다(0.5) 밝아졌다(0.15) 반복 + 붉은 테두리로 또렷하게.
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.red.opacity(active ? (pulse ? 0.50 : 0.15) : 0.0))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(active ? (pulse ? 0.9 : 0.3) : 0.0),
                            lineWidth: active ? 2 : 0)
            )
            .animation(
                active ? .easeInOut(duration: 0.85).repeatForever(autoreverses: true) : .easeOut(duration: 0.4),
                value: pulse
            )
            .onAppear { pulse = active }
            .onChange(of: active) { _, on in pulse = on }
    }
}

// ─────────────────────────────────────────────────
// 음성 지원(번역 음성 재생) 켜진 상태 표시 (v2.18.0)
// 화면에 나타날 때(=조건 충족 시)만 onAppear로 은은하게 맥동.
// 빨간 마이크(입력 받는 느낌)를 피하려고 스피커 + "음성 지원" 텍스트 사용.
struct AudioSupportBadge: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("음성 지원 중")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.blue)
        .opacity(pulse ? 1.0 : 0.55)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                   value: pulse)
        .onAppear { pulse = true }
        .help("번역 음성 재생 중")
    }
}

#Preview {
    ContentView()
}
