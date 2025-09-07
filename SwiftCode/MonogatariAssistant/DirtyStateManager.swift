//
//  DirtyStateManager.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/9/7.
//

import Foundation
#if os(macOS)
import AppKit
#endif

final class DirtyStateManager: ObservableObject {
    static let shared = DirtyStateManager()
    private init() {}

    // 以「存檔成功後」的專案 XML 當作基準
    @Published private(set) var baseline: String?

    // 由 ContentView 設定：如何取得目前快照、如何嘗試存檔（回傳是否成功）
    var currentSnapshotProvider: (() -> String)?
    var attemptSave: (() -> Bool)?

    func setBaseline(_ xml: String) {
        baseline = xml
    }

    func hasUnsavedChanges() -> Bool {
        guard let base = baseline, let current = currentSnapshotProvider?() else { return false }
        return base != current
    }

    #if os(macOS)
    private func presentUnsavedAlert(reason: String) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = "尚未儲存的更動"
        alert.informativeText = "在\(reason)前，是否先儲存？"
        alert.addButton(withTitle: "儲存")    // 第一個
        alert.addButton(withTitle: "不儲存") // 第二個
        alert.addButton(withTitle: "取消")   // 第三個
        return alert.runModal()
    }

    // 用於「新建」或「開啟」動作前
    func confirmProceedIfDirty(reason: String, onProceed: () -> Void) {
        guard hasUnsavedChanges() else { onProceed(); return }
        switch presentUnsavedAlert(reason: reason) {
        case .alertFirstButtonReturn: // 儲存
            if attemptSave?() == true {
                if let current = currentSnapshotProvider?() { setBaseline(current) }
                onProceed()
            }
        case .alertSecondButtonReturn: // 不儲存
            onProceed()
        default: // 取消
            break
        }
    }

    // 用於「關閉程式」（Command+Q），可在 App.commands 中接管
    func confirmAppQuit() {
        confirmProceedIfDirty(reason: "結束程式") {
            NSApplication.shared.terminate(nil)
        }
    }
    #endif
}
