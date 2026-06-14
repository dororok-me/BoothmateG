//
//  TranscriptArchive.swift
//  BoothmateG
//
//  Version: 1.0.0
//  Changelog:
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

    static let maxSessions = 50

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

    // 자동 저장 (내용이 비어 있으면 저장 안 함). 저장 후 50개 초과분 정리.
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

    // 50개 초과 시 오래된 파일부터 삭제
    static func prune() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]) else { return }

        let txts = files.filter { $0.pathExtension.lowercased() == "txt" }
        guard txts.count > maxSessions else { return }

        let sorted = txts.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return da < db   // 오래된 것이 앞
        }
        for old in sorted.prefix(txts.count - maxSessions) {
            try? fm.removeItem(at: old)
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
