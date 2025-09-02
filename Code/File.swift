//
//  File.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/8/28.
//
//  提供檔案開啟/儲存/另存/匯出等輔助工具。
//  一般專案副檔名為 .mnproj（內容格式為 XML），實際解析由主程式負責。

import Foundation

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
import UniformTypeIdentifiers
#endif

enum ProjectFileError: Error {
    case userCancelled
    case invalidURL
    case writeFailed(underlying: Error)
    case readFailed(underlying: Error)
    case encodingFailed
    case decodingFailed
    case unsupportedOperation
}

struct ProjectFileService {
    // MARK: - 基本設定
    static let defaultExtension = "mnproj"
    static let alternateReadableExtension = "xml"
    static let defaultFileName = "Untitled"
    
    // 建議的 XML 模板（必要時讓主程式覆寫/擴充）
    static let defaultXMLTemplate = "<Project>\n</Project>\n"
    
    // MARK: - 共用：讀寫 URL
    static func write(string: String, to url: URL, using encoding: String.Encoding = .utf8) throws {
        do {
            try string.write(to: url, atomically: true, encoding: encoding)
        } catch {
            throw ProjectFileError.writeFailed(underlying: error)
        }
    }
    
    static func write(data: Data, to url: URL) throws {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ProjectFileError.writeFailed(underlying: error)
        }
    }
    
    static func readString(from url: URL, using encoding: String.Encoding = .utf8) throws -> String {
        do {
            return try String(contentsOf: url, encoding: encoding)
        } catch {
            throw ProjectFileError.readFailed(underlying: error)
        }
    }
    
    static func readData(from url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            throw ProjectFileError.readFailed(underlying: error)
        }
    }
    
    // MARK: - 共用：輔助
    static func ensureExtension(_ url: URL, preferredExt: String = defaultExtension) -> URL {
        if url.pathExtension.isEmpty {
            return url.appendingPathExtension(preferredExt)
        }
        return url
    }
    
    static func uniqueURLIfNeeded(_ url: URL) -> URL {
        var candidate = url
        let fm = FileManager.default
        
        if !fm.fileExists(atPath: candidate.path) {
            return candidate
        }
        let baseName = candidate.deletingPathExtension().lastPathComponent
        let ext = candidate.pathExtension
        let dir = candidate.deletingLastPathComponent()
        
        var idx = 1
        while true {
            let name = "\(baseName) (\(idx))"
            let next = dir.appendingPathComponent(name).appendingPathExtension(ext)
            if !fm.fileExists(atPath: next.path) {
                return next
            }
            idx += 1
        }
    }
    
    static func userDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // MARK: - macOS：開啟/儲存面板
    #if os(macOS)
    @discardableResult
    static func openProjectWithPanel() throws -> (url: URL, contents: String) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = [defaultExtension, alternateReadableExtension]
        panel.directoryURL = userDocumentsDirectory()
        panel.title = "開啟專案"
        panel.prompt = "開啟"
        
        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            throw ProjectFileError.userCancelled
        }
        // 主程式負責解析；此處只回傳原始字串
        let contents = try readString(from: url)
        return (url, contents)
    }
    
    // 另存新檔 / 儲存對話框，回傳實際儲存位置
    @discardableResult
    static func saveProjectWithPanel(contents: String, suggestedURL: URL? = nil) throws -> URL {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedFileTypes = [defaultExtension]
        panel.title = "儲存專案"
        panel.prompt = "儲存"
        panel.isExtensionHidden = false
        
        if let sug = suggestedURL {
            panel.directoryURL = sug.deletingLastPathComponent()
            panel.nameFieldStringValue = sug.deletingPathExtension().lastPathComponent
        } else {
            panel.directoryURL = userDocumentsDirectory()
            panel.nameFieldStringValue = defaultFileName
        }
        
        let response = panel.runModal()
        guard response == .OK, let chosen = panel.url else {
            throw ProjectFileError.userCancelled
        }
        let finalURL = ensureExtension(chosen, preferredExt: defaultExtension)
        try write(string: contents, to: finalURL)
        return finalURL
    }
    
    // 匯出純文字（.txt / .md）
    @discardableResult
    static func exportTextWithPanel(text: String, defaultName: String = defaultFileName, fileExtension: String) throws -> URL {
        let allowed = [fileExtension]
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedFileTypes = allowed
        panel.title = "匯出檔案"
        panel.prompt = "匯出"
        panel.isExtensionHidden = false
        panel.directoryURL = userDocumentsDirectory()
        panel.nameFieldStringValue = defaultName
        
        let response = panel.runModal()
        guard response == .OK, let chosen = panel.url else {
            throw ProjectFileError.userCancelled
        }
        let finalURL = ensureExtension(chosen, preferredExt: fileExtension)
        try write(string: text, to: finalURL)
        return finalURL
    }
    #endif
    
    // MARK: - iOS：簡易存取（建議用 .fileImporter / .fileExporter 在 View 端搭配）
    #if os(iOS)
    // 在 iOS，建議於 SwiftUI View 使用 .fileImporter / .fileExporter 管理檔案選取。
    // 下方提供簡易 API（不彈面板），將檔案讀寫到「文件」目錄。
    
    static func saveProjectQuick(contents: String, fileName: String = defaultFileName) throws -> URL {
        let dir = userDocumentsDirectory()
        let url = ensureExtension(dir.appendingPathComponent(fileName), preferredExt: defaultExtension)
        let finalURL = uniqueURLIfNeeded(url)
        try write(string: contents, to: finalURL)
        return finalURL
    }
    
    static func openProjectQuick(from url: URL) throws -> String {
        try readString(from: url)
    }
    
    // 透過 iOS 文件分享（檔案 App）匯出文字，可在呼叫端用 UIActivityViewController 或 .fileExporter。
    // 這裡僅提供將文字輸出成臨時檔，回傳 URL 供上層分享。
    static func exportTextQuickToTemp(text: String, fileName: String, fileExtension: String) throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
        let url = ensureExtension(tmpDir.appendingPathComponent(fileName), preferredExt: fileExtension)
        try write(string: text, to: url)
        return url
    }
    #endif
    
    // MARK: - 建立新專案（回傳模板字串，由主程式去解析/初始化狀態）
    static func newProjectTemplateString() -> String {
        defaultXMLTemplate
    }
}
