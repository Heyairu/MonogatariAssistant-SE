//
//  BaseInfoView.swift
//  MonogatariAssistant
//
//  Ported from the original Qt BaseInfo module (single file, no DataPool)
//  Created by 部屋いる on 2025/8/29.
//

import SwiftUI
import Foundation

// MARK: - Model

struct BaseInfoData: Equatable {
    var bookName: String = ""
    var author: String = ""
    var purpose: String = ""
    var toRecap: String = ""
    var storyType: String = ""
    var intro: String = ""
    var tags: [String] = []
    var latestSave: Date? = nil
    // 在 Qt：totalWords 由 DataPool 供給；此 Swift 版本改由上層提供
    var nowWords: Int = 0     // 由 content（非空白字元數）計算

    mutating func recalcNowWords(from content: String) {
        nowWords = content.unicodeScalars.filter { !$0.properties.isWhitespace }.count
    }

    var isEffectivelyEmpty: Bool {
        bookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        storyType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        intro.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        tags.isEmpty
    }
}

// MARK: - XML Codec (compatible with the Qt format)

enum BaseInfoCodec {
    // 序列化成與 Qt SaveFile() 兼容的 <Type> 片段
    static func saveXML(updatingLatestSave data: inout BaseInfoData, totalWords: Int, contentText: String) -> String? {
        if data.isEffectivelyEmpty { return nil }

        data.latestSave = Date()
        var snapshot = data
        snapshot.recalcNowWords(from: contentText)

        func esc(_ s: String) -> String {
            var out = s
            out = out.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "'", with: "&apos;")
            return out
        }

        let isoSave: String = {
            guard let d = snapshot.latestSave else { return "" }
            let fmt1 = ISO8601DateFormatter()
            fmt1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let s = Optional(fmt1.string(from: d)), !s.isEmpty { return s }
            let fmt2 = ISO8601DateFormatter()
            fmt2.formatOptions = [.withInternetDateTime]
            return fmt2.string(from: d)
        }()

        var xml = ""
        xml += "<Type>\n"
        xml += "  <Name>BaseInfo</Name>\n"
        xml += "  <General>\n"
        xml += "    <BookName>\(esc(snapshot.bookName))</BookName>\n"
        xml += "    <Author>\(esc(snapshot.author))</Author>\n"
        xml += "    <Purpose>\(esc(snapshot.purpose))</Purpose>\n"
        xml += "    <ToRecap>\(esc(snapshot.toRecap))</ToRecap>\n"
        xml += "    <StoryType>\(esc(snapshot.storyType))</StoryType>\n"
        xml += "    <Intro>\(esc(snapshot.intro))</Intro>\n"
        if !isoSave.isEmpty {
            xml += "    <LatestSave>\(isoSave)</LatestSave>\n"
        }
        xml += "  </General>\n"
        xml += "  <Tags>\n"
        for t in snapshot.tags {
            let tt = t.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tt.isEmpty else { continue }
            xml += "    <Tag>\(esc(tt))</Tag>\n"
        }
        xml += "  </Tags>\n"
        xml += "  <Stats>\n"
        xml += "    <TotalWords>\(totalWords)</TotalWords>\n"
        xml += "    <NowWords>\(snapshot.nowWords)</NowWords>\n"
        xml += "  </Stats>\n"
        xml += "</Type>\n"
        return xml
    }

    // 自 <Type> 區塊解析（需 <Name>BaseInfo</Name>）
    static func loadXML(_ xml: String) -> BaseInfoData? {
        class Parser: NSObject, XMLParserDelegate {
            var data = BaseInfoData()
            var path: [String] = []
            var textBuffer: String = ""
            var nameIsBaseInfo = false

            func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                path.append(elementName)
                textBuffer = ""
            }

            func parser(_ parser: XMLParser, foundCharacters string: String) {
                textBuffer += string
            }

            func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
                let trimmed = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

                switch path.joined(separator: "/") {
                case "Type/Name":
                    nameIsBaseInfo = (trimmed == "BaseInfo")
                case "Type/General/BookName":
                    data.bookName = trimmed
                case "Type/General/Author":
                    data.author = trimmed
                case "Type/General/Purpose":
                    data.purpose = trimmed
                case "Type/General/ToRecap":
                    data.toRecap = trimmed
                case "Type/General/StoryType":
                    data.storyType = trimmed
                case "Type/General/Intro":
                    data.intro = trimmed
                case "Type/General/LatestSave":
                    if !trimmed.isEmpty {
                        let fmt1 = ISO8601DateFormatter()
                        fmt1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        if let d = fmt1.date(from: trimmed) {
                            data.latestSave = d
                        } else {
                            let fmt2 = ISO8601DateFormatter()
                            fmt2.formatOptions = [.withInternetDateTime]
                            data.latestSave = fmt2.date(from: trimmed)
                        }
                    }
                case "Type/Tags/Tag":
                    if !trimmed.isEmpty { data.tags.append(trimmed) }
                case "Type/Stats/NowWords":
                    if let v = Int(trimmed) { data.nowWords = v }
                default:
                    break
                }

                _ = path.popLast()
                textBuffer = ""
            }
        }

        guard let dataXml = xml.data(using: .utf8) else { return nil }
        let delegate = Parser()
        let parser = XMLParser(data: dataXml)
        parser.delegate = delegate
        if parser.parse(), delegate.nameIsBaseInfo {
            return delegate.data
        }
        return nil
    }
}

