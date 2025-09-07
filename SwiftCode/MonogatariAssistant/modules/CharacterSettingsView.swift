//
//  CharacterSettingsView.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/8/29.
//

import SwiftUI

// MARK: - LazyDisclosureSection（折疊時完全不建構內容，展開才建構）
public struct LazyDisclosureSection<Header: View, Content: View>: View {
    @Binding private var isExpanded: Bool
    private let animated: Bool
    private let header: () -> Header
    private let content: () -> Content

    public init(
        isExpanded: Binding<Bool>,
        animated: Bool = false,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isExpanded = isExpanded
        self.animated = animated
        self.header = header
        self.content = content
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: toggle) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundStyle(.secondary)
                    header()
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
            }
        }
    }

    private func toggle() {
        if animated {
            withAnimation(.default) { isExpanded.toggle() }
        } else {
            isExpanded.toggle()
        }
    }
}

// MARK: - 資料模型（與主程式共享）

struct CharacterProfile: Identifiable, Equatable {
    struct Relation: Identifiable, Equatable {
        var id = UUID()
        var name: String = ""
        var relation: String = ""
    }
    struct Hinder: Identifiable, Equatable {
        var id = UUID()
        var event: String = ""
        var solve: String = ""
    }

    // 重要資訊
    var id = UUID()
    var surname: String = ""
    var firstName: String = ""
    var gender: String = ""
    var age: String = ""
    var birthMonth: String = ""
    var birthDay: String = ""
    var role: String = ""

    // 詳細資訊 - 基本資料
    var ethnicity: String = ""
    var nation: String = ""
    var home: String = ""
    var occupation: String = ""
    var education: String = ""
    var economic: String = ""
    var mantra: String = ""
    var motto: String = ""
    var nicknames: [String] = []

    // 性取向
    enum Sexual: String, CaseIterable, Identifiable { case same = "同性戀", opposite = "異性戀", other = "其它"; var id: String { rawValue } }
    var sexual: Sexual = .opposite
    var sexualOther: String = ""

    // 戀愛關係
    enum LoveStatus: String, CaseIterable, Identifiable {
        case single = "單身", married = "已婚/準備結婚", dating = "戀愛中/準備戀愛", widowed = "喪偶", other = "其他"
        var id: String { rawValue }
    }
    var loveStatus: LoveStatus = .single
    var loveOther: String = ""
    var isFindNewLove: Bool = false
    var isHarem: Bool = false

    // 與其他角色的關係
    var relations: [Relation] = []

    // 標籤
    var tags: [String] = []

    // 代表元素（顏色省略外部存檔）
    var representColor1: Color = .accentColor
    var representColor2: Color = .secondary
    var representItem: String = ""

    // 身體（字串）
    var heightText: String = ""   // 例如：143.5cm
    var weightText: String = ""   // 例如：34.6kg

    // 身體屬性（0...100）
    var figure: Int = 50          // 瘦弱 ←→ 敦實
    var looks: Int = 50           // 低 ←→ 高
    var temperature: Int = 50     // 低 ←→ 高
    var bodyPower: Int = 50       // 低 ←→ 高

    // 聲音（0...100）
    var soundVolume: Int = 50     // 小聲 ←→ 大聲
    var voicePitch: Int = 50      // 低沉 ←→ 高昂

    // 慣用手
    enum PreferredHand: String, CaseIterable, Identifiable { case left = "左手", right = "右手", other = "其他"; var id: String { rawValue } }
    var hand: PreferredHand = .right
    var handOther: String = ""    // 例如：雙手皆可

    // 視力
    enum Eyesight: String, CaseIterable, Identifiable {
        case great = "極好", normal = "正常", amblyopia = "弱視", impaired = "視力受損"
        case oneBlindOtherOK = "單眼失明、另眼正常", oneBlindOtherBad = "單眼失明、另眼受損"
        case totalBlind = "全盲", other = "其他"
        var id: String { rawValue }
    }
    var eyesight: Eyesight = .normal
    var eyesightOther: String = "" // 例如：使用義眼

    // 健康（複選）
    var healthGood: Bool = false
    var healthWeak: Bool = false
    var healthOld: Bool = false
    var healthSpecialDisease: Bool = false
    var healthMentalIssue: Bool = false
    var healthOtherChecked: Bool = false
    var healthSpecialDiseaseText: String = ""   // 例如：白血病、漸凍症
    var healthMentalIssueText: String = ""      // 例如：思覺失調、PTSD、失智
    var healthOtherText: String = ""            // 其他問題

