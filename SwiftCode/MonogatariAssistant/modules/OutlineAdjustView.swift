//
//  OutlineAdjustView.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/8/29.
//

import SwiftUI
import Foundation
import UniformTypeIdentifiers

// MARK: - 資料結構

// 大箱（故事線）
struct StorylineData: Equatable, Identifiable {
    var StorylineName: String = ""
    var StorylineType: String = ""
    var Scenes: [StoryEventData] = [] // 中箱（事件序列）
    var Memo: String = ""
    var people: [String] = [] // 新增：人物
    var item: [String] = []   // 新增：物件
    var ChapterUUID: UUID = UUID()
    var id: UUID { ChapterUUID }
}

// 中箱（事件序列）
struct StoryEventData: Equatable, Identifiable {
    var StoryEvent: String = ""
    var Scenes: [SceneData] = [] // 小箱（場景）
    var Memo: String = ""
    var people: [String] = [] // 新增：人物
    var item: [String] = []   // 新增：物件
    var StoryEventUUID: UUID = UUID()
    var id: UUID { StoryEventUUID }
}

// 小箱（場景）
struct SceneData: Equatable, Identifiable {
    var SceneName: String = ""
    var time: String = ""
    var location: String = ""
    var people: [String] = []
    var item: [String] = []
    var doingThings: [String] = []
    var Memo: String = ""
    var SceneUUID: UUID = UUID()
    var id: UUID { SceneUUID }
}

// MARK: - 拖放識別字串（用 plainText 搭配前綴區分類型）
private enum DragPayload {
    static let eventPrefix = "EVENT:"
    static let scenePrefix = "SCENE:"
    static func eventString(_ id: UUID) -> String { eventPrefix + id.uuidString }
    static func sceneString(_ id: UUID) -> String { scenePrefix + id.uuidString }
}

// MARK: - XML Codec for Outline
// <Type>
//   <Name>Outline</Name>
//   <Storyline Name="" Type="" UUID="">
//     <Memo>...</Memo>
//     <People>...</People> // 新增
//     <Items>...</Items>   // 新增
//     <Event Name="" UUID="">
//       <Memo>...</Memo>
//       <People>...</People> // 新增
//       <Items>...</Items>   // 新增
//       <Scene Name="" UUID="">
//         <Time>...</Time>
//         <Location>...</Location>
//         <People><Person>...</Person>...</People>
//         <Items><Item>...</Item>...</Items>
//         <Doings><Doing>...</Doing>...</Doings>
//         <Memo>...</Memo>
//       </Scene>
//       ...
//     </Event>
//     ...
//   </Storyline>
//   ...
// </Type>
enum OutlineCodec {
    private static func esc(_ s: String) -> String {
        var t = s
        t = t.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
        return t
    }

