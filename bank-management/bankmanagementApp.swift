//
//  bank_managementApp.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

import SwiftUI
import SwiftData

@main
struct BankManagementApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { store.save() }
                }
#if os(macOS)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    store.save()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
                    store.save()
                }
#endif
        }
        // ← WindowGroup の「外」で宣言するのがポイント
        .modelContainer(for: [
            Transaction.self,
            Category.self,
            Account.self,
            Person.self
        ])
    }
}
