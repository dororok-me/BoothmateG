//
//  TranscriptArchive.swift
//  BoothmateG
//
//  Version: 1.1.0
//  Changelog:
//    1.1.0 - 보관 정책을 "최근 50개 세션" → "최근 3개월"로 변경.
//            prune()이 개수 기준 대신 생성일 기준으로 3개월(maxAgeMonths)보다 오래된 .txt를 삭제.
//            기존 maxSessions 상수는 미사용으로 남겨 둠(append-only).
//    1.0.0 - 최초 작성.
//            · 세션 전사문(.txt) 자동 저장 — 최근 50개 세션까지 보관(초과 시 오래된 것부터 삭제)
//            · 파일명에 날짜·시간 포함 (예: transcript_20260614_153012.txt)
//            · Finder에서 저장 폴더 열기
//            · 현재 전사문을 사용자가 고른 위치에 .txt로 내보내기(NSSavePanel)
//

import Foundation
import AppKit
import UniformTypeIdentifiers

enum TranscriptArchive {

    static let maxSessions = 50          // (미사용) 1.0.0 개수 기준 보관 정책 잔존
    static let maxAgeMonths = 3          // 보관 기간: 최근 3개월

    // 저장 폴더: ~/Library/Application Support/BoothmateG/Transcripts
    static var folderURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("BoothmateG/Transcripts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // 파일명용 타임스탬프: 20260614_153012
    static func timestamp(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: date)
    }

    // 자동 저장 (내용이 비어 있으면 저장 안 함). 저장 후 3개월 지난 전사문 정리.
    @discardableResult
    static func autoSave(_ text: String, started: Date?) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let name = "transcript_\(timestamp(started ?? Date())).txt"
        let url = folderURL.appendingPathComponent(name)
        do {
            try trimmed.write(to: url, atomically: true, encoding: .utf8)
            print("[BMG] 전사문 자동 저장: \(url.lastPathComponent)")
        } catch {
            print("[BMG] 전사문 저장 실패: \(error.localizedDescription)")
            return nil
        }
        prune()
        return url
    }

    // 생성일이 3개월(maxAgeMonths) 이전인 전사문 삭제
    static func prune() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]) else { return }

        // 기준 시각: 지금으로부터 maxAgeMonths개월 전. 계산 실패 시 정리 생략(안전).
        guard let cutoff = Calendar.current.date(
            byAdding: .month, value: -maxAgeMonths, to: Date()) else { return }

        let txts = files.filter { $0.pathExtension.lowercased() == "txt" }
        for url in txts {
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            if created < cutoff {
                try? fm.removeItem(at: url)
            }
        }
    }

    // 보관 중인 전사문 개수
    static func count() -> Int {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension.lowercased() == "txt" }.count
    }

    // Finder에서 저장 폴더 열기
    static func openFolder() {
        NSWorkspace.shared.open(folderURL)
    }

    // 내보내기: 현재 전사문을 사용자가 고른 위치에 .txt로 저장
    static func export(_ text: String, started: Date?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "transcript_\(timestamp(started ?? Date())).txt"
        panel.canCreateDirectories = true
        panel.title = "전사문 내보내기"
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            do {
                try trimmed.write(to: url, atomically: true, encoding: .utf8)
                print("[BMG] 전사문 내보내기 완료: \(url.path)")
            } catch {
                print("[BMG] 전사문 내보내기 실패: \(error.localizedDescription)")
            }
        }
    }
}
