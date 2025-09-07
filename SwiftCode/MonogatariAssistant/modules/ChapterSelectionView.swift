//
//  ChapterSelectionView.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/8/29.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

// MARK: - 資料結構

struct ChapterData: Equatable, Identifiable {
    var ChapterName: String = ""
    var ChapterContent: String = ""
    var ChapterUUID: UUID = UUID()
    var ChapterWordsCount: Int { ChapterContent.count }
    var id: UUID { ChapterUUID }
}

struct SegmentData: Equatable, Identifiable {
    var SegmentName: String = ""
    var Chapters: [ChapterData] = []
    var SegmentUUID: UUID = UUID()
    var id: UUID { SegmentUUID }
}

private extension UTType {
    static let chapterUUIDText = UTType.plainText
}

// MARK: - Codec for <Type><Name>ChapterSelection</Name> ... </Type>
enum ChapterSelectionCodec {
    static func saveXML(segments: [SegmentData]) -> String? {
        guard !segments.isEmpty, segments.contains(where: { !$0.Chapters.isEmpty }) else { return nil }

        func esc(_ s: String) -> String {
            var t = s
            t = t.replacingOccurrences(of: "&", with: "&amp;")
                 .replacingOccurrences(of: "<", with: "&lt;")
                 .replacingOccurrences(of: ">", with: "&gt;")
                 .replacingOccurrences(of: "\"", with: "&quot;")
                 .replacingOccurrences(of: "'", with: "&apos;")
            return t
        }

        var xml = ""
        xml += "<Type>\n"
        xml += "  <Name>ChapterSelection</Name>\n"
        for seg in segments {
            xml += "  <Segment Name=\"\(esc(seg.SegmentName))\" UUID=\"\(seg.SegmentUUID.uuidString)\">\n"
            for ch in seg.Chapters {
                xml += "    <Chapter Name=\"\(esc(ch.ChapterName))\" UUID=\"\(ch.ChapterUUID.uuidString)\">\n"
                xml += "      <Content>\(esc(ch.ChapterContent))</Content>\n"
                xml += "    </Chapter>\n"
            }
            xml += "  </Segment>\n"
        }
        xml += "</Type>\n"
        return xml
    }

    static func loadXML(_ xml: String) -> [SegmentData]? {
        class Parser: NSObject, XMLParserDelegate {
            var nameIsChapterSelection = false
            var path: [String] = []
            var text: String = ""

            var segments: [SegmentData] = []
            var curSegment: SegmentData? = nil
            var curChapter: ChapterData? = nil

            func parser(_ parser: XMLParser, didStartElement el: String, namespaceURI: String?, qualifiedName q: String?, attributes attrs: [String : String] = [:]) {
                path.append(el)
                text = ""

                switch el {
                case "Segment":
                    var seg = SegmentData()
                    seg.SegmentName = attrs["Name"] ?? ""
                    if let u = attrs["UUID"], let id = UUID(uuidString: u) { seg.SegmentUUID = id }
                    curSegment = seg
                case "Chapter":
                    var ch = ChapterData()
                    ch.ChapterName = attrs["Name"] ?? ""
                    if let u = attrs["UUID"], let id = UUID(uuidString: u) { ch.ChapterUUID = id }
                    curChapter = ch
                default:
                    break
                }
            }

            func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

            func parser(_ parser: XMLParser, didEndElement el: String, namespaceURI: String?, qualifiedName q: String?) {
                let p = path.joined(separator: "/")
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

                switch p {
                case "Type/Name":
                    nameIsChapterSelection = (trimmed == "ChapterSelection")
                case "Type/Segment/Chapter/Content":
                    if var ch = curChapter {
                        ch.ChapterContent = trimmed
                        curChapter = ch
                    }
                case "Type/Segment/Chapter":
                    if var seg = curSegment, let ch = curChapter {
                        seg.Chapters.append(ch)
                        curSegment = seg
                        curChapter = nil
                    }
                case "Type/Segment":
                    if let seg = curSegment {
                        segments.append(seg)
                        curSegment = nil
                    }
                default:
                    break
                }

                _ = path.popLast()
                text = ""
            }
        }

        guard let data = xml.data(using: .utf8) else { return nil }
        let p = Parser()
        let parser = XMLParser(data: data)
        parser.delegate = p
        return (parser.parse() && p.nameIsChapterSelection) ? p.segments : nil
    }
}

