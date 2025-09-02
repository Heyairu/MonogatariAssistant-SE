//
//  WorldSettingsView.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/8/29.
//

import SwiftUI

struct WorldSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("世界設定")
                .font(.largeTitle)
                .bold()
            Text("世界觀、地理、歷史、規則等設定。")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}
