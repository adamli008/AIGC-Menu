//
//  SettingsManager.swift
//  AIGC-Menu
//
//  Created by adam li on 2024/1/2.
//

import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    @Published var enabledTasks: Set<Int> = Set(1...6)
    static let shared = SettingsManager()
    
    private init() {
        if let savedTasks = UserDefaults.standard.array(forKey: "EnabledTasks") as? [Int] {
            enabledTasks = Set(savedTasks)
        }
    }
    
    func toggleTask(_ taskNumber: Int) {
        if enabledTasks.contains(taskNumber) {
            enabledTasks.remove(taskNumber)
        } else {
            enabledTasks.insert(taskNumber)
        }
        UserDefaults.standard.set(Array(enabledTasks), forKey: "EnabledTasks")
        
        // 强制更新 UI
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
            // 强制刷新整个菜单栏
            NSApp.mainMenu?.update()
            // 发送通知以触发菜单重建
            NotificationCenter.default.post(
                name: NSNotification.Name("RefreshMenu"),
                object: nil
            )
        }
    }
}