    // 色票（外部存檔略）
    var hairColor1: Color = .black
    var hairColor2: Color = .gray
    var eyeColor1: Color = .brown
    var eyeColor2: Color = .blue
    var skinColor1: Color = .init(red: 1.0, green: 0.88, blue: 0.75)
    var skinColor2: Color = .init(red: 0.95, green: 0.8, blue: 0.65)
    var customColor1Name: String = "自訂項目1"
    var customColor1A: Color = .purple
    var customColor1B: Color = .pink
    var customColor2Name: String = "自訂項目2"
    var customColor2A: Color = .mint
    var customColor2B: Color = .teal

    // 身體補充
    var bodyComplement: String = ""

    // 人物個性
    var personalityDesc: String = ""
    var experiencesDesc: String = ""

    // MBTI（0...100）：E/I、N/S、T/F、J/P、A/T
    var mbtiEI: Int = 50
    var mbtiNS: Int = 50
    var mbtiTF: Int = 50
    var mbtiJP: Int = 50
    var mbtiAT: Int = 50
    var mbtiString: String {
        "\(mbtiEI > 50 ? "I" : "E")\(mbtiNS > 50 ? "N" : "S")\(mbtiTF > 50 ? "F" : "T")\(mbtiJP > 50 ? "P" : "J")-\(mbtiAT > 50 ? "T" : "A")"
    }

    // 行事作風（Approach，0...100）— 12 組
    var approach: [Int] = Array(repeating: 50, count: 12)

    // 性格特質（15 組 0...100）
    var traits: [Int] = Array(repeating: 50, count: 15)

    var personalityOther: String = ""

    // 道德觀＆價值觀
    var tendency: Int = 50 // 利己-利他
    enum Alignment9: String, CaseIterable, Identifiable {
        case lawfulGood = "守序\n善良", neutralGood = "中立\n善良", chaoticGood = "混亂\n善良"
        case lawfulNeutral = "守序\n中立", trueNeutral = "絕對\n中立", chaoticNeutral = "混亂\n中立"
        case lawfulEvil = "守序\n邪惡", neutralEvil = "中立\n邪惡", chaoticEvil = "絕對\n邪惡"
        var id: String { rawValue }
    }
    var alignment9: Alignment9 = .neutralGood

    var belief: String = ""
    var characterLimit: String = ""
    var inFuture: String = ""
    var mostCherish: String = ""
    var mostDisgust: String = ""
    var mostFear: String = ""
    var mostCurious: String = ""
    var mostExpect: String = ""

    var hinders: [Hinder] = []
    var valuesOther: String = ""

    // 能力＆才華
    var loveToDo: [String] = []
    var hateToDo: [String] = []
    var proficientToDo: [String] = []
    var unProficientToDo: [String] = []

    // 生活常用技能（16 組 0...100）
    var commonAbilities: [Int] = Array(repeating: 50, count: 16)

    // 社交相關
    var impression: String = ""
    var mostLikable: String = ""
    var nativeFamily: String = ""

    // 如何表達「喜歡」
    var showLoveLanguage: Bool = false
    var showLoveAccompany: Bool = false
    var showLoveGift: Bool = false
    var showLoveService: Bool = false
    var showLoveTouch: Bool = false
    var showLoveTease: Bool = false
    var showLoveSelf: Bool = false
    var showLoveAvoid: Bool = false
    var showLoveOther: Bool = false
    var showLoveOtherText: String = ""

    // 如何表達好意
    var goodwillLanguage: Bool = false
    var goodwillAccompany: Bool = false
    var goodwillGift: Bool = false
    var goodwillService: Bool = false
    var goodwillTouch: Bool = false
    var goodwillOther: Bool = false
    var goodwillOtherText: String = ""

    // 如何應對討厭的人
    var hateBadWords: Bool = false
    var hateViolence: Bool = false
    var hateTrick: Bool = false
    var hateSneaky: Bool = false
    var hateAvoid: Bool = false
    var hateIndifferent: Bool = false
    var hateRepayKindness: Bool = false
    var hateNoDifference: Bool = false
    var hateOther: Bool = false
    var hateOtherText: String = ""

    // 社交項目（10 組 0...100）
    var socialScales: [Int] = Array(repeating: 50, count: 10)

    // 其他
    var originalName: String = ""
    var likeItems: [String] = []
    var hateItems: [String] = []
    var familiarItems: [String] = []
    var otherText: String = ""
}

// MARK: - 元件

