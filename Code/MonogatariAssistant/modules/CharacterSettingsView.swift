//
//  CharacterSettingsView.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/8/29.
//

import SwiftUI

struct CharacterSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("角色設定")
                .font(.largeTitle)
                .bold()
            Text("製作你的角色檔案。")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}
