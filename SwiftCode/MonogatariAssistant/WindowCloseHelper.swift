//
//  WindowCloseHelper.swift
//  MonogatariAssistant
//
//  Created by 部屋いる on 2025/9/7.
//

#if os(macOS)
import AppKit

final class WindowCloseHelper: NSObject, NSWindowDelegate {
    static let shared = WindowCloseHelper()
    private override init() {}

    func installOnKeyWindow() {
        DispatchQueue.main.async {
            if let win = NSApp.keyWindow ?? NSApp.windows.first {
                win.delegate = self
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 攔截關閉：先詢問是否儲存，選擇儲存/不儲存 -> 結束程式；取消 -> 不關閉
        DirtyStateManager.shared.confirmProceedIfDirty(reason: "結束程式") {
            NSApplication.shared.terminate(nil)
        }
        return false
    }
}
#endif