    static func saveXML(storylines: [StorylineData]) -> String? {
        guard !storylines.isEmpty else { return nil }
        var xml = ""
        xml += "<Type>\n"
        xml += "  <Name>Outline</Name>\n"
        for sl in storylines {
            xml += "  <Storyline Name=\"\(esc(sl.StorylineName))\" Type=\"\(esc(sl.StorylineType))\" UUID=\"\(sl.ChapterUUID.uuidString)\">\n"
            if !sl.Memo.isEmpty {
                xml += "    <Memo>\(esc(sl.Memo))</Memo>\n"
            }
            if !sl.people.isEmpty {
                xml += "    <People>\n"
                for p in sl.people { xml += "      <Person>\(esc(p))</Person>\n" }
                xml += "    </People>\n"
            }
            if !sl.item.isEmpty {
                xml += "    <Items>\n"
                for it in sl.item { xml += "      <Item>\(esc(it))</Item>\n" }
                xml += "    </Items>\n"
            }
            for ev in sl.Scenes {
                xml += "    <Event Name=\"\(esc(ev.StoryEvent))\" UUID=\"\(ev.StoryEventUUID.uuidString)\">\n"
                if !ev.Memo.isEmpty {
                    xml += "      <Memo>\(esc(ev.Memo))</Memo>\n"
                }
                if !ev.people.isEmpty {
                    xml += "      <People>\n"
                    for p in ev.people { xml += "        <Person>\(esc(p))</Person>\n" }
                    xml += "      </People>\n"
                }
                if !ev.item.isEmpty {
                    xml += "      <Items>\n"
                    for it in ev.item { xml += "        <Item>\(esc(it))</Item>\n" }
                    xml += "      </Items>\n"
                }
                for sc in ev.Scenes {
                    xml += "      <Scene Name=\"\(esc(sc.SceneName))\" UUID=\"\(sc.SceneUUID.uuidString)\">\n"
                    if !sc.time.isEmpty {
                        xml += "        <Time>\(esc(sc.time))</Time>\n"
                    }
                    if !sc.location.isEmpty {
                        xml += "        <Location>\(esc(sc.location))</Location>\n"
                    }
                    if !sc.people.isEmpty {
                        xml += "        <People>\n"
                        for p in sc.people {
                            xml += "          <Person>\(esc(p))</Person>\n"
                        }
                        xml += "        </People>\n"
                    }
                    if !sc.item.isEmpty {
                        xml += "        <Items>\n"
                        for it in sc.item {
                            xml += "          <Item>\(esc(it))</Item>\n"
                        }
                        xml += "        </Items>\n"
                    }
                    if !sc.doingThings.isEmpty {
                        xml += "        <Doings>\n"
                        for d in sc.doingThings {
                            xml += "          <Doing>\(esc(d))</Doing>\n"
                        }
                        xml += "        </Doings>\n"
                    }
                    if !sc.Memo.isEmpty {
                        xml += "        <Memo>\(esc(sc.Memo))</Memo>\n"
                    }
                    xml += "      </Scene>\n"
                }
                xml += "    </Event>\n"
            }
            xml += "  </Storyline>\n"
        }
        xml += "</Type>\n"
        return xml
    }

