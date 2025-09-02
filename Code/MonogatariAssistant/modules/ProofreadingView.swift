//
//  ProofreadingView.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/8/29.
//

import SwiftUI

struct ProofreadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("文本校正")
                .font(.largeTitle)
                .bold()
            Text("拼字、標點符號檢查。")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }
}
