//
//  MonogatariAssistantApp.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/8/26.
//

import SwiftUI

@main
struct MonogatariAssistantApp: App {
    @State private var showAbout = false
    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $showAbout) {
                    AboutView()
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("關於本程式…") {
                    showAbout = true
                }
            }
            CommandGroup(replacing: .appTermination) {
                Button("結束 MonogatariAssistant") {
                    DirtyStateManager.shared.confirmAppQuit()
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
        }
    }
}
