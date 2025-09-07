//
//  ContentView.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/8/26.
//

import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct ContentView: View {
    @State var SlidePage : Int = 0
    @State var AutoSaveTime : Int = 1

    // 主編輯器文字
    @State private var ContentText: String = ""

    // BaseInfo & ChapterSelection 狀態
    @State private var baseInfoData = BaseInfoData()
    @State private var SegmentsData: [SegmentData] = [
        SegmentData(
            SegmentName: "Seg 1",
            Chapters: [ChapterData(ChapterName: "Chapter 1", ChapterContent: "")],
            SegmentUUID: UUID()
        )
    ]
    // 大綱（Outline）
    @State private var OutlineData: [StorylineData] = [
        StorylineData(
            StorylineName: "主線 1",
            StorylineType: "起",
            Scenes: [
                StoryEventData(
                    StoryEvent: "事件 1",
                    Scenes: [
                        SceneData(SceneName: "場景 A")
                    ],
                    Memo: ""
                )
            ],
            Memo: ""
        )
    ]
    // 世界設定（WorldSettings）
    @State private var WorldSettingsData: [Location] = [
        Location(LocalName: "全部")
    ]

    // 角色設定（Characters）
    @State private var CharacterData: [CharacterProfile] = [CharacterProfile()]

    // 目前選取位置（Chapter，用於存檔前同步寫回 ContentText）
    @State private var selectedSegID: UUID? = nil
    @State private var selectedChapID: UUID? = nil

    @State private var TotalWords: Int = 0

    // 檔案狀態
    @State private var currentFileURL: URL? = nil
    @State private var showingError = false
    @State private var errorMessage = ""

    #if os(macOS)
    @FocusState private var editorFocused: Bool
    #endif

    // 髒檔管理
    @ObservedObject private var dirty = DirtyStateManager.shared

    var body: some View {
        NavigationSplitView {
            ScrollViewReader { _ in
                Group {
                    Button("故事設定", systemImage: "book") { SlidePage = 0 }.padding()
                    Button("章節選擇", systemImage: "menucard") { SlidePage = 1 }.padding()
                    Button("大綱調整", systemImage: "list.bullet.indent") { SlidePage = 2 }.padding()
                    Button("世界設定", systemImage: "globe.asia.australia") { SlidePage = 3 }.padding()
                    Button("角色設定", systemImage: "person.text.rectangle") { SlidePage = 4 }.padding()
                    Button("詞語參考", systemImage: "character.book.closed") { SlidePage = 5 }.padding()
                    Button("搜尋/取代", systemImage: "magnifyingglass") { SlidePage = 6 }.padding()
                    Button("文本校正", systemImage: "character.cursor.ibeam") { SlidePage = 7 }.padding()
                    Button(" Copliot ", systemImage: "timelapse") { SlidePage = 8 }.padding()
                }
                #if os(macOS)
                .buttonStyle(.borderless)
                #else
                .buttonStyle(.plain)
                #endif
            }
        } content: {
            pageView()
        } detail: {
            TextEditor(text: $ContentText)
                .padding()
                #if os(macOS)
                .focused($editorFocused)
                .onAppear { editorFocused = true }
                #endif
                .toolbar {
                    ToolbarItem() {
                        HStack {
                            Menu("檔案") {
                                Button("新建檔案") { newProject() }
                                Button("開啟檔案") { openProject() }
                                Button("儲存檔案") { saveProject() }
                                Button("另存新檔") { saveProjectAs() }
                                Menu("匯出檔案") {
                                    Button(".txt") { exportAs(ext: "txt") }
                                    Button(".md") { exportAs(ext: "md") }
                                }
                            }
                            .font(.title2).padding()

                            Button("Undo", systemImage: "arrow.uturn.backward"){ performEditorAction("undo:") }
                            Button("Redo", systemImage: "arrow.uturn.forward"){ performEditorAction("redo:") }
                            Button("AllSelect", systemImage: "doc.plaintext.fill"){ performEditorAction("selectAll:") }
                            Button("Cut", systemImage: "scissors"){ performEditorAction("cut:") }
                            Button("Copy", systemImage: "doc.on.doc"){ performEditorAction("copy:") }
                            Button("Paste", systemImage: "list.clipboard"){ performEditorAction("paste:") }
                            Button("Find", systemImage: "magnifyingglass"){ print("Find") }
                        }
                    }
                }
                .alert("錯誤", isPresented: $showingError) { Button("好", role: .cancel) {} } message: { Text(errorMessage) }
        }
        .onAppear {
            // 設定髒檔管理所需的快照與儲存行為
            dirty.currentSnapshotProvider = { self.projectXMLSnapshotForCompare() }
            dirty.attemptSave = { self.saveProjectForPrompt() }

            // 啟動時建立 baseline，解決「初始化修改後新建不提示」問題
            if dirty.baseline == nil {
                dirty.setBaseline(projectXMLSnapshotForCompare())
            }

            #if os(macOS)
            // 攔截視窗關閉：先詢問是否儲存，再結束程式
            WindowCloseHelper.shared.installOnKeyWindow()
            #endif
        }
    }

    @ViewBuilder
    private func pageView() -> some View {
        switch SlidePage {
        case 0:
            BaseInfoView(data: $baseInfoData, contentText: $ContentText, totalWords: $TotalWords)
        case 1:
            ChapterSelectionView(
                segments: $SegmentsData,
                contentText: $ContentText,
                selectedSegmentID: $selectedSegID,
                selectedChapterID: $selectedChapID
            )
        case 2:
            OutlineAdjustView(storylines: $OutlineData)
        case 3:
            WorldSettingsView(locations: $WorldSettingsData)
        case 4:
            CharacterSettingsView(characters: $CharacterData)
        case 5: GlossaryView()
        case 6: FindReplaceView()
        case 7: ProofreadingView()
        case 8: CopilotView()
        default:
            Text("Page \(SlidePage+1)")
        }
    }

    // MARK: - 存檔前同步：把編輯器內容寫回目前選取的章節（ChapterSelection）
    private func syncEditorToSelectedChapter() {
        guard let segID = selectedSegID, let chapID = selectedChapID,
              let si = SegmentsData.firstIndex(where: { $0.SegmentUUID == segID }),
              let ci = SegmentsData[si].Chapters.firstIndex(where: { $0.ChapterUUID == chapID }) else { return }
        SegmentsData[si].Chapters[ci].ChapterContent = ContentText
    }

    // MARK: - 專案 XML：保存版（包含 LatestSave）與比較版（去除 LatestSave）

    // 比較用：避免 LatestSave 時戳干擾，且不回寫 latestSave 到狀態
    private func projectXMLSnapshotForCompare() -> String {
        syncEditorToSelectedChapter()
        return buildProjectXML(includeLatestSaveInXML: false, propagateLatestSaveBack: false)
    }

    // 寫檔用：寫入 LatestSave，並回寫 latestSave 到狀態
    private func projectXMLSnapshotForSave() -> String {
        syncEditorToSelectedChapter()
        return buildProjectXML(includeLatestSaveInXML: true, propagateLatestSaveBack: true)
    }

    private func buildProjectXML(includeLatestSaveInXML: Bool, propagateLatestSaveBack: Bool) -> String {
        var blocks: [String] = []

        // BaseInfo
        do {
            var snapshot = baseInfoData
            if let xml = BaseInfoCodec.saveXML(updatingLatestSave: &snapshot, totalWords: TotalWords, contentText: ContentText) {
                if propagateLatestSaveBack {
                    baseInfoData.latestSave = snapshot.latestSave
                }
                let xml2: String
                if includeLatestSaveInXML {
                    xml2 = xml
                } else {
                    xml2 = stripLatestSave(from: xml)
                }
                blocks.append(xml2)
            }
        }

        // ChapterSelection
        if let xml = ChapterSelectionCodec.saveXML(segments: SegmentsData) {
            blocks.append(xml)
        }

        // Outline
        if let xml = OutlineCodec.saveXML(storylines: OutlineData) {
            blocks.append(xml)
        }

        // WorldSettings
        if let xml = WorldSettingsCodec.saveXML(locations: WorldSettingsData) {
            blocks.append(xml)
        }

        // Characters
        if let xml = CharacterSettingsCodec.saveXML(characters: CharacterData) {
            blocks.append(xml)
        }

        var final = ""
        final += "<Project>\n"
        for b in blocks { final += b + "\n" }
        final += "</Project>\n"
        return final
    }

    private func stripLatestSave(from xml: String) -> String {
        // 移除 <LatestSave>...</LatestSave> 以避免時間戳造成髒檔誤判
        let pattern = "<LatestSave>[\\s\\S]*?<\\/LatestSave>\\s*"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
            return regex.stringByReplacingMatches(in: xml, options: [], range: range, withTemplate: "")
        }
        return xml
    }

    // MARK: - 檔案動作

    private func newProject() {
        #if os(macOS)
        dirty.confirmProceedIfDirty(reason: "新建檔案") {
            performNewProjectReset()
            // 新建完成後視為「乾淨」
            dirty.setBaseline(projectXMLSnapshotForCompare())
        }
        #else
        performNewProjectReset()
        #endif
    }

    private func performNewProjectReset() {
        baseInfoData = BaseInfoData()
        SegmentsData = [
            SegmentData(
                SegmentName: "Seg 1",
                Chapters: [ChapterData(ChapterName: "Chapter 1", ChapterContent: "")],
                SegmentUUID: UUID()
            )
        ]
        OutlineData = [
            StorylineData(
                StorylineName: "主線 1",
                StorylineType: "起",
                Scenes: [StoryEventData(StoryEvent: "事件 1", Scenes: [SceneData(SceneName: "場景 A")], Memo: "", StoryEventUUID: UUID())],
                Memo: "",
                ChapterUUID: UUID()
            )
        ]
        WorldSettingsData = [Location(LocalName: "全部")]

        CharacterData = [CharacterProfile()]

        selectedSegID = SegmentsData.first?.SegmentUUID
        selectedChapID = SegmentsData.first?.Chapters.first?.ChapterUUID
        TotalWords = 0
        ContentText = ""
        currentFileURL = nil
    }

    private func openProject() {
        #if os(macOS)
        dirty.confirmProceedIfDirty(reason: "開啟檔案") {
            do {
                let result = try ProjectFileService.openProjectWithPanel()
                currentFileURL = result.url

                let contents = result.contents
                if contents.contains("<Type>") {
                    let blocks = extractTypeBlocks(from: contents)
                    for block in blocks {
                        if let parsed = BaseInfoCodec.loadXML(block) {
                            baseInfoData = parsed
                            continue
                        }
                        if let segs = ChapterSelectionCodec.loadXML(block) {
                            SegmentsData = segs
                            continue
                        }
                        if let outline = OutlineCodec.loadXML(block) {
                            OutlineData = outline
                            continue
                        }
                        if let world = WorldSettingsCodec.loadXML(block) {
                            WorldSettingsData = world
                            continue
                        }
                        if let chars = CharacterSettingsCodec.loadXML(block) {
                            CharacterData = chars
                            continue
                        }
                    }
                    // 顯示初始化
                    selectedSegID = SegmentsData.first?.SegmentUUID
                    selectedChapID = SegmentsData.first?.Chapters.first?.ChapterUUID
                    ContentText = SegmentsData.first?.Chapters.first?.ChapterContent ?? ""
                } else {
                    // 非專案格式：直接視為正文（不會存回專案）
                    ContentText = contents
                }

                // 成功開啟後，更新基準
                dirty.setBaseline(projectXMLSnapshotForCompare())
            } catch {
                present(error)
            }
        }
        #else
        present(ProjectFileError.unsupportedOperation)
        #endif
    }

    private func saveProject() {
        let xml = projectXMLSnapshotForSave()

        #if os(macOS)
        do {
            if let url = currentFileURL {
                try ProjectFileService.write(string: xml, to: url)
                dirty.setBaseline(projectXMLSnapshotForCompare())
            } else {
                let url = try ProjectFileService.saveProjectWithPanel(contents: xml, suggestedURL: nil)
                currentFileURL = url
                dirty.setBaseline(projectXMLSnapshotForCompare())
            }
        } catch {
            present(error)
        }
        #else
        do {
            let url = try ProjectFileService.saveProjectQuick(contents: xml)
            currentFileURL = url
            dirty.setBaseline(projectXMLSnapshotForCompare())
        } catch {
            present(error)
        }
        #endif
    }

    // 提供給提醒使用：回傳是否存檔成功
    private func saveProjectForPrompt() -> Bool {
        let xml = projectXMLSnapshotForSave()
        #if os(macOS)
        do {
            if let url = currentFileURL {
                try ProjectFileService.write(string: xml, to: url)
                dirty.setBaseline(projectXMLSnapshotForCompare())
                return true
            } else {
                let url = try ProjectFileService.saveProjectWithPanel(contents: xml, suggestedURL: nil)
                currentFileURL = url
                dirty.setBaseline(projectXMLSnapshotForCompare())
                return true
            }
        } catch {
            present(error)
            return false
        }
        #else
        return false
        #endif
    }

    private func saveProjectAs() {
        let xml = projectXMLSnapshotForSave()
        #if os(macOS)
        do {
            let url = try ProjectFileService.saveProjectWithPanel(contents: xml, suggestedURL: currentFileURL)
            currentFileURL = url
            dirty.setBaseline(projectXMLSnapshotForCompare())
        } catch {
            present(error)
        }
        #else
        present(ProjectFileError.unsupportedOperation)
        #endif
    }

    private func exportAs(ext fileExtension: String) {
        #if os(macOS)
        do {
            let base = (currentFileURL?.deletingPathExtension().lastPathComponent) ?? ProjectFileService.defaultFileName
            _ = try ProjectFileService.exportTextWithPanel(text: ContentText, defaultName: base, fileExtension: fileExtension)
        } catch { present(error) }
        #else
        do {
            let base = (currentFileURL?.deletingPathExtension().lastPathComponent) ?? ProjectFileService.defaultFileName
            _ = try ProjectFileService.exportTextQuickToTemp(text: ContentText, fileName: base, fileExtension: fileExtension)
        } catch { present(error) }
        #endif
    }

    // MARK: - XML 區塊抽取（開檔解析）
    private func extractTypeBlocks(from content: String) -> [String] {
        do {
            let pattern = "<Type[\\s\\S]*?</Type>"
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            let matches = regex.matches(in: content, options: [], range: range)
            return matches.compactMap { m in
                guard let r = Range(m.range, in: content) else { return nil }
                return String(content[r])
            }
        } catch {
            return []
        }
    }

    // MARK: - 編輯器動作
    private func performEditorAction(_ selectorName: String) {
        let sel = NSSelectorFromString(selectorName)
        #if os(macOS)
        DispatchQueue.main.async { NSApp.sendAction(sel, to: nil, from: nil) }
        #elseif os(iOS)
        DispatchQueue.main.async { UIApplication.shared.sendAction(sel, to: nil, from: nil, for: nil) }
        #endif
    }

    // MARK: - 錯誤處理
    private func present(_ error: Error) {
        errorMessage = (error as NSError).localizedDescription
        showingError = true
    }
}

#Preview {
    ContentView()
}