struct ScaleRow: View {
    var title: String
    var left: String
    var right: String
    @Binding var value: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).bold()
            HStack(spacing: 8) {
                Text(left).font(.caption).frame(width: 42, alignment: .leading)
                Slider(value: Binding(get: { Double(value) }, set: { value = Int(round($0)) }), in: 0...100, step: 1)
                Text(right).font(.caption).frame(width: 42, alignment: .trailing)
            }
            HStack { Spacer(); Text("\(value)").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
        }
    }
}

struct ListEditor: View {
    let placeholder: String
    @Binding var items: [String]
    @State private var temp: String = ""
    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, val in
                HStack {
                    Text(val)
                    Spacer()
                    Button {
                        items.remove(at: idx)
                    } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                    .buttonStyle(.plain)
                }
                Divider()
            }
            HStack {
                TextField(placeholder, text: $temp).textFieldStyle(.roundedBorder)
                Button {
                    let v = temp.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !v.isEmpty else { return }
                    items.append(v)
                    temp = ""
                } label: { Image(systemName: "plus.circle.fill").foregroundStyle(.green) }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct RelationEditor: View {
    @Binding var rows: [CharacterProfile.Relation]
    @State private var name: String = ""
    @State private var role: String = ""
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("角色").frame(maxWidth: .infinity, alignment: .leading).font(.caption).foregroundStyle(.secondary)
                Text("關係").frame(maxWidth: .infinity, alignment: .leading).font(.caption).foregroundStyle(.secondary)
                Spacer().frame(width: 24)
            }
            ForEach($rows) { $r in
                HStack {
                    TextField("角色", text: $r.name).textFieldStyle(.roundedBorder)
                    TextField("關係", text: $r.relation).textFieldStyle(.roundedBorder)
                    Button {
                        rows.removeAll { $0.id == r.id }
                    } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                TextField("角色", text: $name).textFieldStyle(.roundedBorder)
                TextField("關係", text: $role).textFieldStyle(.roundedBorder)
                Button {
                    let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let rr = role.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !n.isEmpty || !rr.isEmpty else { return }
                    rows.append(.init(name: n, relation: rr))
                    name = ""; role = ""
                } label: { Image(systemName: "plus.circle.fill").foregroundStyle(.green) }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct HinderEditor: View {
    @Binding var rows: [CharacterProfile.Hinder]
    @State private var event: String = ""
    @State private var solve: String = ""
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("阻礙事件").frame(maxWidth: .infinity, alignment: .leading).font(.caption).foregroundStyle(.secondary)
                Text("解決方式").frame(maxWidth: .infinity, alignment: .leading).font(.caption).foregroundStyle(.secondary)
                Spacer().frame(width: 24)
            }
            ForEach($rows) { $r in
                HStack {
                    TextField("阻礙", text: $r.event).textFieldStyle(.roundedBorder)
                    TextField("解決", text: $r.solve).textFieldStyle(.roundedBorder)
                    Button {
                        rows.removeAll { $0.id == r.id }
                    } label: { Image(systemName: "minus.circle.fill").foregroundStyle(.red) }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                TextField("阻礙", text: $event).textFieldStyle(.roundedBorder)
                TextField("解決", text: $solve).textFieldStyle(.roundedBorder)
                Button {
                    let e = event.trimmingCharacters(in: .whitespacesAndNewlines)
                    let s = solve.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !e.isEmpty || !s.isEmpty else { return }
                    rows.append(.init(event: e, solve: s))
                    event = ""; solve = ""
                } label: { Image(systemName: "plus.circle.fill").foregroundStyle(.green) }
                .buttonStyle(.borderless)
            }
        }
    }
}

@ViewBuilder
private func AlignmentGrid(selection: Binding<CharacterProfile.Alignment9>) -> some View {
    let rows: [[CharacterProfile.Alignment9]] = [
        [.lawfulGood, .neutralGood, .chaoticGood],
        [.lawfulNeutral, .trueNeutral, .chaoticNeutral],
        [.lawfulEvil, .neutralEvil, .chaoticEvil]
    ]
    VStack(spacing: 8) {
        ForEach(0..<3, id: \.self) { r in
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { c in
                    let val = rows[r][c]
                    Button {
                        selection.wrappedValue = val
                    } label: {
                        Text(val.rawValue)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selection.wrappedValue == val ? Color.accentColor.opacity(0.2) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selection.wrappedValue == val ? Color.accentColor : .secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - 主視圖（以 LazyDisclosureSection 降低折疊開銷）

struct CharacterSettingsView: View {
    // 接入主程式：由 ContentView 持有，這裡用 Binding
    @Binding var characters: [CharacterProfile]
    @State private var selectedID: CharacterProfile.ID? = nil

    // 模板（暫提供空白選項）
    @State private var templates: [String] = ["空白"]
    @State private var selectedTemplate: String = "空白"

    // 折疊狀態（預設全部折疊以省 CPU）
    @State private var expand_basic: Bool = false
    @State private var expand_body: Bool = false
    @State private var expand_personality: Bool = false
    @State private var expand_values: Bool = false
    @State private var expand_ability: Bool = false
    @State private var expand_social: Bool = false
    @State private var expand_other: Bool = false

    private var selectedIndex: Int? {
        guard let id = selectedID else { return characters.indices.first }
        return characters.firstIndex { $0.id == id } ?? characters.indices.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("角色編輯").font(.largeTitle.bold())

                // 角色列表
                groupBox("角色列表") {
                    VStack(spacing: 8) {
                        List(selection: Binding(get: {
                            selectedID.map { Set([$0]) } ?? Set<CharacterProfile.ID>()
                        }, set: { sel in
                            selectedID = sel.first ?? characters.first?.id
                        })) {
                            ForEach(characters) { ch in
                                Text(displayName(ch)).tag(ch.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedID = ch.id }
                            }
                            .onDelete { idx in deleteCharacters(at: idx) }
                        }
                        .frame(minHeight: 160)

                        HStack(spacing: 6) {
                            Button {
                                addCharacter()
                            } label: {
                                Label("新增", systemImage: "plus.circle.fill").labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                if let idx = selectedIndex {
                                    characters.remove(at: idx)
                                    selectedID = characters.first?.id
                                }
                            } label: {
                                Label("刪除", systemImage: "minus.circle.fill").labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)
                            .disabled(characters.isEmpty)
                        }
                    }
                }

                // 套用模板
                HStack(spacing: 8) {
                    Text("套用模板：").font(.subheadline)
                    Picker("", selection: $selectedTemplate) {
                        ForEach(templates, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                    Button("生效") { applyTemplate() }
                        .buttonStyle(.bordered)
                }

                Divider().padding(.vertical, 4)

                if let idx = selectedIndex {
                    let b = $characters[idx]

                    // 角色編輯（重要資訊）— 小區塊
                    groupBox("角色編輯") {
                        Text("重要資訊").font(.title3.bold())
                        VStack(alignment: .leading, spacing: 8) {
                            Text("姓名：")
                            HStack(spacing: 8) {
                                TextField("姓氏", text: b.surname).textFieldStyle(.roundedBorder)
                                TextField("名稱", text: b.firstName).textFieldStyle(.roundedBorder)
                            }
                            Text("性別：")
                            TextField("例如：女性、男Omega", text: b.gender).textFieldStyle(.roundedBorder)

                            Text("年齡：")
                            TextField("例如：6歲", text: b.age).textFieldStyle(.roundedBorder)

                            Text("生日：")
                            HStack {
                                TextField("月分", text: b.birthMonth).textFieldStyle(.roundedBorder)
                                Text("月")
                                Spacer().frame(width: 16)
                                TextField("日期", text: b.birthDay).textFieldStyle(.roundedBorder)
                                Text("日")
                            }

                            Text("在故事中扮演什麼角色？")
                            TextField("例如：主角、配角、反派", text: b.role).textFieldStyle(.roundedBorder)
                        }
                    }

                    // 基本資料
                    LazyDisclosureSection(isExpanded: $expand_basic) {
                        Text("基本資料").font(.title3.bold())
                    } content: {
                        VStack(alignment: .leading, spacing: 10) {
                            labeledTF("種族：", "例如：神族、黃人等", b.ethnicity)
                            labeledTF("國籍：", "例如：亞特蘭提斯", b.nation)
                            labeledTF("居住地點：", "角色居住的地方（例如：雲空府）", b.home)
                            labeledTF("職業：", "例如：繪師、雲空一高高二生", b.occupation)
                            labeledTF("教育程度：", "例如：高中、大學", b.education)
                            labeledTF("經濟狀況：", "例如：小康", b.economic)
                            labeledTF("口頭禪：", "例如：嘛～、雜魚～♡", b.mantra)
                            labeledTF("座右銘：", "例如：部屋居士", b.motto)

                            Text("角色的其他別稱")
                            ListEditor(placeholder: "例如：小羽", items: b.nicknames)

                            Divider()
                            Text("性取向").font(.headline)
                            Picker("", selection: b.sexual) {
                                ForEach(CharacterProfile.Sexual.allCases) { Text($0.rawValue).tag($0) }
                            }.pickerStyle(.segmented)
                            if b.sexual.wrappedValue == .other {
                                TextField("例如雙性戀、無性戀", text: b.sexualOther).textFieldStyle(.roundedBorder)
                            }

                            Divider()
                            Text("戀愛關係").font(.headline)
                            Picker("", selection: b.loveStatus) {
                                ForEach(CharacterProfile.LoveStatus.allCases) { Text($0.rawValue).tag($0) }
                            }.pickerStyle(.segmented)
                            if b.loveStatus.wrappedValue == .other {
                                HStack { Text("其他："); TextField("其他……", text: b.loveOther).textFieldStyle(.roundedBorder) }
                            }
                            Toggle("另尋新歡？", isOn: b.isFindNewLove)
                            Toggle("后宮型作品？", isOn: b.isHarem)

                            Divider()
                            Text("與其他角色的關係").font(.headline)
                            RelationEditor(rows: b.relations)

                            Divider()
                            Text("角色標籤").font(.headline)
                            ListEditor(placeholder: "標籤", items: b.tags)

                            Divider()
                            HStack {
                                Text("代表色：")
                                ColorPicker("", selection: b.representColor1).labelsHidden()
                                ColorPicker("", selection: b.representColor2).labelsHidden()
                                Spacer()
                            }
                            labeledTF("代表物：", "代表物", b.representItem)
                        }
                        .padding(.top, 4)
                    }

                    // 身體屬性
                    LazyDisclosureSection(isExpanded: $expand_body) {
                        Text("身體屬性").font(.title3.bold())
                    } content: {
                        VStack(alignment: .leading, spacing: 12) {
                            labeledTF("身高：", "例如：143.5cm", b.heightText)
                            labeledTF("體重：", "例如：34.6kg", b.weightText)

                            LazyVStack(spacing: 10) {
                                ScaleRow(title: "身材", left: "瘦弱", right: "敦實", value: b.figure)
                                ScaleRow(title: "外貌", left: "低", right: "高", value: b.looks)
                                ScaleRow(title: "體溫", left: "低", right: "高", value: b.temperature)
                                ScaleRow(title: "力量", left: "低", right: "高", value: b.bodyPower)
                                Text("聲音").font(.headline)
                                ScaleRow(title: "音量", left: "小聲", right: "大聲", value: b.soundVolume)
                                ScaleRow(title: "聲線", left: "低沉", right: "高昂", value: b.voicePitch)
                            }

                            Group {
                                Text("慣用手").font(.headline)
                                Picker("", selection: b.hand) {
                                    ForEach(CharacterProfile.PreferredHand.allCases) { Text($0.rawValue).tag($0) }
                                }.pickerStyle(.segmented)
                                if b.hand.wrappedValue == .other {
                                    TextField("例如：雙手皆可、雙手皆不可", text: b.handOther).textFieldStyle(.roundedBorder)
                                }
                            }

                            Group {
                                Text("視力狀況").font(.headline)
                                Picker("", selection: b.eyesight) {
                                    ForEach(CharacterProfile.Eyesight.allCases) { Text($0.rawValue).tag($0) }
                                }.pickerStyle(.inline)
                                if b.eyesight.wrappedValue == .other {
                                    TextField("例如：使用義眼", text: b.eyesightOther).textFieldStyle(.roundedBorder)
                                }
                            }

                            Group {
                                Text("健康狀況").font(.headline)
                                VStack(alignment: .leading) {
                                    Toggle("良好", isOn: b.healthGood)
                                    Toggle("病弱系", isOn: b.healthWeak)
                                    Toggle("年老體衰", isOn: b.healthOld)
                                    Toggle("特殊疾病", isOn: b.healthSpecialDisease)
                                    if b.healthSpecialDisease.wrappedValue {
                                        TextField("例如：白血病、漸凍症", text: b.healthSpecialDiseaseText).textFieldStyle(.roundedBorder)
                                    }
                                    Toggle("精神問題", isOn: b.healthMentalIssue)
                                    if b.healthMentalIssue.wrappedValue {
                                        TextField("例如：思覺失調、PTSD、失智", text: b.healthMentalIssueText).textFieldStyle(.roundedBorder)
                                    }
                                    Toggle("其他", isOn: b.healthOtherChecked)
                                    if b.healthOtherChecked.wrappedValue {
                                        TextField("其他問題", text: b.healthOtherText).textFieldStyle(.roundedBorder)
                                    }
                                }
                            }

                            Group {
                                Text("色票").font(.headline)
                                colorRow("髮色", b.hairColor1, b.hairColor2)
                                colorRow("瞳色", b.eyeColor1, b.eyeColor2)
                                colorRow("膚色", b.skinColor1, b.skinColor2)
                                HStack {
                                    TextField("自訂項目1", text: b.customColor1Name).textFieldStyle(.roundedBorder)
                                    ColorPicker("", selection: b.customColor1A).labelsHidden()
                                    ColorPicker("", selection: b.customColor1B).labelsHidden()
                                }
                                HStack {
                                    TextField("自訂項目2", text: b.customColor2Name).textFieldStyle(.roundedBorder)
                                    ColorPicker("", selection: b.customColor2A).labelsHidden()
                                    ColorPicker("", selection: b.customColor2B).labelsHidden()
                                }
                            }

                            Text("其他補充：")
                            TextEditor(text: b.bodyComplement)
                                .frame(minHeight: 80)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                        }
                        .padding(.top, 4)
                    }

                    // 人物個性
                    LazyDisclosureSection(isExpanded: $expand_personality) {
                        Text("人物個性").font(.title3.bold())
                    } content: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("簡述人物性格：")
                            TextEditor(text: b.personalityDesc)
                                .frame(minHeight: 80)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))

                            Text("簡述人物經歷：")
                            TextEditor(text: b.experiencesDesc)
                                .frame(minHeight: 80)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))

                            Text("MBTI").font(.headline)
                            LazyVStack(spacing: 10) {
                                ScaleRow(title: "外向 E ←→ 內向 I", left: "E外向", right: "內向I", value: b.mbtiEI)
                                ScaleRow(title: "實感 S ←→ 直覺 N", left: "S實感", right: "直覺N", value: b.mbtiNS)
                                ScaleRow(title: "思考 T ←→ 情感 F", left: "T思考", right: "情感F", value: b.mbtiTF)
                                ScaleRow(title: "判斷 J ←→ 感知 P", left: "J判斷", right: "感知P", value: b.mbtiJP)
                                ScaleRow(title: "自信 A ←→ 敏感 T", left: "A自信", right: "敏感T", value: b.mbtiAT)
                            }
                            HStack { Text("性格：").font(.subheadline); Text(b.wrappedValue.mbtiString).font(.title3) }

                            Text("行事作風").font(.headline)
                            LazyVStack(spacing: 8) {
                                let labels: [(String,String,String)] = [
                                    ("低調 / 高調","低調","高調"),
                                    ("消極 / 積極","消極","積極"),
                                    ("狡猾 / 老實","狡猾","老實"),
                                    ("幼稚 / 成熟","幼稚","成熟"),
                                    ("冷靜 / 衝動","冷靜","衝動"),
                                    ("寡言 / 多話","寡言","多話"),
                                    ("順從 / 執拗","順從","執拗"),
                                    ("奔放 / 自律","奔放","自律"),
                                    ("嚴肅 / 輕浮","嚴肅","輕浮"),
                                    ("彆扭 / 坦率","彆扭","坦率"),
                                    ("淡漠 / 好奇","淡漠","好奇"),
                                    ("遲鈍 / 敏銳","遲鈍","敏銳")
                                ]
                                ForEach(labels.indices, id: \.self) { i in
                                    ScaleRow(title: labels[i].0, left: labels[i].1, right: labels[i].2, value: Binding(
                                        get: { b.approach.wrappedValue[i] },
                                        set: { b.approach.wrappedValue[i] = $0 }
                                    ))
                                }
                            }

                            Text("性格特質").font(.headline)
                            LazyVStack(spacing: 8) {
                                let labels: [(String,String,String)] = [
                                    ("態度","悲觀","樂觀"),
                                    ("表情","面癱","生動"),
                                    ("資質","笨蛋","天才"),
                                    ("思想","單純","複雜"),
                                    ("臉皮","極薄","極厚"),
                                    ("脾氣","溫和","火爆"),
                                    ("舉止","粗魯","斯文"),
                                    ("意志","易碎","堅強"),
                                    ("慾望","無慾","強烈"),
                                    ("膽量","膽小","勇敢"),
                                    ("談吐","木訥","風趣"),
                                    ("戒心","輕信","多疑"),
                                    ("自尊","低下","高亢"),
                                    ("自信","低下","高亢"),
                                    ("陰陽","陰角","陽角")
                                ]
                                ForEach(labels.indices, id: \.self) { i in
                                    ScaleRow(title: labels[i].0, left: labels[i].1, right: labels[i].2, value: Binding(
                                        get: { b.traits.wrappedValue[i] },
                                        set: { b.traits.wrappedValue[i] = $0 }
                                    ))
                                }
                            }

                            Text("其它補充")
                            TextEditor(text: b.personalityOther)
                                .frame(minHeight: 80)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                        }
                        .padding(.top, 4)
                    }

                    // 道德觀＆＆價值觀
                    LazyDisclosureSection(isExpanded: $expand_values) {
                        Text("道德觀＆＆價值觀").font(.title3.bold())
                    } content: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("行為傾向").font(.headline)
                            ScaleRow(title: "利己 / 利他", left: "利己", right: "利他", value: b.tendency)

                            Text("陣營九宮格").font(.headline)
                            AlignmentGrid(selection: b.alignment9)

                            labeledTF("信仰：", "", b.belief)
                            labeledTF("底線", "", b.characterLimit)
                            labeledTF("將來想變得如何？", "", b.inFuture)
                            labeledTF("最珍視的事物？", "", b.mostCherish)
                            labeledTF("最厭惡的事物？", "", b.mostDisgust)
                            labeledTF("最害怕的事物？", "", b.mostFear)
                            labeledTF("最好奇的事物？", "", b.mostCurious)
                            labeledTF("最期待的事物？", "", b.mostExpect)

                            Text("故事相關").font(.headline)
                            labeledTF("故事中的動機、目標？", "", b.representItem)
                            Text("阻礙主角的事件？")
                            HinderEditor(rows: b.hinders)

                            Text("其他補充：")
                            TextEditor(text: b.valuesOther)
                                .frame(minHeight: 80)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                        }
                        .padding(.top, 4)
                    }

                    // 能力＆＆才華
                    LazyDisclosureSection(isExpanded: $expand_ability) {
                        Text("能力＆＆才華").font(.title3.bold())
                    } content: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("熱愛做的事情")
                            ListEditor(placeholder: "新增", items: b.loveToDo)

                            Text("討厭做的事情")
                            ListEditor(placeholder: "新增", items: b.hateToDo)

                            Text("擅長做的事情")
                            ListEditor(placeholder: "新增", items: b.proficientToDo)

                            Text("不擅長做的事情")
                            ListEditor(placeholder: "新增", items: b.unProficientToDo)

                            Text("生活常用技能").font(.headline)
                            LazyVStack(spacing: 8) {
                                let titles = [
                                    "運動","廚藝","家務","自理","口才","美感","運勢","字跡",
                                    "酒量","歌唱","理財","認路","六感","性技","手巧","應變"
                                ]
                                let lefts = [
                                    "極弱","極弱","極弱","邋遢","口拙","極弱","衰神","潦草",
                                    "易醉","音痴","浪費","路癡","遲鈍","極弱","手拙","驚慌"
                                ]
                                let rights = [
                                    "極強","極強","極強","整潔","伶俐","極強","錦鯉","工整",
                                    "酒豪","天籟","節儉","識途","敏銳","極強","巧手","鎮定"
                                ]
                                ForEach(titles.indices, id: \.self) { i in
                                    ScaleRow(
                                        title: titles[i],
                                        left: lefts[i],
                                        right: rights[i],
                                        value: Binding(
                                            get: { b.commonAbilities.wrappedValue[i] },
                                            set: { b.commonAbilities.wrappedValue[i] = $0 }
                                        )
                                    )
                                }
                            }
                        }
                        .padding(.top, 4)
                    }

                    // 社交相關
                    LazyDisclosureSection(isExpanded: $expand_social) {
                        Text("社交相關").font(.title3.bold())
                    } content: {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("來自他人的印象")
                            TextEditor(text: b.impression)
                                .frame(minHeight: 80)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))

                            labeledTF("最受他人欣賞/喜愛的特點", "", b.mostLikable)

                            Text("簡述原生家庭")
                            TextEditor(text: b.nativeFamily)
                                .frame(minHeight: 80)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))

                            Text("如何表達「喜歡」").font(.headline)
                            VStack(alignment: .leading) {
                                HStack {
                                    Toggle("語言", isOn: b.showLoveLanguage)
                                    Toggle("陪伴", isOn: b.showLoveAccompany)
                                    Toggle("送禮", isOn: b.showLoveGift)
                                    Toggle("服務行為", isOn: b.showLoveService)
                                }
                                HStack {
                                    Toggle("肢體接觸", isOn: b.showLoveTouch)
                                    Toggle("捉弄", isOn: b.showLoveTease)
                                    Toggle("獻上自己", isOn: b.showLoveSelf)
                                    Toggle("迴避", isOn: b.showLoveAvoid)
                                }
                                Toggle("其他", isOn: b.showLoveOther)
                                if b.showLoveOther.wrappedValue {
                                    TextField("其他……", text: b.showLoveOtherText).textFieldStyle(.roundedBorder)
                                }
                            }

                            Text("如何表達好意").font(.headline)
                            VStack(alignment: .leading) {
                                HStack {
                                    Toggle("語言", isOn: b.goodwillLanguage)
                                    Toggle("陪伴", isOn: b.goodwillAccompany)
                                    Toggle("送禮", isOn: b.goodwillGift)
                                }
                                HStack {
                                    Toggle("服務行為", isOn: b.goodwillService)
                                    Toggle("肢體接觸", isOn: b.goodwillTouch)
                                    Toggle("其他", isOn: b.goodwillOther)
                                }
                                if b.goodwillOther.wrappedValue {
                                    TextField("其他……", text: b.goodwillOtherText).textFieldStyle(.roundedBorder)
                                }
                            }

                            Text("如何應對討厭的人？").font(.headline)
                            VStack(alignment: .leading) {
                                HStack {
                                    Toggle("惡言", isOn: b.hateBadWords)
                                    Toggle("武力", isOn: b.hateViolence)
                                    Toggle("戲弄", isOn: b.hateTrick)
                                    Toggle("耍陰招", isOn: b.hateSneaky)
                                }
                                HStack {
                                    Toggle("迴避", isOn: b.hateAvoid)
                                    Toggle("冷漠", isOn: b.hateIndifferent)
                                    Toggle("以德報怨", isOn: b.hateRepayKindness)
                                    Toggle("不做區別", isOn: b.hateNoDifference)
                                }
                                Toggle("其它", isOn: b.hateOther)
                                if b.hateOther.wrappedValue {
                                    TextField("其他……", text: b.hateOtherText).textFieldStyle(.roundedBorder)
                                }
                            }

                            Text("社交相關項目").font(.headline)
                            LazyVStack(spacing: 8) {
                                let titles = ["人緣","社交","處事","地位","桃花","同理心","友伴","態度","碰觸","（自訂）"]
                                let lefts  = ["極差","孤僻","稚嫩","卑賤","絕緣","極低","損友","謙遜","反感",""]
                                let rights = ["極好","合群","老練","高尚","撩人","極高","益友","高傲","喜歡",""]
                                ForEach(0..<10, id: \.self) { i in
                                    ScaleRow(title: titles[i], left: lefts[i], right: rights[i], value: Binding(
                                        get: { b.socialScales.wrappedValue[i] },
                                        set: { b.socialScales.wrappedValue[i] = $0 }
                                    ))
                                }
                            }
                        }
                        .padding(.top, 4)
                    }

                    // 其他
                    LazyDisclosureSection(isExpanded: $expand_other) {
                        Text("其他").font(.title3.bold())
                    } content: {
                        VStack(alignment: .leading, spacing: 12) {
                            labeledTF("原文姓名", "例如：桜田如羽", b.originalName)

                            Text("喜歡的人事物")
                            ListEditor(placeholder: "新增", items: b.likeItems)

                            Text("討厭的人事物")
                            ListEditor(placeholder: "新增", items: b.hateItems)

                            Text("習慣的人事物")
                            ListEditor(placeholder: "新增", items: b.familiarItems)

                            Text("其他補充")
                            TextEditor(text: b.otherText)
                                .frame(minHeight: 80)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                        }
                        .padding(.top, 4)
                    }
                } else {
                    Text("請先新增或選擇一個角色").foregroundStyle(.secondary).padding(.vertical, 12)
                }

                Spacer(minLength: 24)
            }
            .padding()
        }
        .onAppear {
            if selectedID == nil { selectedID = characters.first?.id }
        }
    }

    // MARK: - 小元件與工具

    @ViewBuilder
    private func groupBox(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold())
            content()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
    }

    @ViewBuilder
    private func labeledTF(_ label: String, _ placeholder: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
            TextField(placeholder, text: binding).textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private func colorRow(_ title: String, _ c1: Binding<Color>, _ c2: Binding<Color>) -> some View {
        HStack {
            Text(title)
            ColorPicker("", selection: c1).labelsHidden()
            ColorPicker("", selection: c2).labelsHidden()
            Spacer()
        }
    }

    private func displayName(_ c: CharacterProfile) -> String {
        let full = "\(c.surname)\(c.firstName)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? "（未命名角色）" : full
    }

    private func addCharacter() {
        let c = CharacterProfile()
        characters.append(c)
        selectedID = c.id
    }

    private func deleteCharacters(at offsets: IndexSet) {
        characters.remove(atOffsets: offsets)
        selectedID = characters.first?.id
    }

    private func applyTemplate() {
        // 目前僅示意：空白模板不做任何事。可在此接入外部模板系統。
    }
}

#Preview {
    @State var demo: [CharacterProfile] = [CharacterProfile()]
    return CharacterSettingsView(characters: $demo)
}