    static func loadXML(_ xml: String) -> [StorylineData]? {
        class Parser: NSObject, XMLParserDelegate {
            var isOutlineBlock = false
            var text = ""
            var path: [String] = []

            var storylines: [StorylineData] = []
            var curStoryline: StorylineData?
            var curEvent: StoryEventData?
            var curScene: SceneData?

            func parser(_ parser: XMLParser, didStartElement el: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                path.append(el)
                text = ""

                switch el {
                case "Storyline":
                    var s = StorylineData()
                    s.StorylineName = attributeDict["Name"] ?? ""
                    s.StorylineType = attributeDict["Type"] ?? ""
                    if let u = attributeDict["UUID"], let id = UUID(uuidString: u) { s.ChapterUUID = id }
                    curStoryline = s
                case "Event":
                    var e = StoryEventData()
                    e.StoryEvent = attributeDict["Name"] ?? ""
                    if let u = attributeDict["UUID"], let id = UUID(uuidString: u) { e.StoryEventUUID = id }
                    curEvent = e
                case "Scene":
                    var sc = SceneData()
                    sc.SceneName = attributeDict["Name"] ?? ""
                    if let u = attributeDict["UUID"], let id = UUID(uuidString: u) { sc.SceneUUID = id }
                    curScene = sc
                default:
                    break
                }
            }

            func parser(_ parser: XMLParser, foundCharacters string: String) {
                text += string
            }

            func parser(_ parser: XMLParser, didEndElement el: String, namespaceURI: String?, qualifiedName qName: String?) {
                let joined = path.joined(separator: "/")
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

                switch joined {
                case "Type/Name":
                    isOutlineBlock = (trimmed == "Outline")
                case "Type/Storyline/Memo":
                    curStoryline?.Memo = trimmed
                case "Type/Storyline/People/Person":
                    if !trimmed.isEmpty { curStoryline?.people.append(trimmed) }
                case "Type/Storyline/Items/Item":
                    if !trimmed.isEmpty { curStoryline?.item.append(trimmed) }
                case "Type/Storyline/Event/Memo":
                    curEvent?.Memo = trimmed
                case "Type/Storyline/Event/People/Person":
                    if !trimmed.isEmpty { curEvent?.people.append(trimmed) }
                case "Type/Storyline/Event/Items/Item":
                    if !trimmed.isEmpty { curEvent?.item.append(trimmed) }
                case "Type/Storyline/Event/Scene/Time":
                    curScene?.time = trimmed
                case "Type/Storyline/Event/Scene/Location":
                    curScene?.location = trimmed
                case "Type/Storyline/Event/Scene/People/Person":
                    if !trimmed.isEmpty { curScene?.people.append(trimmed) }
                case "Type/Storyline/Event/Scene/Items/Item":
                    if !trimmed.isEmpty { curScene?.item.append(trimmed) }
                case "Type/Storyline/Event/Scene/Doings/Doing":
                    if !trimmed.isEmpty { curScene?.doingThings.append(trimmed) }
                case "Type/Storyline/Event/Scene/Memo":
                    curScene?.Memo = trimmed
                case "Type/Storyline/Event/Scene":
                    if let scene = curScene {
                        curEvent?.Scenes.append(scene)
                        curScene = nil
                    }
                case "Type/Storyline/Event":
                    if let ev = curEvent {
                        curStoryline?.Scenes.append(ev)
                        curEvent = nil
                    }
                case "Type/Storyline":
                    if let sl = curStoryline {
                        storylines.append(sl)
                        curStoryline = nil
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
        if parser.parse(), p.isOutlineBlock {
            return p.storylines
        }
        return nil
    }
}

struct OutlineAdjustView: View {
    @Binding var storylines: [StorylineData]

    @State private var selectedStorylineID: UUID? = nil
    @State private var selectedEventID: UUID? = nil
    @State private var selectedSceneID: UUID? = nil

    @State private var editingStorylineID: UUID? = nil
    @State private var editingEventID: UUID? = nil
    @State private var editingSceneID: UUID? = nil

    @State private var newStorylineName: String = ""
    @State private var newEventName: String = ""
    @State private var newSceneName: String = ""

    @State private var newPerson: String = ""
    @State private var newItem: String = ""
    @State private var newDoing: String = ""

    @State private var newStorylinePerson: String = "" // for 大箱
    @State private var newStorylineItem: String = ""
    @State private var newEventPerson: String = "" // for 中箱
    @State private var newEventItem: String = ""

    private var selectedStorylineIndex: Int? {
        guard let id = selectedStorylineID else { return nil }
        return storylines.firstIndex(where: { $0.id == id })
    }
    private var selectedEventIndex: Int? {
        guard let si = selectedStorylineIndex, let id = selectedEventID else { return nil }
        return storylines[si].Scenes.firstIndex(where: { $0.id == id })
    }
    private var selectedSceneIndex: Int? {
        guard let si = selectedStorylineIndex,
              let ei = selectedEventIndex,
              let id = selectedSceneID else { return nil }
        return storylines[si].Scenes[ei].Scenes.firstIndex(where: { $0.id == id })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: - 大箱（故事線）列表
                VStack(alignment: .leading, spacing: 8) {
                    Text("大箱（故事線）")
                        .font(.title2).bold()

                    List {
                        ForEach(storylines) { line in
                            storylineRow(line)
                                .listRowBackground(
                                    (line.id == selectedStorylineID) ? Color.accentColor.opacity(0.12) : Color.clear
                                )
                                .onDrop(of: [UTType.plainText.identifier], isTargeted: nil) { providers in
                                    handleDropToStoryline(providers: providers, toStorylineID: line.id)
                                }
                        }
                        .onMove { indices, newOffset in
                            moveStorylines(indices: indices, newOffset: newOffset)
                        }
                    }
                    .frame(minHeight: 200)

                    HStack {
                        TextField("新增故事線名稱", text: $newStorylineName)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            addStoryline()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("新增故事線")
                    }

                    if let si = selectedStorylineIndex {
                        DisclosureGroup("大箱內容（故事線細節）") {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("故事線名稱", text: Binding(
                                    get: { storylines[si].StorylineName },
                                    set: { storylines[si].StorylineName = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                Text("標記")
                                TextField("標記（例如：轉、衝突）", text: Binding(
                                    get: { storylines[si].StorylineType },
                                    set: { storylines[si].StorylineType = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)

                                tagListEditor(title: "預設人物", items: Binding(
                                    get: { storylines[si].people },
                                    set: { storylines[si].people = $0 }
                                ), newText: $newStorylinePerson)

                                tagListEditor(title: "預設物件", items: Binding(
                                    get: { storylines[si].item },
                                    set: { storylines[si].item = $0 }
                                ), newText: $newStorylineItem)

                                Text("備註")
                                TextEditor(text: Binding(
                                    get: { storylines[si].Memo },
                                    set: { storylines[si].Memo = $0 }
                                ))
                                .frame(minHeight: 80)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                            }
                            .padding(.top, 4)
                        }
                        .padding(.top, 4)
                        Text("""
                            大箱：
                            故事的大致走向。
                            標記可以使用「三幕劇」、「起承轉合」、「故事七步驟」等結構
                            """).font(.system(size: 12, weight: .light))
                    }
                }

                Divider().padding(.vertical, 10)

                // MARK: - 中箱（事件）列表
                VStack(alignment: .leading, spacing: 8) {
                    Text("中箱（事件）")
                        .font(.title2).bold()

                    if let si = selectedStorylineIndex {
                        let events = storylines[si].Scenes
                        List {
                            ForEach(events) { ev in
                                eventRow(ev, inStoryline: si)
                                    .listRowBackground(
                                        (ev.id == selectedEventID) ? Color.accentColor.opacity(0.12) : Color.clear
                                    )
                                    .onDrop(of: [UTType.plainText.identifier], isTargeted: nil) { providers in
                                        handleDropToEvent(providers: providers, destStorylineIndex: si, toEventID: ev.id)
                                    }
                            }
                            .onMove { indices, newOffset in
                                moveEvents(inStoryline: si, indices: indices, newOffset: newOffset)
                            }
                        }
                        .frame(minHeight: 200)

                        HStack {
                            TextField("新增事件名稱", text: $newEventName)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                addEvent(toStoryline: si)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("新增事件")
                        }

                        if let ei = selectedEventIndex {
                            DisclosureGroup("中箱內容（事件細節）") {
                                VStack(alignment: .leading, spacing: 8) {
                                    TextField("事件名稱", text: Binding(
                                        get: { storylines[si].Scenes[ei].StoryEvent },
                                        set: { storylines[si].Scenes[ei].StoryEvent = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)

                                    tagListEditor(title: "預設人物", items: Binding(
                                        get: { storylines[si].Scenes[ei].people },
                                        set: { storylines[si].Scenes[ei].people = $0 }
                                    ), newText: $newEventPerson)

                                    tagListEditor(title: "預設物件", items: Binding(
                                        get: { storylines[si].Scenes[ei].item },
                                        set: { storylines[si].Scenes[ei].item = $0 }
                                    ), newText: $newEventItem)

                                    Text("備註")
                                    TextEditor(text: Binding(
                                        get: { storylines[si].Scenes[ei].Memo },
                                        set: { storylines[si].Scenes[ei].Memo = $0 }
                                    ))
                                    .frame(minHeight: 80)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                                }
                                .padding(.top, 6)
                            }
                            .padding(.top, 4)
                        }
                    } else {
                        Text("請先選擇一個故事線")
                            .foregroundStyle(.secondary)
                            .frame(minHeight: 200)
                    }
                    Text("""
                        中箱：
                        故事的事件。
                        """).font(.system(size: 12, weight: .light))
                }

                Divider().padding(.vertical, 10)

                // MARK: - 小箱（場景）列表
                VStack(alignment: .leading, spacing: 8) {
                    Text("小箱（場景）")
                        .font(.title2).bold()

                    if let si = selectedStorylineIndex, let ei = selectedEventIndex {
                        let scenes = storylines[si].Scenes[ei].Scenes
                        List {
                            ForEach(scenes) { sc in
                                sceneRow(sc, inStoryline: si, inEvent: ei)
                                    .listRowBackground(
                                        (sc.id == selectedSceneID) ? Color.accentColor.opacity(0.12) : Color.clear
                                    )
                            }
                            .onMove { indices, newOffset in
                                moveScenes(inStoryline: si, inEvent: ei, indices: indices, newOffset: newOffset)
                            }
                        }
                        .frame(minHeight: 220)

                        HStack {
                            TextField("新增場景名稱", text: $newSceneName)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                addScene(toStoryline: si, toEvent: ei)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("新增場景")
                        }

                        if let ci = selectedSceneIndex {
                            DisclosureGroup("小箱內容（場景細節）") {
                                VStack(alignment: .leading, spacing: 10) {
                                    TextField("場景名稱", text: Binding(
                                        get: { storylines[si].Scenes[ei].Scenes[ci].SceneName },
                                        set: { storylines[si].Scenes[ei].Scenes[ci].SceneName = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)

                                    HStack {
                                        TextField("時間", text: Binding(
                                            get: { storylines[si].Scenes[ei].Scenes[ci].time },
                                            set: { storylines[si].Scenes[ei].Scenes[ci].time = $0 }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                        TextField("地點", text: Binding(
                                            get: { storylines[si].Scenes[ei].Scenes[ci].location },
                                            set: { storylines[si].Scenes[ei].Scenes[ci].location = $0 }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                    }

                                    tagListEditor(title: "人物", items: Binding(
                                        get: { storylines[si].Scenes[ei].Scenes[ci].people },
                                        set: { storylines[si].Scenes[ei].Scenes[ci].people = $0 }
                                    ), newText: $newPerson)

                                    tagListEditor(title: "物件", items: Binding(
                                        get: { storylines[si].Scenes[ei].Scenes[ci].item },
                                        set: { storylines[si].Scenes[ei].Scenes[ci].item = $0 }
                                    ), newText: $newItem)

                                    tagListEditor(title: "行動", items: Binding(
                                        get: { storylines[si].Scenes[ei].Scenes[ci].doingThings },
                                        set: { storylines[si].Scenes[ei].Scenes[ci].doingThings = $0 }
                                    ), newText: $newDoing)

                                    Text("備註")
                                    TextEditor(text: Binding(
                                        get: { storylines[si].Scenes[ei].Scenes[ci].Memo },
                                        set: { storylines[si].Scenes[ei].Scenes[ci].Memo = $0 }
                                    ))
                                    .frame(minHeight: 80)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                                }
                                .padding(.top, 6)
                            }
                            .padding(.top, 4)
                        }
                    } else {
                        Text("請先選擇一個事件")
                            .foregroundStyle(.secondary)
                            .frame(minHeight: 220)
                    }
                    Text("""
                        小箱：
                        事件的詳細場景。
                        """).font(.system(size: 12, weight: .light))
                }
            }
            .padding()
        }
        .onAppear {
            if selectedStorylineID == nil {
                selectedStorylineID = storylines.first?.id
            }
            if let si = selectedStorylineIndex {
                if selectedEventID == nil {
                    selectedEventID = storylines[si].Scenes.first?.id
                }
                if let ei = selectedEventIndex, selectedSceneID == nil {
                    selectedSceneID = storylines[si].Scenes[ei].Scenes.first?.id
                }
            }
        }
    }

    // MARK: - Row Builders

    @ViewBuilder
    private func storylineRow(_ line: StorylineData) -> some View {
        let isEditing = (editingStorylineID == line.id)
        HStack(spacing: 8) {
            if isEditing, let idx = storylines.firstIndex(where: { $0.id == line.id }) {
                TextField("故事線名稱", text: Binding(
                    get: { storylines[idx].StorylineName },
                    set: { storylines[idx].StorylineName = $0 }
                ), onCommit: {
                    editingStorylineID = nil
                })
                .textFieldStyle(.roundedBorder)
                .onSubmit { editingStorylineID = nil }
            } else {
                Text(line.StorylineName.isEmpty ? "(未命名故事線)" : line.StorylineName)
            }
            Spacer()
            Button {
                editingStorylineID = line.id
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help("重新命名")
            Button {
                deleteStoryline(line.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
                editingStorylineID = line.id
            }
        )
        .onTapGesture {
            selectedStorylineID = line.id
            if let si = selectedStorylineIndex {
                selectedEventID = storylines[si].Scenes.first?.id
                if let ei = selectedEventIndex {
                    selectedSceneID = storylines[si].Scenes[ei].Scenes.first?.id
                } else {
                    selectedSceneID = nil
                }
            }
        }
    }

    @ViewBuilder
    private func eventRow(_ ev: StoryEventData, inStoryline si: Int) -> some View {
        let isEditing = (editingEventID == ev.id)
        HStack(spacing: 8) {
            if isEditing, let idx = storylines[si].Scenes.firstIndex(where: { $0.id == ev.id }) {
                TextField("事件名稱", text: Binding(
                    get: { storylines[si].Scenes[idx].StoryEvent },
                    set: { storylines[si].Scenes[idx].StoryEvent = $0 }
                ), onCommit: {
                    editingEventID = nil
                })
                .textFieldStyle(.roundedBorder)
                .onSubmit { editingEventID = nil }
            } else {
                Text(ev.StoryEvent.isEmpty ? "(未命名事件)" : ev.StoryEvent)
            }
            Spacer()
            Button {
                editingEventID = ev.id
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help("重新命名")
            Button {
                deleteEvent(ev.id, inStoryline: si)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
                editingEventID = ev.id
            }
        )
        .onTapGesture {
            selectedStorylineID = storylines[si].id
            selectedEventID = ev.id
            selectedSceneID = ev.Scenes.first?.id
        }
        .onDrag {
            NSItemProvider(object: DragPayload.eventString(ev.id) as NSString)
        }
    }

    @ViewBuilder
    private func sceneRow(_ sc: SceneData, inStoryline si: Int, inEvent ei: Int) -> some View {
        let isEditing = (editingSceneID == sc.id)
        HStack(spacing: 8) {
            if isEditing, let idx = storylines[si].Scenes[ei].Scenes.firstIndex(where: { $0.id == sc.id }) {
                TextField("場景名稱", text: Binding(
                    get: { storylines[si].Scenes[ei].Scenes[idx].SceneName },
                    set: { storylines[si].Scenes[ei].Scenes[idx].SceneName = $0 }
                ), onCommit: {
                    editingSceneID = nil
                })
                .textFieldStyle(.roundedBorder)
                .onSubmit { editingSceneID = nil }
            } else {
                Text(sc.SceneName.isEmpty ? "(未命名場景)" : sc.SceneName)
            }
            Spacer()
            Button {
                editingSceneID = sc.id
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help("重新命名")
            Button {
                deleteScene(sc.id, inStoryline: si, inEvent: ei)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture(count: 2).onEnded {
                editingSceneID = sc.id
            }
        )
        .onTapGesture {
            selectedStorylineID = storylines[si].id
            selectedEventID = storylines[si].Scenes[ei].id
            selectedSceneID = sc.id
        }
        .onDrag {
            NSItemProvider(object: DragPayload.sceneString(sc.id) as NSString)
        }
    }

    // MARK: - 小型編輯元件

    private func tagListEditor(title: String, items: Binding<[String]>, newText: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
            ForEach(Array(items.wrappedValue.enumerated()), id: \.offset) { idx, value in
                HStack {
                    Text(value)
                    Spacer()
                    Button {
                        var arr = items.wrappedValue
                        arr.remove(at: idx)
                        items.wrappedValue = arr
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                Divider()
            }
            HStack {
                TextField("新增\(title)", text: newText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    let v = newText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !v.isEmpty else { return }
                    var arr = items.wrappedValue
                    arr.append(v)
                    items.wrappedValue = arr
                    newText.wrappedValue = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("新增\(title)")
            }
        }
    }

    // MARK: - 新增

    private func addStoryline() {
        let name = newStorylineName.trimmingCharacters(in: .whitespacesAndNewlines)
        let final = name.isEmpty ? "故事線 \(storylines.count + 1)" : name
        let id = UUID()
        storylines.append(StorylineData(StorylineName: final, StorylineType: "", Scenes: [], Memo: "", people: [], item: [], ChapterUUID: id))
        selectedStorylineID = id
        selectedEventID = nil
        selectedSceneID = nil
        newStorylineName = ""
    }

    private func addEvent(toStoryline si: Int) {
        guard storylines.indices.contains(si) else { return }
        let name = newEventName.trimmingCharacters(in: .whitespacesAndNewlines)
        let final = name.isEmpty ? "事件 \(storylines[si].Scenes.count + 1)" : name
        let ev = StoryEventData(
            StoryEvent: final,
            Scenes: [],
            Memo: "",
            people: storylines[si].people, // 繼承大箱
            item: storylines[si].item,     // 繼承大箱
            StoryEventUUID: UUID()
        )
        storylines[si].Scenes.append(ev)
        selectedStorylineID = storylines[si].id
        selectedEventID = ev.id
        selectedSceneID = nil
        newEventName = ""
    }

    private func addScene(toStoryline si: Int, toEvent ei: Int) {
        guard storylines.indices.contains(si),
              storylines[si].Scenes.indices.contains(ei) else { return }
        let name = newSceneName.trimmingCharacters(in: .whitespacesAndNewlines)
        let final = name.isEmpty ? "場景 \(storylines[si].Scenes[ei].Scenes.count + 1)" : name
        let sc = SceneData(
            SceneName: final,
            people: storylines[si].Scenes[ei].people, // 繼承中箱
            item: storylines[si].Scenes[ei].item      // 繼承中箱
        )
        storylines[si].Scenes[ei].Scenes.append(sc)
        selectedStorylineID = storylines[si].id
        selectedEventID = storylines[si].Scenes[ei].id
        selectedSceneID = sc.id
        newSceneName = ""
    }

    // MARK: - 刪除
    private func deleteStoryline(_ id: UUID) {
        guard let idx = storylines.firstIndex(where: { $0.id == id }) else { return }
        storylines.remove(at: idx)
        selectedStorylineID = storylines.first?.id
        if let si = selectedStorylineIndex {
            selectedEventID = storylines[si].Scenes.first?.id
            if let ei = selectedEventIndex {
                selectedSceneID = storylines[si].Scenes[ei].Scenes.first?.id
            } else {
                selectedSceneID = nil
            }
        } else {
            selectedEventID = nil
            selectedSceneID = nil
        }
    }

    private func deleteEvent(_ id: UUID, inStoryline si: Int) {
        guard storylines.indices.contains(si),
              let idx = storylines[si].Scenes.firstIndex(where: { $0.id == id }) else { return }
        storylines[si].Scenes.remove(at: idx)
        selectedStorylineID = storylines[si].id
        selectedEventID = storylines[si].Scenes.first?.id
        if let ei = selectedEventIndex {
            selectedSceneID = storylines[si].Scenes[ei].Scenes.first?.id
        } else {
            selectedSceneID = nil
        }
    }

    private func deleteScene(_ id: UUID, inStoryline si: Int, inEvent ei: Int) {
        guard storylines.indices.contains(si),
              storylines[si].Scenes.indices.contains(ei),
              let idx = storylines[si].Scenes[ei].Scenes.firstIndex(where: { $0.id == id }) else { return }
        storylines[si].Scenes[ei].Scenes.remove(at: idx)
        selectedStorylineID = storylines[si].id
        selectedEventID = storylines[si].Scenes[ei].id
        selectedSceneID = storylines[si].Scenes[ei].Scenes.first?.id
    }

    // MARK: - 重新排序
    private func moveStorylines(indices: IndexSet, newOffset: Int) {
        storylines.move(fromOffsets: indices, toOffset: newOffset)
    }
    private func moveEvents(inStoryline si: Int, indices: IndexSet, newOffset: Int) {
        guard storylines.indices.contains(si) else { return }
        storylines[si].Scenes.move(fromOffsets: indices, toOffset: newOffset)
    }
    private func moveScenes(inStoryline si: Int, inEvent ei: Int, indices: IndexSet, newOffset: Int) {
        guard storylines.indices.contains(si),
              storylines[si].Scenes.indices.contains(ei) else { return }
        storylines[si].Scenes[ei].Scenes.move(fromOffsets: indices, toOffset: newOffset)
    }

    // MARK: - 拖放處理
    private func handleDropToStoryline(providers: [NSItemProvider], toStorylineID destID: UUID) -> Bool {
        for p in providers where p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            p.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (item, _) in
                var raw: String?
                if let s = item as? String {
                    raw = s
                } else if let data = item as? Data, let s = String(data: data, encoding: .utf8) {
                    raw = s
                }
                guard let str = raw, str.hasPrefix(DragPayload.eventPrefix) else { return }
                let idStr = String(str.dropFirst(DragPayload.eventPrefix.count))
                guard let evID = UUID(uuidString: idStr) else { return }
                DispatchQueue.main.async {
                    self.moveEvent(eventID: evID, toStorylineID: destID)
                }
            }
        }
        return true
    }
    private func handleDropToEvent(providers: [NSItemProvider], destStorylineIndex si: Int, toEventID destEventID: UUID) -> Bool {
        for p in providers where p.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            p.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { (item, _) in
                var raw: String?
                if let s = item as? String {
                    raw = s
                } else if let data = item as? Data, let s = String(data: data, encoding: .utf8) {
                    raw = s
                }
                guard let str = raw, str.hasPrefix(DragPayload.scenePrefix) else { return }
                let idStr = String(str.dropFirst(DragPayload.scenePrefix.count))
                guard let scID = UUID(uuidString: idStr) else { return }
                DispatchQueue.main.async {
                    self.moveScene(sceneID: scID, toStorylineIndex: si, toEventID: destEventID)
                }
            }
        }
        return true
    }
    private func moveEvent(eventID: UUID, toStorylineID destID: UUID) {
        var fromSi: Int?
        var fromEi: Int?
        for (si, line) in storylines.enumerated() {
            if let ei = line.Scenes.firstIndex(where: { $0.id == eventID }) {
                fromSi = si
                fromEi = ei
                break
            }
        }
        guard let fsi = fromSi, let fei = fromEi,
              let dsi = storylines.firstIndex(where: { $0.id == destID }) else { return }
        if fsi == dsi { return }
        let moving = storylines[fsi].Scenes[fei]
        storylines[fsi].Scenes.remove(at: fei)
        storylines[dsi].Scenes.append(moving)
        selectedStorylineID = storylines[dsi].id
        selectedEventID = moving.id
        selectedSceneID = moving.Scenes.first?.id
    }
    private func moveScene(sceneID: UUID, toStorylineIndex dsi: Int, toEventID destEventID: UUID) {
        var fromSi: Int?
        var fromEi: Int?
        var fromCi: Int?
        for (si, line) in storylines.enumerated() {
            for (ei, ev) in line.Scenes.enumerated() {
                if let ci = ev.Scenes.firstIndex(where: { $0.id == sceneID }) {
                    fromSi = si; fromEi = ei; fromCi = ci
                    break
                }
            }
        }
        guard let fsi = fromSi, let fei = fromEi, let fci = fromCi else { return }
        guard storylines.indices.contains(dsi),
              let dei = storylines[dsi].Scenes.firstIndex(where: { $0.id == destEventID }) else { return }
        if fsi == dsi && fei == dei { return }
        let moving = storylines[fsi].Scenes[fei].Scenes[fci]
        storylines[fsi].Scenes[fei].Scenes.remove(at: fci)
        storylines[dsi].Scenes[dei].Scenes.append(moving)
        selectedStorylineID = storylines[dsi].id
        selectedEventID = storylines[dsi].Scenes[dei].id
        selectedSceneID = moving.id
    }
}

// 使用 Binding 預覽
#Preview {
    @State var data: [StorylineData] = [
        StorylineData(
            StorylineName: "主線 1",
            StorylineType: "起",
            Scenes: [
                StoryEventData(
                    StoryEvent: "事件 1",
                    Scenes: [
                        SceneData(SceneName: "場景 A"),
                        SceneData(SceneName: "場景 B")
                    ],
                    Memo: ""
                )
            ],
            Memo: ""
        )
    ]
    return OutlineAdjustView(storylines: $data)
}