struct ChapterSelectionView: View {
    // 綁定主程式：段落與編輯器文字
    @Binding var segments: [SegmentData]
    @Binding var contentText: String
    // 將「目前選取的 Seg/Chapter」提升為外部綁定，方便外層存檔前回寫
    @Binding var selectedSegmentID: UUID?
    @Binding var selectedChapterID: UUID?

    // 編輯名稱（雙擊）狀態
    @State private var editingSegmentID: UUID? = nil
    @State private var editingChapterID: UUID? = nil

    // 新增輸入框
    @State private var newSegmentName: String = ""
    @State private var newChapterName: String = ""

    private var totalChaptersCount: Int {
        segments.reduce(0) { $0 + $1.Chapters.count }
    }
    private var selectedSegmentIndex: Int? {
        guard let id = selectedSegmentID else { return nil }
        return segments.firstIndex(where: { $0.SegmentUUID == id })
    }
    
    // MARK: - 頁面佈局 && 初始設定

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("章節選擇")
                    .font(.largeTitle)
                    .bold()
                Spacer()
                #if os(iOS)
                EditButton()
                #endif
            }
            VStack(alignment: .leading, spacing: 16) {
                // Seg 列表
                VStack(alignment: .leading, spacing: 8) {
                    Text("區段選擇")
                        .font(.title2).bold()

                    List {
                        ForEach(segments) { seg in
                            segRow(seg)
                                .listRowBackground(
                                    (seg.SegmentUUID == selectedSegmentID) ? Color.accentColor.opacity(0.12) : Color.clear
                                )
                                .onDrop(of: [UTType.chapterUUIDText.identifier], isTargeted: nil) { providers in
                                    handleDropChapter(providers: providers, toSegmentID: seg.SegmentUUID)
                                }
                        }
                        .onMove { indices, newOffset in
                            moveSegments(indices: indices, newOffset: newOffset)
                        }
                    }
                    .frame(minWidth: 240, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)

                    HStack {
                        TextField("新增區段名稱", text: $newSegmentName)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            addSegment()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("新增區段")
                    }
                }

                // Chapter 列表（根據選取的 Seg 顯示）
                VStack(alignment: .leading, spacing: 8) {
                    Text("章節選擇")
                        .font(.title2).bold()

                    if let segIdx = selectedSegmentIndex {
                        let chapters = segments[segIdx].Chapters
                        List {
                            ForEach(chapters) { chap in
                                chapterRow(chap, segIdx: segIdx)
                                    .listRowBackground(
                                        (chap.ChapterUUID == selectedChapterID) ? Color.accentColor.opacity(0.12) : Color.clear
                                    )
                                    .onDrag {
                                        NSItemProvider(object: chap.ChapterUUID.uuidString as NSString)
                                    }
                            }
                            .onMove { indices, newOffset in
                                moveChapters(in: segIdx, indices: indices, newOffset: newOffset)
                            }
                        }
                        .frame(minWidth: 280, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)

                        HStack {
                            TextField("新增章節名稱", text: $newChapterName)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                addChapter(to: segIdx)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("新增章節")
                        }
                    } else {
                        VStack(spacing: 12) {
                            Text("請先選擇一個區段")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(minWidth: 280, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)
                        HStack {
                            TextField("新增 Chapter 名稱", text: $newChapterName)
                                .textFieldStyle(.roundedBorder)
                            Button("增加") {
                                if segments.isEmpty {
                                    segments.append(SegmentData(SegmentName: "Seg 1", Chapters: [], SegmentUUID: UUID()))
                                }
                                if selectedSegmentID == nil {
                                    commitCurrentEditorToSelectedChapter()
                                    selectedSegmentID = segments.first?.SegmentUUID
                                    selectedChapterID = segments.first?.Chapters.first?.ChapterUUID
                                    if let si = selectedSegmentIndex,
                                       let cid = selectedChapterID,
                                       let ci = segments[si].Chapters.firstIndex(where: { $0.ChapterUUID == cid }) {
                                        contentText = segments[si].Chapters[ci].ChapterContent
                                    }
                                }
                                if let segIdx = selectedSegmentIndex {
                                    addChapter(to: segIdx)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding()
        .onAppear {
            if segments.isEmpty {
                segments.append(
                    SegmentData(
                        SegmentName: "Seg 1",
                        Chapters: [ChapterData(ChapterName: "Chapter 1", ChapterContent: "")],
                        SegmentUUID: UUID()
                    )
                )
            } else if totalChaptersCount == 0 {
                segments[0].Chapters.append(ChapterData(ChapterName: "Chapter 1", ChapterContent: ""))
            }
            if selectedSegmentID == nil { selectedSegmentID = segments.first?.SegmentUUID }
            if selectedChapterID == nil, let idx = selectedSegmentIndex {
                selectedChapterID = segments[idx].Chapters.first?.ChapterUUID
            }
            if let si = selectedSegmentIndex,
               let cid = selectedChapterID,
               let ci = segments[si].Chapters.firstIndex(where: { $0.ChapterUUID == cid }) {
                contentText = segments[si].Chapters[ci].ChapterContent
            }
        }
    }

    // MARK: - Helper：保存/選取

    private func commitCurrentEditorToSelectedChapter() {
        guard let si = selectedSegmentIndex,
              let cid = selectedChapterID,
              let ci = segments[si].Chapters.firstIndex(where: { $0.ChapterUUID == cid }) else { return }
        segments[si].Chapters[ci].ChapterContent = contentText
    }

    private func selectSegment(_ segID: UUID) {
        commitCurrentEditorToSelectedChapter()
        selectedSegmentID = segID
        if let si = segments.firstIndex(where: { $0.SegmentUUID == segID }) {
            if let firstChap = segments[si].Chapters.first {
                selectedChapterID = firstChap.ChapterUUID
                contentText = firstChap.ChapterContent
            } else {
                selectedChapterID = nil
                contentText = ""
            }
        }
    }

    private func selectChapter(segIdx: Int, chapterID: UUID) {
        commitCurrentEditorToSelectedChapter()
        selectedSegmentID = segments[segIdx].SegmentUUID
        selectedChapterID = chapterID
        if let ci = segments[segIdx].Chapters.firstIndex(where: { $0.ChapterUUID == chapterID }) {
            contentText = segments[segIdx].Chapters[ci].ChapterContent
        }
    }

    // MARK: - Row builders

    @ViewBuilder
    private func segRow(_ seg: SegmentData) -> some View {
        let isEditing = (editingSegmentID == seg.SegmentUUID)
        HStack(spacing: 8) {
            if isEditing, let idx = segments.firstIndex(where: { $0.SegmentUUID == seg.SegmentUUID }) {
                TextField("Seg 名稱", text: Binding(
                    get: { segments[idx].SegmentName },
                    set: { segments[idx].SegmentName = $0 }
                ), onCommit: {
                    editingSegmentID = nil
                })
                .textFieldStyle(.roundedBorder)
                .onSubmit { editingSegmentID = nil }
            } else {
                Text(seg.SegmentName.isEmpty ? "(未命名 Seg)" : seg.SegmentName)
            }
            Spacer()
            Button {
                editingSegmentID = seg.SegmentUUID
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help("重新命名")
            Button {
                deleteSegment(seg.SegmentUUID)
            } label: {
                Image(systemName: "trash").foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("刪除此 Seg")
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
                editingSegmentID = seg.SegmentUUID
            }
        )
        .onTapGesture { selectSegment(seg.SegmentUUID) }
    }

    @ViewBuilder
    private func chapterRow(_ chap: ChapterData, segIdx: Int) -> some View {
        let isEditing = (editingChapterID == chap.ChapterUUID)
        HStack(spacing: 8) {
            if isEditing, let cIdx = segments[segIdx].Chapters.firstIndex(where: { $0.ChapterUUID == chap.ChapterUUID }) {
                TextField("Chapter 名稱", text: Binding(
                    get: { segments[segIdx].Chapters[cIdx].ChapterName },
                    set: { segments[segIdx].Chapters[cIdx].ChapterName = $0 }
                ), onCommit: {
                    editingChapterID = nil
                })
                .textFieldStyle(.roundedBorder)
                .onSubmit { editingChapterID = nil }
            } else {
                Text(chap.ChapterName.isEmpty ? "(未命名 Chapter)" : chap.ChapterName)
            }
            Spacer()
            Button {
                editingChapterID = chap.ChapterUUID
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help("重新命名")
            Button {
                deleteChapter(segIdx: segIdx, chapterID: chap.ChapterUUID)
            } label: {
                Image(systemName: "trash").foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("刪除此章節")
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
                editingChapterID = chap.ChapterUUID
            }
        )
        .onTapGesture { selectChapter(segIdx: segIdx, chapterID: chap.ChapterUUID) }
    }

    // MARK: - 新增

    private func addSegment() {
        commitCurrentEditorToSelectedChapter()

        let name = newSegmentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = name.isEmpty ? "Seg \(segments.count + 1)" : name
        let firstChapter = ChapterData(ChapterName: "Chapter 1", ChapterContent: "")
        let newSegID = UUID()
        segments.append(SegmentData(SegmentName: finalName, Chapters: [firstChapter], SegmentUUID: newSegID))
        newSegmentName = ""

        selectSegment(newSegID)
    }

    private func addChapter(to segIdx: Int) {
        commitCurrentEditorToSelectedChapter()

        var name = newChapterName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = "Chapter \(segments[segIdx].Chapters.count + 1)" }
        let newChapter = ChapterData(ChapterName: name, ChapterContent: "")
        segments[segIdx].Chapters.append(newChapter)
        newChapterName = ""

        selectChapter(segIdx: segIdx, chapterID: newChapter.ChapterUUID)
    }

    // MARK: - 刪除

    private func deleteSegment(_ segID: UUID) {
        guard let idx = segments.firstIndex(where: { $0.SegmentUUID == segID }) else { return }
        guard segments.count > 1 else { return }
        let remainingChapters = totalChaptersCount - segments[idx].Chapters.count
        guard remainingChapters > 0 else { return }

        if selectedSegmentID == segID { commitCurrentEditorToSelectedChapter() }
        segments.remove(at: idx)

        if let first = segments.first {
            selectedSegmentID = first.SegmentUUID
            selectedChapterID = first.Chapters.first?.ChapterUUID
            if let cid = selectedChapterID,
               let ci = first.Chapters.firstIndex(where: { $0.ChapterUUID == cid }) {
                contentText = first.Chapters[ci].ChapterContent
            } else {
                contentText = ""
            }
        } else {
            selectedSegmentID = nil
            selectedChapterID = nil
            contentText = ""
        }
    }

    private func deleteChapter(segIdx: Int, chapterID: UUID) {
        guard segments.indices.contains(segIdx) else { return }
        guard let cIdx = segments[segIdx].Chapters.firstIndex(where: { $0.ChapterUUID == chapterID }) else { return }
        guard totalChaptersCount > 1 else { return }

        if selectedChapterID == chapterID { commitCurrentEditorToSelectedChapter() }

        segments[segIdx].Chapters.remove(at: cIdx)

        if let nextID = (segments[segIdx].Chapters.indices.contains(cIdx)
                         ? segments[segIdx].Chapters[cIdx].ChapterUUID
                         : segments[segIdx].Chapters.last?.ChapterUUID) {
            selectedChapterID = nextID
            if let ci = segments[segIdx].Chapters.firstIndex(where: { $0.ChapterUUID == nextID }) {
                contentText = segments[segIdx].Chapters[ci].ChapterContent
            }
        } else {
            selectedChapterID = nil
        }

        if segments[segIdx].Chapters.isEmpty, segments.count > 1 {
            let removedSegID = segments[segIdx].SegmentUUID
            segments.remove(at: segIdx)
            if let first = segments.first {
                selectedSegmentID = first.SegmentUUID
                selectedChapterID = first.Chapters.first?.ChapterUUID
                if let cid = selectedChapterID,
                   let ci = first.Chapters.firstIndex(where: { $0.ChapterUUID == cid }) {
                    contentText = first.Chapters[ci].ChapterContent
                } else {
                    contentText = ""
                }
            } else {
                selectedSegmentID = nil
                selectedChapterID = nil
                contentText = ""
            }
            if selectedSegmentID == removedSegID {
                selectedSegmentID = segments.first?.SegmentUUID
                selectedChapterID = segments.first?.Chapters.first?.ChapterUUID
                if let si = selectedSegmentIndex,
                   let cid = selectedChapterID,
                   let ci = segments[si].Chapters.firstIndex(where: { $0.ChapterUUID == cid }) {
                    contentText = segments[si].Chapters[ci].ChapterContent
                }
            }
        }
    }

    // MARK: - 移動 / 拖放

    private func moveSegments(indices: IndexSet, newOffset: Int) {
        segments.move(fromOffsets: indices, toOffset: newOffset)
    }

    private func moveChapters(in segIdx: Int, indices: IndexSet, newOffset: Int) {
        guard segments.indices.contains(segIdx) else { return }
        segments[segIdx].Chapters.move(fromOffsets: indices, toOffset: newOffset)
    }

    private func moveChapter(uuid: UUID, toSegmentID destSegID: UUID) {
        commitCurrentEditorToSelectedChapter()

        var sourceSegIdx: Int?
        var sourceChapIdx: Int?
        for (si, s) in segments.enumerated() {
            if let ci = s.Chapters.firstIndex(where: { $0.ChapterUUID == uuid }) {
                sourceSegIdx = si
                sourceChapIdx = ci
                break
            }
        }
        guard let fromSegIdx = sourceSegIdx, let fromChapIdx = sourceChapIdx else { return }
        guard let toSegIdx = segments.firstIndex(where: { $0.SegmentUUID == destSegID }) else { return }
        if fromSegIdx == toSegIdx { return }

        let sourceSegID = segments[fromSegIdx].SegmentUUID

        let moving = segments[fromSegIdx].Chapters[fromChapIdx]
        segments[fromSegIdx].Chapters.remove(at: fromChapIdx)
        segments[toSegIdx].Chapters.append(moving)

        selectedSegmentID = segments[toSegIdx].SegmentUUID
        selectedChapterID = moving.ChapterUUID
        contentText = moving.ChapterContent

        if segments.indices.contains(fromSegIdx),
           segments[fromSegIdx].SegmentUUID == sourceSegID,
           segments[fromSegIdx].Chapters.isEmpty,
           segments.count > 1 {
            segments.remove(at: fromSegIdx)
            if selectedSegmentID == sourceSegID {
                selectedSegmentID = segments.first(where: { $0.SegmentUUID == destSegID })?.SegmentUUID ?? segments.first?.SegmentUUID
                selectedChapterID = moving.ChapterUUID
                contentText = moving.ChapterContent
            }
        }
    }

    private func handleDropChapter(providers: [NSItemProvider], toSegmentID segID: UUID) -> Bool {
        let idType = UTType.chapterUUIDText.identifier
        for p in providers where p.hasItemConformingToTypeIdentifier(idType) {
            p.loadItem(forTypeIdentifier: idType, options: nil) { (item, _) in
                if let str = item as? String, let uuid = UUID(uuidString: str) {
                    DispatchQueue.main.async { self.moveChapter(uuid: uuid, toSegmentID: segID) }
                } else if let data = item as? Data,
                          let s = String(data: data, encoding: .utf8),
                          let uuid = UUID(uuidString: s) {
                    DispatchQueue.main.async { self.moveChapter(uuid: uuid, toSegmentID: segID) }
                }
            }
        }
        return true
    }
}

#Preview {
    ChapterSelectionView(
        segments: .constant([
            SegmentData(SegmentName: "Seg 1", Chapters: [ChapterData(ChapterName: "Chapter 1")]),
            SegmentData(SegmentName: "Seg 2", Chapters: [ChapterData(ChapterName: "Chapter 2")])
        ]),
        contentText: .constant(""),
        selectedSegmentID: .constant(nil as UUID?),
        selectedChapterID: .constant(nil as UUID?)
    )
}