// MARK: - View

struct BaseInfoView: View {
    // 提供自外部的綁定：
    // - data：本頁面的資料模型
    // - contentText：用於計算「本章字數」的正文（不會存入檔案）
    // - totalWords：總字數由上層提供（不從 content 計）
    @Binding var data: BaseInfoData
    @Binding var contentText: String
    @Binding var totalWords: Int

    @State private var newTag: String = ""

    private let dateLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy.MM.dd HH:mm:ss"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("基本資訊")
                    .font(.largeTitle)
                    .bold()

                // 書名
                Group {
                    Text("書名：")
                        .font(.title3)
                    TextField("輸入書名", text: $data.bookName)
                        .textFieldStyle(.roundedBorder)
                }

                // 作者
                Group {
                    Text("作者：")
                        .font(.title3)
                    TextField("輸入作者名", text: $data.author)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 故事主旨
                Group {
                    Text("主旨：")
                        .font(.title3)
                    TextField("輸入故事主旨", text: $data.purpose)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 一句話簡介
                Group {
                    Text("一句話簡介：")
                        .font(.title3)
                    TextField("輸入一句話簡介", text: $data.toRecap)
                        .textFieldStyle(.roundedBorder)
                }

                // 類型
                Group {
                    Text("類型：")
                        .font(.title3)
                    TextField("輸入作品類型", text: $data.storyType)
                        .textFieldStyle(.roundedBorder)
                }

                // 標籤
                Group {
                    Text("標籤：")
                        .font(.title3)

                    VStack(spacing: 6) {
                        ForEach(Array(data.tags.enumerated()), id: \.offset) { idx, tag in
                            HStack {
                                Text(tag)
                                Spacer()
                                Button {
                                    removeTag(atOffsets: IndexSet(integer: idx))
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("刪除標籤 \(tag)")
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }

                        HStack(spacing: 8) {
                            TextField("新增標籤", text: $newTag, onCommit: addTag)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                addTag()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("新增標籤")
                        }
                    }
                }

                // 簡介
                Group {
                    Text("簡介：")
                        .font(.title3)
                    TextEditor(text: $data.intro)
                        .frame(minHeight: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.secondary.opacity(0.3))
                        )
                }

                // 最後儲存時間
                Group {
                    Text("最後儲存時間")
                        .font(.title3)
                    Text(data.latestSave.map { dateLabelFormatter.string(from: $0) } ?? "YYYY.MM.DD hh.mm.ss")
                        .font(.title3.weight(.semibold))
                }

                // 字數統計
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("總字數")
                        Spacer()
                        Text("\(totalWords)")
                        Text("字")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("本章字數")
                        Spacer()
                        Text("\(data.nowWords)")
                        Text("字")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)

                Spacer(minLength: 16)
            }
            .padding()
        }
        .onAppear {
            data.recalcNowWords(from: contentText)
        }
        .onChange(of: contentText) { _, newValue in
            data.recalcNowWords(from: newValue)
        }
    }

    // MARK: - Tag helpers

    private func addTag() {
        let t = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        guard !data.tags.contains(t) else {
            newTag = ""
            return
        }
        data.tags.append(t)
        newTag = ""
    }

    private func removeTag(atOffsets offsets: IndexSet) {
        data.tags.remove(atOffsets: offsets)
    }
}
