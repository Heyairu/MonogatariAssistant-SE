//
//  GlossaryView.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/8/29.
//

import SwiftUI

struct GlossaryView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("詞語參考")
                .font(.largeTitle)
                .bold()
            Text("術語、專有名詞與關鍵詞表。")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}
