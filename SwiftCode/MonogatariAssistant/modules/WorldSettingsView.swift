//
//  WorldSettingsView.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/8/29.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

// MARK: - 資料結構

struct Location: Identifiable, Equatable {
    struct Customize: Equatable, Identifiable {
        var id = UUID()
        var key: String = ""
        var val: String = ""
    }
    let id = UUID()
    var LocalName: String = ""
    var LocalType: String = ""
    var CustomVal: [Customize] = []
    var note: String = ""
    var Child: [Location] = []
}

struct TemplatePreset: Identifiable, Equatable {
    let id = UUID()
    var name: String    // == WorldType
    var type: String    // == WorldType
    var keys: [String]
}

// MARK: - XML Codec（WorldSettings）
// 結構：
// <Type>
//   <Name>WorldSettings</Name>
//   <Location>
//     <LocalName>LocalName1</LocalName>
//     <LocalType>Type</LocalType>
//     <Key Name="KeyName1">KeyVal</Key>
//     <Memo>...</Memo>
//     <Location> ... </Location>
//   </Location>
//   ...
// </Type>
// 存/讀檔忽略「全部」區域：
// - save 時：若陣列中有名稱為「全部」的節點，僅輸出其子節點；否則輸出頂層所有節點
// - load 時：解析後自動包一層名稱為「全部」的根節點
enum WorldSettingsCodec {
    private static func esc(_ s: String) -> String {
        var t = s
        t = t.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
        return t
    }

    static func saveXML(locations: [Location]) -> String? {
        // 取得需要輸出的根（忽略「全部」）
        let roots: [Location] = locations.flatMap { loc in
            (loc.LocalName == "全部") ? loc.Child : [loc]
        }
        guard !roots.isEmpty else { return nil }

        var xml = ""
        xml += "<Type>\n"
        xml += "  <Name>WorldSettings</Name>\n"
        for root in roots {
            xml += xmlLocation(root, indent: "  ")
        }
        xml += "</Type>\n"
        return xml
    }

    private static func xmlLocation(_ loc: Location, indent: String) -> String {
        var xml = ""
        xml += "\(indent)<Location>\n"
        xml += "\(indent)  <LocalName>\(esc(loc.LocalName))</LocalName>\n"
        if !loc.LocalType.isEmpty {
            xml += "\(indent)  <LocalType>\(esc(loc.LocalType))</LocalType>\n"
        }
        if !loc.CustomVal.isEmpty {
            for kv in loc.CustomVal {
                let k = esc(kv.key)
                let v = esc(kv.val)
                xml += "\(indent)  <Key Name=\"\(k)\">\(v)</Key>\n"
            }
        }
        if !loc.note.isEmpty {
            xml += "\(indent)  <Memo>\(esc(loc.note))</Memo>\n"
        }
        if !loc.Child.isEmpty {
            for child in loc.Child {
                xml += xmlLocation(child, indent: indent + "  ")
            }
        }
        xml += "\(indent)</Location>\n"
        return xml
    }

