//
//  CopilotView.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/8/29.
//

import SwiftUI

struct CopilotView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Copilot")
                .font(.largeTitle)
                .bold()
            Text("AI 協作、靈感擴寫與重寫建議。")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}
