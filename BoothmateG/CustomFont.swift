//
//  CustomFont.swift
//  BoothmateG
//
//  Version: 1.0.0
//  Changelog:
//    1.0.0 - 최초 작성. 행사용 커스텀 글꼴(.ttf/.otf)을 런타임에 등록해 자막에 사용.
//            · 글꼴 파일 선택(NSOpenPanel) → 앱 저장소 복사 → CTFontManager 등록 → PostScript 이름 반환
//            · 앱 재시작 시 저장된 글꼴 재등록(register). Xcode에 폰트를 미리 넣지 않아도 됨.
//            · 행사마다 다른 글꼴을 그때그때 골라 적용하는 용도.
//

import AppKit
import CoreText
import UniformTypeIdentifiers

enum CustomFont {
    // 글꼴 보관 폴더: ~/Library/Application Support/BoothmateG/Fonts
    static func fontsDir() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("BoothmateG/Fonts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // 글꼴 파일의 PostScript 이름(SwiftUI Font.custom에 쓰는 이름) 추출
    static func postScriptName(of url: URL) -> String? {
        guard let descs = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let desc = descs.first else { return nil }
        let font = CTFontCreateWithFontDescriptor(desc, 0, nil)
        return CTFontCopyPostScriptName(font) as String
    }

    // 글꼴 파일을 현재 프로세스에 등록(이미 등록돼 있으면 그대로 둠). PostScript 이름 반환.
    @discardableResult
    static func register(path: String) -> String? {
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else { return nil }
        let url = URL(fileURLWithPath: path)
        var err: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err)
        // 이미 등록된 경우의 에러는 무시(등록 상태는 유효함)
        return postScriptName(of: url)
    }

    // 글꼴 등록 해제
    static func unregister(path: String) {
        guard !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        var err: Unmanaged<CFError>?
        CTFontManagerUnregisterFontsForURL(url as CFURL, .process, &err)
    }

    // 글꼴 파일 선택 → 앱 저장소로 복사 → 등록. (경로, PostScript 이름) 반환. 취소/실패 시 nil.
    static func pickAndRegister() -> (path: String, psName: String)? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.font]   // .ttf / .otf / .ttc 등
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "행사용 글꼴 선택 (.ttf / .otf)"
        guard panel.runModal() == .OK, let src = panel.url else { return nil }

        let dest = fontsDir().appendingPathComponent(src.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        do { try FileManager.default.copyItem(at: src, to: dest) }
        catch { return nil }

        guard let ps = register(path: dest.path), !ps.isEmpty else { return nil }
        return (dest.path, ps)
    }
}