    static func loadXML(_ xml: String) -> [Location]? {
        class Parser: NSObject, XMLParserDelegate {
            var isWorldBlock = false
            var text = ""
            var path: [String] = []

            var roots: [Location] = []
            var stack: [Location] = []

            // 暫存 <Key> 的屬性
            var currentKeyName: String?

            func parser(_ parser: XMLParser, didStartElement el: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                path.append(el)
                text = ""

                if el == "Location" {
                    stack.append(Location())
                } else if el == "Key" {
                    currentKeyName = attributeDict["Name"] ?? ""
                }
            }

            func parser(_ parser: XMLParser, foundCharacters string: String) {
                text += string
            }

            func parser(_ parser: XMLParser, didEndElement el: String, namespaceURI: String?, qualifiedName qName: String?) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let joined = path.joined(separator: "/")

                switch el {
                case "Name":
                    if joined == "Type/Name" {
                        isWorldBlock = (trimmed == "WorldSettings")
                    }

                case "LocalName":
                    if !stack.isEmpty {
                        stack[stack.count - 1].LocalName = trimmed
                    }

                case "LocalType":
                    if !stack.isEmpty {
                        stack[stack.count - 1].LocalType = trimmed
                    }

                case "Key":
                    if !stack.isEmpty {
                        let key = currentKeyName ?? ""
                        let val = trimmed
                        stack[stack.count - 1].CustomVal.append(.init(key: key, val: val))
                    }
                    currentKeyName = nil

                case "Memo":
                    if !stack.isEmpty {
                        stack[stack.count - 1].note = trimmed
                    }

                case "Location":
                    guard !stack.isEmpty else { break }
                    // 完成一個 Location：彈出並掛回上一層；若無上一層則視為 root
                    let finished = stack.removeLast()
                    if stack.isEmpty {
                        roots.append(finished)
                    } else {
                        stack[stack.count - 1].Child.append(finished)
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
        if parser.parse(), p.isWorldBlock {
            // 包一層「全部」根
            return [Location(LocalName: "全部", Child: p.roots)]
        }
        return nil
    }
}

// MARK: - 主視圖

struct WorldSettingsView: View {
    // 由主程式管理，透過 Binding 傳入，才能存/讀檔（Codec 會忽略「全部」）
    @Binding var locations: [Location]

    @State private var selectedNodeId: UUID?
    @State private var editingNodeId: UUID?
    @State private var newName: String = ""

    @State private var tempCustomKey: String = ""
    @State private var tempCustomVal: String = ""
    @State private var templatePresets: [TemplatePreset] = [
        TemplatePreset(name: "空白", type: "", keys: [])
    ]
    @State private var selectedPresetName: String = "空白"
    @State private var showRenamePresetAlert = false
    @State private var renamePresetText = ""
    @State private var showSavePresetAlert = false
    @State private var showFileImporter = false
    @State private var showFileExporter = false
    @State private var exportXML: String = ""
    @State private var exportFileName: String = "WorldTemplate.xml"
    @State private var pendingOverwritePreset: TemplatePreset? = nil

    var body: some View {
        ScrollView {
            VStack {
                HStack{
                    Text("世界設定")
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                    Menu {
                        Button("匯入模板檔案…") { showFileImporter = true }
                        Button("匯出選取模板…", action: exportSelectedTemplate)
                            .disabled(selectedPreset == nil)
                        Button("匯出全部模板…", action: exportAllTemplates)
                            .disabled(templatePresets.isEmpty)
                        Divider()
                        Button("儲存預設模板…") { saveCurrentAsPreset() }
                        Button("更改預設名稱…", action: {
                            renamePresetText = selectedPresetName
                            showRenamePresetAlert = true
                        })
                        .disabled(selectedPreset == nil)
                        Button("刪除選取預設", role: .destructive, action: deleteSelectedPreset)
                            .disabled(selectedPreset == nil || selectedPreset?.name == "空白")
                    } label: {
                        Label("模板管理", systemImage: "square.grid.2x2")
                            .labelStyle(.titleAndIcon)
                            .padding(8)
                            .background(Color.accentColor.opacity(0.14))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.borderless)
                    .padding(.trailing, 12)
                }
                VStack {
                    List {
                        ForEach($locations) { $root in
                            LocationTreeItem(
                                location: $root,
                                selectedNodeId: $selectedNodeId,
                                editingNodeId: $editingNodeId,
                                onAdd: addChild,
                                onDelete: deleteNode,
                                onRename: renameNode,
                                onMove: moveNode
                            )
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 26)
                    .frame(minWidth: 360, minHeight: 360)

                    HStack {
                        TextField("新地點名稱", text: $newName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button {
                            addLocation()
                        } label: {
                            Image(systemName: "plus.circle.fill") .foregroundStyle(.green)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("新增地點")
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.vertical, 4)

                    Divider()

                    // 選中節點顯示詳情欄
                    if let selectedId = selectedNodeId,
                       let binding = getBinding(for: selectedId, in: $locations),
                       binding.LocalName.wrappedValue != "全部" {
                        VStack(alignment: .leading, spacing: 16) {
                            // 應用模板
                            HStack {
                                Picker("應用模板:", selection: $selectedPresetName) {
                                    ForEach(templatePresets.map(\.name), id: \.self) { t in
                                        Text(t)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                Button("確定") {
                                    if let preset = templatePresets.first(where: { $0.name == selectedPresetName }) {
                                        applyTemplateTo(binding: binding, preset: preset)
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            // 名稱
                            HStack {
                                Text("名稱:")
                                TextField("地點名稱", text: binding.LocalName)
                            }
                            // 類型
                            HStack {
                                Text("類型:")
                                TextField("地點類型", text: binding.LocalType)
                            }
                            // 自訂值表
                            VStack(alignment: .leading) {
                                Text("自訂值表:")
                                ForEach(binding.CustomVal) { $item in
                                    HStack {
                                        TextField("設定", text: $item.key)
                                        Text("=")
                                        TextField("鍵值", text: $item.val)
                                        Button(role: .destructive) {
                                            binding.CustomVal.wrappedValue.removeAll { $0.id == item.id }
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("刪除設定")
                                    }
                                }
                                HStack {
                                    TextField("設定", text: $tempCustomKey)
                                    Text("=")
                                    TextField("鍵值", text: $tempCustomVal)
                                    Button {
                                        if !tempCustomKey.isEmpty {
                                            binding.CustomVal.wrappedValue.append(.init(key: tempCustomKey, val: tempCustomVal))
                                            tempCustomKey = ""
                                            tempCustomVal = ""
                                        }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("新增設定")
                                }
                            }
                            // 備註
                            VStack(alignment: .leading) {
                                Text("備註:")
                                TextEditor(text: binding.note)
                                    .frame(height: 60)
                                    .border(Color.gray.opacity(0.3))
                            }
                            Spacer()
                        }
                        .padding()
                        .frame(minWidth: 320, maxWidth: .infinity, alignment: .topLeading)
                    } else {
                        Spacer()
                    }
                }
                Spacer()
            }
        }
        .padding()
        // Save Preset：自動以 WorldType 為名，重複則詢問覆蓋
        .alert("儲存預設模板", isPresented: $showSavePresetAlert, actions: {
            Text("同名模板已存在，是否要覆蓋？")
            Button("覆蓋", action: confirmOverwritePreset)
            Button("取消", role: .cancel) { pendingOverwritePreset = nil }
        })
        // Rename Preset
        .alert("更改預設名稱", isPresented: $showRenamePresetAlert, actions: {
            TextField("新模板名稱", text: $renamePresetText)
            Button("確定", action: { renameSelectedPreset(to: renamePresetText) })
            Button("取消", role: .cancel) {}
        })
        // 匯入
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.xml, .plainText, .text, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let granted = url.startAccessingSecurityScopedResource()
                defer { if granted { url.stopAccessingSecurityScopedResource() } }
                do {
                    let xml = try String(contentsOf: url)
                    let presets = parseAllTemplatesXML(xml: xml)
                    if presets.isEmpty {
                        print("匯入失敗：檔案中沒有找到任何 <Type> 節點。")
                    } else {
                        // 合併：同名覆蓋
                        for preset in presets {
                            if let idx = templatePresets.firstIndex(where: { $0.name == preset.name }) {
                                templatePresets[idx] = preset
                            } else {
                                templatePresets.append(preset)
                            }
                        }
                        ensureBlankPresetExists()
                        if let last = presets.last { selectedPresetName = last.name }
                    }
                } catch {
                    print("讀取檔案失敗：\(error.localizedDescription)")
                }
            case .failure(let error):
                print("挑選檔案失敗：\(error.localizedDescription)")
            }
        }
        // 匯出至檔案
        .fileExporter(isPresented: $showFileExporter,
                      document: TextFileDocument(text: exportXML),
                      contentType: .xml,
                      defaultFilename: exportFileName) { _ in }
        // 啟動時初始化資料與讀模板
        .onAppear {
            // 確保存在「全部」根
            if locations.first?.LocalName != "全部" {
                locations.insert(Location(LocalName: "全部"), at: 0)
            }
            loadTemplatesFromDisk()
        }
        // 列表變更自動存檔（僅模板）
        .onChange(of: templatePresets) { _ in
            saveTemplatesToDisk()
        }
    }

    // ====== 模板管理 ======
    var selectedPreset: TemplatePreset? { templatePresets.first { $0.name == selectedPresetName } }

    func applyTemplateTo(binding: Binding<Location>, preset: TemplatePreset) {
        binding.LocalType.wrappedValue = preset.type
        binding.LocalName.wrappedValue = preset.name
        binding.CustomVal.wrappedValue = preset.keys.map { Location.Customize(key: $0, val: "") }
    }

    func saveCurrentAsPreset() {
        guard let selectedId = selectedNodeId,
              let loc = getLocation(for: selectedId, in: locations) else { return }
        let worldType = loc.LocalType.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !worldType.isEmpty else { return }
        let preset = TemplatePreset(
            name: worldType,
            type: worldType,
            keys: loc.CustomVal.map { $0.key }
        )
        if let idx = templatePresets.firstIndex(where: { $0.name == preset.name }) {
            pendingOverwritePreset = preset
            showSavePresetAlert = true
        } else {
            templatePresets.append(preset)
            selectedPresetName = preset.name
        }
    }
    func confirmOverwritePreset() {
        if let preset = pendingOverwritePreset,
           let idx = templatePresets.firstIndex(where: { $0.name == preset.name }) {
            templatePresets[idx] = preset
            selectedPresetName = preset.name
        }
        pendingOverwritePreset = nil
        showSavePresetAlert = false
    }
    func renameSelectedPreset(to newName: String) {
        guard let idx = templatePresets.firstIndex(where: { $0.name == selectedPresetName }) else { return }
        templatePresets[idx].name = newName
        templatePresets[idx].type = newName
        selectedPresetName = newName
        renamePresetText = ""
    }
    func deleteSelectedPreset() {
        if let idx = templatePresets.firstIndex(where: { $0.name == selectedPresetName && $0.name != "空白" }) {
            templatePresets.remove(at: idx)
            selectedPresetName = templatePresets.first?.name ?? ""
        }
    }

    func exportSelectedTemplate() {
        guard let preset = selectedPreset else { return }
        exportXML = toXML(preset: preset)
        exportFileName = "\(preset.name).xml"
        showFileExporter = true
    }
    func exportAllTemplates() {
        exportXML = templatePresets.map(toXML).joined(separator: "\n")
        exportFileName = "AllTemplates.xml"
        showFileExporter = true
    }

    // ==== XML/Parse（模板檔案，與專案無關） ====
    func toXML(preset: TemplatePreset) -> String {
        var xml = "<Type>\n"
        xml += "  <WorldType>\(preset.type)</WorldType>\n"
        for key in preset.keys {
            xml += "  <Key>\(key)</Key>\n"
        }
        xml += "</Type>"
        return xml
    }
    func parseTemplateXML(xml: String) -> TemplatePreset? {
        let worldType = xml.slice(from: "<WorldType>", to: "</WorldType>")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !worldType.isEmpty else { return nil }
        let keyStrings = xml.capturedGroups(pattern: "<Key>(.*?)</Key>")
        return TemplatePreset(name: worldType, type: worldType, keys: keyStrings)
    }
    func parseAllTemplatesXML(xml: String) -> [TemplatePreset] {
        guard let regex = try? NSRegularExpression(pattern: "<Type>([\\s\\S]*?)</Type>", options: [.dotMatchesLineSeparators]) else { return [] }
        let results = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
        return results.compactMap { result in
            guard let range = Range(result.range(at: 1), in: xml) else { return nil }
            return parseTemplateXML(xml: "<Type>\(xml[range])</Type>")
        }
    }

    // ==== 持久化（沙盒 Application Support/Data/WorldTemplate.xml） ====
    private func dataDirectoryURL() -> URL {
        let fm = FileManager.default
        var dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        // 建議建立 Data 子目錄
        dir.appendPathComponent("Data", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                print("建立資料夾失敗：\(error.localizedDescription)")
            }
        }
        return dir
    }
    private var worldTemplateFileURL: URL {
        dataDirectoryURL().appendingPathComponent("WorldTemplate.xml", isDirectory: false)
    }

    private func saveTemplatesToDisk() {
        let xml = templatePresets.map(toXML).joined(separator: "\n")
        do {
            try xml.write(to: worldTemplateFileURL, atomically: true, encoding: .utf8)
            // 將檔案排除 iCloud 備份（需要對可變 var 呼叫）
            var fileURL = worldTemplateFileURL
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? fileURL.setResourceValues(resourceValues)
            // print("已儲存到：\(worldTemplateFileURL.path)")
        } catch {
            print("儲存模板失敗：\(error.localizedDescription)")
        }
    }

    private func loadTemplatesFromDisk() {
        let url = worldTemplateFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            ensureBlankPresetExists()
            return
        }
        do {
            let xml = try String(contentsOf: url)
            let presets = parseAllTemplatesXML(xml: xml)
            if presets.isEmpty {
                print("讀檔成功但解析為空，保留現有預設。")
                ensureBlankPresetExists()
                return
            }
            templatePresets = presets
            ensureBlankPresetExists()
            selectedPresetName = templatePresets.first?.name ?? "空白"
        } catch {
            print("讀取模板失敗：\(error.localizedDescription)")
            ensureBlankPresetExists()
        }
    }

    private func ensureBlankPresetExists() {
        if !templatePresets.contains(where: { $0.name == "空白" }) {
            templatePresets.insert(TemplatePreset(name: "空白", type: "", keys: []), at: 0)
        }
    }

    func getLocation(for id: UUID, in arr: [Location]) -> Location? {
        for loc in arr {
            if loc.id == id { return loc }
            if let found = getLocation(for: id, in: loc.Child) { return found }
        }
        return nil
    }

    // ==== TreeView 操作 ====
    func addLocation() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let targetId = selectedNodeId ?? locations.first!.id
        addChild(parentId: targetId, name: trimmed)
        newName = ""
    }
    func addChild(parentId: UUID, name: String) {
        addChildRecursive(parentId: parentId, name: name, in: &locations)
    }
    func addChildRecursive(parentId: UUID, name: String, in arr: inout [Location]) {
        for i in arr.indices {
            if arr[i].id == parentId {
                arr[i].Child.append(Location(LocalName: name))
                return
            }
            addChildRecursive(parentId: parentId, name: name, in: &arr[i].Child)
        }
    }
    func renameNode(_ id: UUID, to newName: String) {
        renameNodeRecursive(id: id, newName: newName, in: &locations)
    }
    func renameNodeRecursive(id: UUID, newName: String, in arr: inout [Location]) {
        for i in arr.indices {
            if arr[i].id == id {
                arr[i].LocalName = newName
                return
            }
            renameNodeRecursive(id: id, newName: newName, in: &arr[i].Child)
        }
    }
    func deleteNode(_ id: UUID) {
        guard id != locations.first?.id else { return }
        _ = removeNodeRecursive(id: id, in: &locations)
        if selectedNodeId == id { selectedNodeId = nil }
    }
    func removeNodeRecursive(id: UUID, in arr: inout [Location]) -> Bool {
        for i in arr.indices {
            if arr[i].id == id {
                arr.remove(at: i)
                return true
            }
            if removeNodeRecursive(id: id, in: &arr[i].Child) { return true }
        }
        return false
    }
    func moveNode(_ id: UUID, toParent parentId: UUID, at index: Int) {
        guard id != locations.first?.id else { return }
        if let moving = extractNode(id: id, from: &locations) {
            insertNode(moving, to: parentId, at: index, in: &locations)
        }
    }
    func extractNode(id: UUID, from arr: inout [Location]) -> Location? {
        for i in arr.indices {
            if arr[i].id == id {
                return arr.remove(at: i)
            }
            if let n = extractNode(id: id, from: &arr[i].Child) { return n }
        }
        return nil
    }
    func insertNode(_ node: Location, to parentId: UUID, at index: Int, in arr: inout [Location]) {
        for i in arr.indices {
            if arr[i].id == parentId {
                arr[i].Child.insert(node, at: min(index, arr[i].Child.count))
                return
            }
            insertNode(node, to: parentId, at: index, in: &arr[i].Child)
        }
    }

    // 取得選定節點的 Binding
    func getBinding(for id: UUID, in arr: Binding<[Location]>) -> Binding<Location>? {
        for i in arr.indices {
            if arr[i].wrappedValue.id == id {
                return arr[i]
            }
            if let b = getBinding(for: id, in: arr[i].Child) { return b }
        }
        return nil
    }
}

// === String 擴充 ===
extension String {
    func slice(from: String, to: String) -> String? {
        guard let f = range(of: from)?.upperBound, let t = range(of: to, range: f..<endIndex)?.lowerBound else { return nil }
        return String(self[f..<t])
    }
    func capturedGroups(pattern: String) -> [String] {
        (try? NSRegularExpression(pattern: pattern)).map { regex in
            let results = regex.matches(in: self, range: NSRange(startIndex..., in: self))
            return results.compactMap {
                Range($0.range(at: 1), in: self).map { String(self[$0]) }
            }
        } ?? []
    }
}

// === TextFileDocument for macOS/iOS 17+ fileExporter ===
struct TextFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .xml] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        .init(regularFileWithContents: text.data(using: .utf8)!)
    }
}

// === TreeView 與 DropDelegate ===
struct LocationTreeItem: View {
    @Binding var location: Location
    @Binding var selectedNodeId: UUID?
    @Binding var editingNodeId: UUID?
    var onAdd: (UUID, String) -> Void
    var onDelete: (UUID) -> Void
    var onRename: (UUID, String) -> Void
    var onMove: (UUID, UUID, Int) -> Void

    @State private var expanded: Bool = true
    @State private var tempName: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                if editingNodeId == location.id {
                    TextField("地點名稱", text: $tempName, onCommit: {
                        onRename(location.id, tempName)
                        editingNodeId = nil
                    })
                    .textFieldStyle(.roundedBorder)
                    .onAppear { tempName = location.LocalName }
                    .onExitCommand { editingNodeId = nil }
                } else {
                    Text(location.LocalName.isEmpty ? "（未命名）" : location.LocalName)
                        .fontWeight(selectedNodeId == location.id ? .bold : .regular)
                        .onTapGesture { selectedNodeId = location.id }
                        .onTapGesture(count: 2) {
                            tempName = location.LocalName
                            editingNodeId = location.id
                        }
                }
                Spacer()
                if !location.Child.isEmpty {
                    Button(action: { expanded.toggle() }) {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }.buttonStyle(.plain)
                }
                if location.LocalName != "全部" {
                    Button(role: .destructive) {
                        onDelete(location.id)
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { selectedNodeId = location.id }
            .onDrag {
                NSItemProvider(object: location.id.uuidString as NSString)
            }
            .onDrop(of: [UTType.text.identifier], delegate: LocationDropDelegate(
                parentId: location.id,
                onMove: onMove
            ))
            if expanded {
                ForEach($location.Child) { $child in
                    LocationTreeItem(
                        location: $child,
                        selectedNodeId: $selectedNodeId,
                        editingNodeId: $editingNodeId,
                        onAdd: onAdd,
                        onDelete: onDelete,
                        onRename: onRename,
                        onMove: onMove
                    )
                    .padding(.leading, 16)
                }
            }
        }
    }
}

struct LocationDropDelegate: DropDelegate {
    let parentId: UUID
    let onMove: (UUID, UUID, Int) -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [UTType.text.identifier]).first else { return false }
        item.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, _) in
            if let d = data as? Data, let s = String(data: d, encoding: .utf8), let uuid = UUID(uuidString: s) {
                DispatchQueue.main.async {
                    onMove(uuid, parentId, 0)
                }
            }
        }
        return true
    }
}

// 使用 Binding 預覽
#Preview {
    @State var data: [Location] = [
        Location(LocalName: "全部", Child: [
            Location(LocalName: "大陸", LocalType: "國家/地理", CustomVal: [.init(key: "氣候", val: "溫帶")], note: "這是備註", Child: [
                Location(LocalName: "首都", LocalType: "城市", CustomVal: [.init(key: "人口", val: "100萬")], note: "子層備註", Child: [])
            ])
        ])
    ]
    return WorldSettingsView(locations: $data)
}
