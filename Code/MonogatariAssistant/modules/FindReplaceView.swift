//
//  FindReplaceView.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/8/29.
//

import SwiftUI

struct FindReplaceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("搜尋 / 取代")
                .font(.largeTitle)
                .bold()
            Text("搜尋與取代工具。")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}
