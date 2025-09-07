//
//  CharacterSettingsCodec.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/9/7.
//

import Foundation
import SwiftUI
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// 將角色資料序列化為 XML，並從 XML 還原
// 本版新增：所有顏色以 Hex 色碼（#RRGGBB 或 #RRGGBBAA）直接寫入/讀出 Codoc 檔
enum CharacterSettingsCodec {
    // MARK: - Helpers

    private static func esc(_ s: String) -> String {
        var t = s
        t = t.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
        return t
    }

    private static func xmlBool(_ v: Bool) -> String { v ? "true" : "false" }
    private static func xmlInt(_ v: Int) -> String { String(v) }

    // Color -> #RRGGBBAA（若 alpha 為 1.0，仍輸出 8 碼以一致）
    private static func colorToHex(_ color: Color) -> String {
        #if os(iOS) || os(tvOS) || os(watchOS)
        let u = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        if !u.getRed(&r, &g, &b, &a) {
            // 嘗試轉換色彩空間
            let converted = u.cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .relativeColorimetric, options: nil)
            let uu = converted.flatMap { UIColor(cgColor: $0) } ?? u
            uu.getRed(&r, &g, &b, &a)
        }
        #elseif os(macOS)
        let n = NSColor(color)
        let cs = n.usingColorSpace(.sRGB) ?? n
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        cs.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        let ri = max(0, min(255, Int(round(r * 255))))
        let gi = max(0, min(255, Int(round(g * 255))))
        let bi = max(0, min(255, Int(round(b * 255))))
        let ai = max(0, min(255, Int(round(a * 255))))
        return String(format: "#%02X%02X%02X%02X", ri, gi, bi, ai)
    }

    // 支援 #RRGGBB 與 #RRGGBBAA
    private static func hexToColor(_ hex: String) -> Color? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }

        var value: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&value) else { return nil }

        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((value & 0xFF000000) >> 24) / 255.0
            g = Double((value & 0x00FF0000) >> 16) / 255.0
            b = Double((value & 0x0000FF00) >> 8) / 255.0
            a = Double(value & 0x000000FF) / 255.0
        } else {
            r = Double((value & 0xFF0000) >> 16) / 255.0
            g = Double((value & 0x00FF00) >> 8) / 255.0
            b = Double(value & 0x0000FF) / 255.0
            a = 1.0
        }
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    private static func writeList(_ title: String, _ items: [String], indent: String) -> String {
        var xml = ""
        xml += "\(indent)<\(title)>\n"
        for it in items { xml += "\(indent)  <Item>\(esc(it))</Item>\n" }
        xml += "\(indent)</\(title)>\n"
        return xml
    }

    private static func writeIntArray(_ title: String, _ items: [Int], indent: String) -> String {
        var xml = ""
        xml += "\(indent)<\(title)>\n"
        for v in items { xml += "\(indent)  <Val>\(v)</Val>\n" }
        xml += "\(indent)</\(title)>\n"
        return xml
    }

    private static func writeRelations(_ rows: [CharacterProfile.Relation], indent: String) -> String {
        var xml = ""
        xml += "\(indent)<Relations>\n"
        for r in rows {
            xml += "\(indent)  <Relation>\n"
            xml += "\(indent)    <Name>\(esc(r.name))</Name>\n"
            xml += "\(indent)    <Role>\(esc(r.relation))</Role>\n"
            xml += "\(indent)  </Relation>\n"
        }
        xml += "\(indent)</Relations>\n"
        return xml
    }

    private static func writeHinders(_ rows: [CharacterProfile.Hinder], indent: String) -> String {
        var xml = ""
        xml += "\(indent)<Hinders>\n"
        for r in rows {
            xml += "\(indent)  <Hinder>\n"
            xml += "\(indent)    <Event>\(esc(r.event))</Event>\n"
            xml += "\(indent)    <Solve>\(esc(r.solve))</Solve>\n"
            xml += "\(indent)  </Hinder>\n"
        }
        xml += "\(indent)</Hinders>\n"
        return xml
    }

    // MARK: - Save

    static func saveXML(characters: [CharacterProfile]) -> String? {
        guard !characters.isEmpty else { return nil }
        var xml = ""
        xml += "<Type>\n"
        xml += "  <Name>Characters</Name>\n"
        for c in characters {
            xml += "  <Character>\n"
            // 重要資訊
            xml += "    <Surname>\(esc(c.surname))</Surname>\n"
            xml += "    <FirstName>\(esc(c.firstName))</FirstName>\n"
            xml += "    <Gender>\(esc(c.gender))</Gender>\n"
            xml += "    <Age>\(esc(c.age))</Age>\n"
            xml += "    <BirthMonth>\(esc(c.birthMonth))</BirthMonth>\n"
            xml += "    <BirthDay>\(esc(c.birthDay))</BirthDay>\n"
            xml += "    <Role>\(esc(c.role))</Role>\n"

            // 基本資料
            xml += "    <Ethnicity>\(esc(c.ethnicity))</Ethnicity>\n"
            xml += "    <Nation>\(esc(c.nation))</Nation>\n"
            xml += "    <Home>\(esc(c.home))</Home>\n"
            xml += "    <Occupation>\(esc(c.occupation))</Occupation>\n"
            xml += "    <Education>\(esc(c.education))</Education>\n"
            xml += "    <Economic>\(esc(c.economic))</Economic>\n"
            xml += "    <Mantra>\(esc(c.mantra))</Mantra>\n"
            xml += "    <Motto>\(esc(c.motto))</Motto>\n"
            xml += writeList("Nicknames", c.nicknames, indent: "    ")
            xml += writeList("Tags", c.tags, indent: "    ")

            // 性取向/戀愛關係
            xml += "    <Sexual>\(esc(c.sexual.rawValue))</Sexual>\n"
            xml += "    <SexualOther>\(esc(c.sexualOther))</SexualOther>\n"
            xml += "    <LoveStatus>\(esc(c.loveStatus.rawValue))</LoveStatus>\n"
            xml += "    <LoveOther>\(esc(c.loveOther))</LoveOther>\n"
            xml += "    <IsFindNewLove>\(xmlBool(c.isFindNewLove))</IsFindNewLove>\n"
            xml += "    <IsHarem>\(xmlBool(c.isHarem))</IsHarem>\n"
            xml += writeRelations(c.relations, indent: "    ")

            // 代表元素
            xml += "    <RepresentItem>\(esc(c.representItem))</RepresentItem>\n"
            xml += "    <RepresentColor1Hex>\(colorToHex(c.representColor1))</RepresentColor1Hex>\n"
            xml += "    <RepresentColor2Hex>\(colorToHex(c.representColor2))</RepresentColor2Hex>\n"

            // 身體
            xml += "    <HeightText>\(esc(c.heightText))</HeightText>\n"
            xml += "    <WeightText>\(esc(c.weightText))</WeightText>\n"
            xml += "    <Figure>\(xmlInt(c.figure))</Figure>\n"
            xml += "    <Looks>\(xmlInt(c.looks))</Looks>\n"
            xml += "    <Temperature>\(xmlInt(c.temperature))</Temperature>\n"
            xml += "    <BodyPower>\(xmlInt(c.bodyPower))</BodyPower>\n"
            xml += "    <SoundVolume>\(xmlInt(c.soundVolume))</SoundVolume>\n"
            xml += "    <VoicePitch>\(xmlInt(c.voicePitch))</VoicePitch>\n"
            xml += "    <PreferredHand>\(esc(c.hand.rawValue))</PreferredHand>\n"
            xml += "    <PreferredHandOther>\(esc(c.handOther))</PreferredHandOther>\n"
            xml += "    <Eyesight>\(esc(c.eyesight.rawValue))</Eyesight>\n"
            xml += "    <EyesightOther>\(esc(c.eyesightOther))</EyesightOther>\n"
            xml += "    <HealthGood>\(xmlBool(c.healthGood))</HealthGood>\n"
            xml += "    <HealthWeak>\(xmlBool(c.healthWeak))</HealthWeak>\n"
            xml += "    <HealthOld>\(xmlBool(c.healthOld))</HealthOld>\n"
            xml += "    <HealthSpecialDisease>\(xmlBool(c.healthSpecialDisease))</HealthSpecialDisease>\n"
            xml += "    <HealthSpecialDiseaseText>\(esc(c.healthSpecialDiseaseText))</HealthSpecialDiseaseText>\n"
            xml += "    <HealthMentalIssue>\(xmlBool(c.healthMentalIssue))</HealthMentalIssue>\n"
            xml += "    <HealthMentalIssueText>\(esc(c.healthMentalIssueText))</HealthMentalIssueText>\n"
            xml += "    <HealthOtherChecked>\(xmlBool(c.healthOtherChecked))</HealthOtherChecked>\n"
            xml += "    <HealthOtherText>\(esc(c.healthOtherText))</HealthOtherText>\n"
            xml += "    <BodyComplement>\(esc(c.bodyComplement))</BodyComplement>\n"

            // 個性
            xml += "    <PersonalityDesc>\(esc(c.personalityDesc))</PersonalityDesc>\n"
            xml += "    <ExperiencesDesc>\(esc(c.experiencesDesc))</ExperiencesDesc>\n"
            xml += "    <MBTI>\n"
            xml += "      <EI>\(xmlInt(c.mbtiEI))</EI>\n"
            xml += "      <NS>\(xmlInt(c.mbtiNS))</NS>\n"
            xml += "      <TF>\(xmlInt(c.mbtiTF))</TF>\n"
            xml += "      <JP>\(xmlInt(c.mbtiJP))</JP>\n"
            xml += "      <AT>\(xmlInt(c.mbtiAT))</AT>\n"
            xml += "    </MBTI>\n"
            xml += writeIntArray("Approach", c.approach, indent: "    ")
            xml += writeIntArray("Traits", c.traits, indent: "    ")
            xml += "    <PersonalityOther>\(esc(c.personalityOther))</PersonalityOther>\n"

            // 能力
            xml += writeList("LoveToDo", c.loveToDo, indent: "    ")
            xml += writeList("HateToDo", c.hateToDo, indent: "    ")
            xml += writeList("ProficientToDo", c.proficientToDo, indent: "    ")
            xml += writeList("UnProficientToDo", c.unProficientToDo, indent: "    ")
            xml += writeIntArray("CommonAbilities", c.commonAbilities, indent: "    ")

            // 色票（全部以 Hex 儲存）
            xml += "    <ColorChips>\n"
            xml += "      <HairColor1Hex>\(colorToHex(c.hairColor1))</HairColor1Hex>\n"
            xml += "      <HairColor2Hex>\(colorToHex(c.hairColor2))</HairColor2Hex>\n"
            xml += "      <EyeColor1Hex>\(colorToHex(c.eyeColor1))</EyeColor1Hex>\n"
            xml += "      <EyeColor2Hex>\(colorToHex(c.eyeColor2))</EyeColor2Hex>\n"
            xml += "      <SkinColor1Hex>\(colorToHex(c.skinColor1))</SkinColor1Hex>\n"
            xml += "      <SkinColor2Hex>\(colorToHex(c.skinColor2))</SkinColor2Hex>\n"
            xml += "      <CustomColor1Name>\(esc(c.customColor1Name))</CustomColor1Name>\n"
            xml += "      <CustomColor1AHex>\(colorToHex(c.customColor1A))</CustomColor1AHex>\n"
            xml += "      <CustomColor1BHex>\(colorToHex(c.customColor1B))</CustomColor1BHex>\n"
            xml += "      <CustomColor2Name>\(esc(c.customColor2Name))</CustomColor2Name>\n"
            xml += "      <CustomColor2AHex>\(colorToHex(c.customColor2A))</CustomColor2AHex>\n"
            xml += "      <CustomColor2BHex>\(colorToHex(c.customColor2B))</CustomColor2BHex>\n"
            xml += "    </ColorChips>\n"

            // 社交
            xml += "    <Impression>\(esc(c.impression))</Impression>\n"
            xml += "    <MostLikable>\(esc(c.mostLikable))</MostLikable>\n"
            xml += "    <NativeFamily>\(esc(c.nativeFamily))</NativeFamily>\n"

            xml += "    <ShowLove>\n"
            xml += "      <Language>\(xmlBool(c.showLoveLanguage))</Language>\n"
            xml += "      <Accompany>\(xmlBool(c.showLoveAccompany))</Accompany>\n"
            xml += "      <Gift>\(xmlBool(c.showLoveGift))</Gift>\n"
            xml += "      <Service>\(xmlBool(c.showLoveService))</Service>\n"
            xml += "      <Touch>\(xmlBool(c.showLoveTouch))</Touch>\n"
            xml += "      <Tease>\(xmlBool(c.showLoveTease))</Tease>\n"
            xml += "      <Self>\(xmlBool(c.showLoveSelf))</Self>\n"
            xml += "      <Avoid>\(xmlBool(c.showLoveAvoid))</Avoid>\n"
            xml += "      <Other>\(xmlBool(c.showLoveOther))</Other>\n"
            xml += "      <OtherText>\(esc(c.showLoveOtherText))</OtherText>\n"
            xml += "    </ShowLove>\n"

            xml += "    <Goodwill>\n"
            xml += "      <Language>\(xmlBool(c.goodwillLanguage))</Language>\n"
            xml += "      <Accompany>\(xmlBool(c.goodwillAccompany))</Accompany>\n"
            xml += "      <Gift>\(xmlBool(c.goodwillGift))</Gift>\n"
            xml += "      <Service>\(xmlBool(c.goodwillService))</Service>\n"
            xml += "      <Touch>\(xmlBool(c.goodwillTouch))</Touch>\n"
            xml += "      <Other>\(xmlBool(c.goodwillOther))</Other>\n"
            xml += "      <OtherText>\(esc(c.goodwillOtherText))</OtherText>\n"
            xml += "    </Goodwill>\n"

            xml += "    <HandleHate>\n"
            xml += "      <BadWords>\(xmlBool(c.hateBadWords))</BadWords>\n"
            xml += "      <Violence>\(xmlBool(c.hateViolence))</Violence>\n"
            xml += "      <Trick>\(xmlBool(c.hateTrick))</Trick>\n"
            xml += "      <Sneaky>\(xmlBool(c.hateSneaky))</Sneaky>\n"
            xml += "      <Avoid>\(xmlBool(c.hateAvoid))</Avoid>\n"
            xml += "      <Indifferent>\(xmlBool(c.hateIndifferent))</Indifferent>\n"
            xml += "      <RepayKindness>\(xmlBool(c.hateRepayKindness))</RepayKindness>\n"
            xml += "      <NoDifference>\(xmlBool(c.hateNoDifference))</NoDifference>\n"
            xml += "      <Other>\(xmlBool(c.hateOther))</Other>\n"
            xml += "      <OtherText>\(esc(c.hateOtherText))</OtherText>\n"
            xml += "    </HandleHate>\n"

            xml += writeIntArray("SocialScales", c.socialScales, indent: "    ")

            // 其他
            xml += "    <OriginalName>\(esc(c.originalName))</OriginalName>\n"
            xml += writeList("LikeItems", c.likeItems, indent: "    ")
            xml += writeList("HateItems", c.hateItems, indent: "    ")
            xml += writeList("FamiliarItems", c.familiarItems, indent: "    ")
            xml += "    <OtherText>\(esc(c.otherText))</OtherText>\n"

            xml += "  </Character>\n"
        }
        xml += "</Type>\n"
        return xml
    }

    // MARK: - Load helpers

    private static func clamp01(_ v: Int) -> Int { max(0, min(100, v)) }

    private static func normalizedIntArray(_ arr: [Int], count: Int, defaultValue: Int = 50) -> [Int] {
        if arr.isEmpty { return Array(repeating: defaultValue, count: count) }
        var a = arr.map { clamp01($0) }
        if a.count < count {
            a.append(contentsOf: Array(repeating: defaultValue, count: count - a.count))
        } else if a.count > count {
            a = Array(a.prefix(count))
        }
        return a
    }

    // MARK: - Load

    static func loadXML(_ xml: String) -> [CharacterProfile]? {
        guard let data = xml.data(using: .utf8) else { return nil }

        final class Parser: NSObject, XMLParserDelegate {
            var isCharactersBlock = false

            var chars: [CharacterProfile] = []
            var stack: [String] = []
            var text = ""

            var current: CharacterProfile?
            var currentRelation: CharacterProfile.Relation?
            var currentHinder: CharacterProfile.Hinder?

            // list collecting flags
            var collectingNicknames = false
            var collectingTags = false
            var collectingLoveToDo = false
            var collectingHateToDo = false
            var collectingProficientToDo = false
            var collectingUnProficientToDo = false
            var collectingLikeItems = false
            var collectingHateItems = false
            var collectingFamiliarItems = false

            // int-array collecting
            var tmpApproach: [Int] = []
            var tmpTraits: [Int] = []
            var tmpCommon: [Int] = []
            var tmpSocial: [Int] = []

            func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
                stack.append(name)
                text = ""

                switch name {
                case "Character":
                    current = CharacterProfile()
                case "Nicknames": collectingNicknames = true
                case "Tags": collectingTags = true
                case "LoveToDo": collectingLoveToDo = true
                case "HateToDo": collectingHateToDo = true
                case "ProficientToDo": collectingProficientToDo = true
                case "UnProficientToDo": collectingUnProficientToDo = true
                case "LikeItems": collectingLikeItems = true
                case "HateItems": collectingHateItems = true
                case "FamiliarItems": collectingFamiliarItems = true

                case "Relation": currentRelation = CharacterProfile.Relation()
                case "Hinder": currentHinder = CharacterProfile.Hinder()

                case "Approach": tmpApproach.removeAll()
                case "Traits": tmpTraits.removeAll()
                case "CommonAbilities": tmpCommon.removeAll()
                case "SocialScales": tmpSocial.removeAll()
                default: break
                }
            }

            func parser(_ parser: XMLParser, foundCharacters string: String) {
                text += string
            }

            func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName qName: String?) {
                let joined = stack.joined(separator: "/")
                let val = text.trimmingCharacters(in: .whitespacesAndNewlines)

                switch joined {
                case "Type/Name":
                    isCharactersBlock = (val == "Characters")

                case "Type/Character":
                    if var c = current {
                        // 陣列預設 50%
                        if c.approach.count != 12 { c.approach = Array(repeating: 50, count: 12) }
                        if c.traits.count != 15 { c.traits = Array(repeating: 50, count: 15) }
                        if c.commonAbilities.count != 16 { c.commonAbilities = Array(repeating: 50, count: 16) }
                        if c.socialScales.count != 10 { c.socialScales = Array(repeating: 50, count: 10) }
                        chars.append(c)
                    }
                    current = nil

                // 基本字串
                case "Type/Character/Surname": current?.surname = val
                case "Type/Character/FirstName": current?.firstName = val
                case "Type/Character/Gender": current?.gender = val
                case "Type/Character/Age": current?.age = val
                case "Type/Character/BirthMonth": current?.birthMonth = val
                case "Type/Character/BirthDay": current?.birthDay = val
                case "Type/Character/Role": current?.role = val

                case "Type/Character/Ethnicity": current?.ethnicity = val
                case "Type/Character/Nation": current?.nation = val
                case "Type/Character/Home": current?.home = val
                case "Type/Character/Occupation": current?.occupation = val
                case "Type/Character/Education": current?.education = val
                case "Type/Character/Economic": current?.economic = val
                case "Type/Character/Mantra": current?.mantra = val
                case "Type/Character/Motto": current?.motto = val

                case "Type/Character/Sexual": current?.sexual = CharacterProfile.Sexual(rawValue: val) ?? .opposite
                case "Type/Character/SexualOther": current?.sexualOther = val
                case "Type/Character/LoveStatus": current?.loveStatus = CharacterProfile.LoveStatus(rawValue: val) ?? .single
                case "Type/Character/LoveOther": current?.loveOther = val
                case "Type/Character/IsFindNewLove": current?.isFindNewLove = (val == "true" || val == "1")
                case "Type/Character/IsHarem": current?.isHarem = (val == "true" || val == "1")

                case "Type/Character/RepresentItem": current?.representItem = val
                case "Type/Character/RepresentColor1Hex":
                    if let cHex = CharacterSettingsCodec.hexToColor(val) { current?.representColor1 = cHex }
                case "Type/Character/RepresentColor2Hex":
                    if let cHex = CharacterSettingsCodec.hexToColor(val) { current?.representColor2 = cHex }

                case "Type/Character/HeightText": current?.heightText = val
                case "Type/Character/WeightText": current?.weightText = val
                case "Type/Character/Figure": current?.figure = Int(val) ?? 0
                case "Type/Character/Looks": current?.looks = Int(val) ?? 0
                case "Type/Character/Temperature": current?.temperature = Int(val) ?? 0
                case "Type/Character/BodyPower": current?.bodyPower = Int(val) ?? 0
                case "Type/Character/SoundVolume": current?.soundVolume = Int(val) ?? 0
                case "Type/Character/VoicePitch": current?.voicePitch = Int(val) ?? 0
                case "Type/Character/PreferredHand": current?.hand = CharacterProfile.PreferredHand(rawValue: val) ?? .right
                case "Type/Character/PreferredHandOther": current?.handOther = val
                case "Type/Character/Eyesight": current?.eyesight = CharacterProfile.Eyesight(rawValue: val) ?? .normal
                case "Type/Character/EyesightOther": current?.eyesightOther = val
                case "Type/Character/HealthGood": current?.healthGood = (val == "true" || val == "1")
                case "Type/Character/HealthWeak": current?.healthWeak = (val == "true" || val == "1")
                case "Type/Character/HealthOld": current?.healthOld = (val == "true" || val == "1")
                case "Type/Character/HealthSpecialDisease": current?.healthSpecialDisease = (val == "true" || val == "1")
                case "Type/Character/HealthSpecialDiseaseText": current?.healthSpecialDiseaseText = val
                case "Type/Character/HealthMentalIssue": current?.healthMentalIssue = (val == "true" || val == "1")
                case "Type/Character/HealthMentalIssueText": current?.healthMentalIssueText = val
                case "Type/Character/HealthOtherChecked": current?.healthOtherChecked = (val == "true" || val == "1")
                case "Type/Character/HealthOtherText": current?.healthOtherText = val
                case "Type/Character/BodyComplement": current?.bodyComplement = val

                case "Type/Character/PersonalityDesc": current?.personalityDesc = val
                case "Type/Character/ExperiencesDesc": current?.experiencesDesc = val
                case "Type/Character/MBTI/EI": current?.mbtiEI = Int(val) ?? 0
                case "Type/Character/MBTI/NS": current?.mbtiNS = Int(val) ?? 0
                case "Type/Character/MBTI/TF": current?.mbtiTF = Int(val) ?? 0
                case "Type/Character/MBTI/JP": current?.mbtiJP = Int(val) ?? 0
                case "Type/Character/MBTI/AT": current?.mbtiAT = Int(val) ?? 0
                case "Type/Character/PersonalityOther": current?.personalityOther = val

                case "Type/Character/Tendency": current?.tendency = Int(val) ?? 0
                case "Type/Character/Alignment9": current?.alignment9 = CharacterProfile.Alignment9(rawValue: val) ?? .neutralGood
                case "Type/Character/Belief": current?.belief = val
                case "Type/Character/CharacterLimit": current?.characterLimit = val
                case "Type/Character/InFuture": current?.inFuture = val
                case "Type/Character/MostCherish": current?.mostCherish = val
                case "Type/Character/MostDisgust": current?.mostDisgust = val
                case "Type/Character/MostFear": current?.mostFear = val
                case "Type/Character/MostCurious": current?.mostCurious = val
                case "Type/Character/MostExpect": current?.mostExpect = val
                case "Type/Character/ValuesOther": current?.valuesOther = val

                // 色票（Hex）
                case "Type/Character/ColorChips/HairColor1Hex":
                    if let cHex = CharacterSettingsCodec.hexToColor(val) { current?.hairColor1 = cHex }
                case "Type/Character/ColorChips/HairColor2Hex":
                    if let cHex = CharacterSettingsCodec.hexToColor(val) { current?.hairColor2 = cHex }
                case "Type/Character/ColorChips/EyeColor1Hex":
                    if let cHex = CharacterSettingsCodec.hexToColor(val) { current?.eyeColor1 = cHex }
                case "Type/Character/ColorChips/EyeColor2Hex":
                    if let cHex = CharacterSettingsCodec.hexToColor(val) { current?.eyeColor2 = cHex }
                case "Type/Character/ColorChips/SkinColor1Hex":
                    if let cHex = CharacterSettingsCodec.hexToColor(val) { current?.skinColor1 = cHex }
                case "Type/Character/ColorChips/SkinColor2Hex":
                    if let cHex = CharacterSettingsCodec.hexToColor(val) { current?.skinColor2 = cHex }
                case "Type/Character/ColorChips/CustomColor1Name": current?.customColor1Name = val
                case "Type/Character/ColorChips/CustomColor1AHex":
                    if let cHex = CharacterSettingsCodec.hexToColor(val) { current?.customColor1A = cHex }
                case "Type/Character/ColorChips/CustomColor1BHex":
                    if let cHex = CharacterSettingsCodec.hexToColor(val) { current?.customColor1B = cHex }
                case "Type/Character/ColorChips/CustomColor2Name": current?.customColor2Name = val
                case "Type/Character/ColorChips/CustomColor2AHex":
                    if let cHex = CharacterSettingsCodec.hexToColor(val) { current?.customColor2A = cHex }
                case "Type/Character/ColorChips/CustomColor2BHex":
                    if let cHex = CharacterSettingsCodec.hexToColor(val) { current?.customColor2B = cHex }

                // 社交
                case "Type/Character/Impression": current?.impression = val
                case "Type/Character/MostLikable": current?.mostLikable = val
                case "Type/Character/NativeFamily": current?.nativeFamily = val

                case "Type/Character/ShowLove/Language": current?.showLoveLanguage = (val == "true" || val == "1")
                case "Type/Character/ShowLove/Accompany": current?.showLoveAccompany = (val == "true" || val == "1")
                case "Type/Character/ShowLove/Gift": current?.showLoveGift = (val == "true" || val == "1")
                case "Type/Character/ShowLove/Service": current?.showLoveService = (val == "true" || val == "1")
                case "Type/Character/ShowLove/Touch": current?.showLoveTouch = (val == "true" || val == "1")
                case "Type/Character/ShowLove/Tease": current?.showLoveTease = (val == "true" || val == "1")
                case "Type/Character/ShowLove/Self": current?.showLoveSelf = (val == "true" || val == "1")
                case "Type/Character/ShowLove/Avoid": current?.showLoveAvoid = (val == "true" || val == "1")
                case "Type/Character/ShowLove/Other": current?.showLoveOther = (val == "true" || val == "1")
                case "Type/Character/ShowLove/OtherText": current?.showLoveOtherText = val

                case "Type/Character/Goodwill/Language": current?.goodwillLanguage = (val == "true" || val == "1")
                case "Type/Character/Goodwill/Accompany": current?.goodwillAccompany = (val == "true" || val == "1")
                case "Type/Character/Goodwill/Gift": current?.goodwillGift = (val == "true" || val == "1")
                case "Type/Character/Goodwill/Service": current?.goodwillService = (val == "true" || val == "1")
                case "Type/Character/Goodwill/Touch": current?.goodwillTouch = (val == "true" || val == "1")
                case "Type/Character/Goodwill/Other": current?.goodwillOther = (val == "true" || val == "1")
                case "Type/Character/Goodwill/OtherText": current?.goodwillOtherText = val

                case "Type/Character/HandleHate/BadWords": current?.hateBadWords = (val == "true" || val == "1")
                case "Type/Character/HandleHate/Violence": current?.hateViolence = (val == "true" || val == "1")
                case "Type/Character/HandleHate/Trick": current?.hateTrick = (val == "true" || val == "1")
                case "Type/Character/HandleHate/Sneaky": current?.hateSneaky = (val == "true" || val == "1")
                case "Type/Character/HandleHate/Avoid": current?.hateAvoid = (val == "true" || val == "1")
                case "Type/Character/HandleHate/Indifferent": current?.hateIndifferent = (val == "true" || val == "1")
                case "Type/Character/HandleHate/RepayKindness": current?.hateRepayKindness = (val == "true" || val == "1")
                case "Type/Character/HandleHate/NoDifference": current?.hateNoDifference = (val == "true" || val == "1")
                case "Type/Character/HandleHate/Other": current?.hateOther = (val == "true" || val == "1")
                case "Type/Character/HandleHate/OtherText": current?.hateOtherText = val

                case "Type/Character/OriginalName": current?.originalName = val
                case "Type/Character/OtherText": current?.otherText = val

                // Relations
                case "Type/Character/Relations/Relation/Name": currentRelation?.name = val
                case "Type/Character/Relations/Relation/Role": currentRelation?.relation = val
                case "Type/Character/Relations/Relation":
                    if let r = currentRelation { current?.relations.append(r) }
                    currentRelation = nil

                // Hinders
                case "Type/Character/Hinders/Hinder/Event": currentHinder?.event = val
                case "Type/Character/Hinders/Hinder/Solve": currentHinder?.solve = val
                case "Type/Character/Hinders/Hinder":
                    if let h = currentHinder { current?.hinders.append(h) }
                    currentHinder = nil

                // Lists <...><Item>
                case "Type/Character/Nicknames/Item":
                    if collectingNicknames { current?.nicknames.append(val) }
                case "Type/Character/Nicknames":
                    collectingNicknames = false

                case "Type/Character/Tags/Item":
                    if collectingTags { current?.tags.append(val) }
                case "Type/Character/Tags":
                    collectingTags = false

                case "Type/Character/LoveToDo/Item":
                    if collectingLoveToDo { current?.loveToDo.append(val) }
                case "Type/Character/LoveToDo":
                    collectingLoveToDo = false

                case "Type/Character/HateToDo/Item":
                    if collectingHateToDo { current?.hateToDo.append(val) }
                case "Type/Character/HateToDo":
                    collectingHateToDo = false

                case "Type/Character/ProficientToDo/Item":
                    if collectingProficientToDo { current?.proficientToDo.append(val) }
                case "Type/Character/ProficientToDo":
                    collectingProficientToDo = false

                case "Type/Character/UnProficientToDo/Item":
                    if collectingUnProficientToDo { current?.unProficientToDo.append(val) }
                case "Type/Character/UnProficientToDo":
                    collectingUnProficientToDo = false

                case "Type/Character/LikeItems/Item":
                    if collectingLikeItems { current?.likeItems.append(val) }
                case "Type/Character/LikeItems":
                    collectingLikeItems = false

                case "Type/Character/HateItems/Item":
                    if collectingHateItems { current?.hateItems.append(val) }
                case "Type/Character/HateItems":
                    collectingHateItems = false

                case "Type/Character/FamiliarItems/Item":
                    if collectingFamiliarItems { current?.familiarItems.append(val) }
                case "Type/Character/FamiliarItems":
                    collectingFamiliarItems = false

                // Int arrays <...><Val>
                case "Type/Character/Approach/Val":
                    if let v = Int(val) { tmpApproach.append(v) }
                case "Type/Character/Approach":
                    if var c = current {
                        c.approach = CharacterSettingsCodec.normalizedIntArray(tmpApproach, count: 12, defaultValue: 50)
                        current = c
                    }

                case "Type/Character/Traits/Val":
                    if let v = Int(val) { tmpTraits.append(v) }
                case "Type/Character/Traits":
                    if var c = current {
                        c.traits = CharacterSettingsCodec.normalizedIntArray(tmpTraits, count: 15, defaultValue: 50)
                        current = c
                    }

                case "Type/Character/CommonAbilities/Val":
                    if let v = Int(val) { tmpCommon.append(v) }
                case "Type/Character/CommonAbilities":
                    if var c = current {
                        c.commonAbilities = CharacterSettingsCodec.normalizedIntArray(tmpCommon, count: 16, defaultValue: 50)
                        current = c
                    }

                case "Type/Character/SocialScales/Val":
                    if let v = Int(val) { tmpSocial.append(v) }
                case "Type/Character/SocialScales":
                    if var c = current {
                        c.socialScales = CharacterSettingsCodec.normalizedIntArray(tmpSocial, count: 10, defaultValue: 50)
                        current = c
                    }

                default: break
                }

                _ = stack.popLast()
                text = ""
            }
        }

        let p = Parser()
        let parser = XMLParser(data: data)
        parser.delegate = p
        if parser.parse(), p.isCharactersBlock {
            return p.chars
        }
        return nil
    }
}
