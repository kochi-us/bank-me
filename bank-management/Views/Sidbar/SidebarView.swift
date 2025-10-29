//
//  SidebarView.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @EnvironmentObject private var store: AppStore
    @State private var showNameEditor = false
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    
    var body: some View {
        List(selection: $selection) {
            // プロフィール
            Section {
                Button { showNameEditor = true } label: {
                    PersonBadge(name: store.personName, avatar: store.avatar)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showNameEditor) { profileSheet }
            }
            
            // 口座
            Section("bank account") {
                ForEach(store.accounts) { acc in
                    Label(acc.name, systemImage: "building.columns")
                        .tag(SidebarItem.account(acc))   // NavigationLinkではなく tag で選択反映
                }
            }
            
            // 管理
            Section("to manage") {
                Label("bank account", systemImage: "banknote")
                    .tag(SidebarItem.accounts)
                Label("credit card", systemImage: "creditcard")
                    .tag(SidebarItem.creditCards)
                Label("categories", systemImage: "square.grid.2x2")
                    .tag(SidebarItem.categories)
            }
            
            // クイック
            Section("today or all time") {
                Label("all", systemImage: "tray.full")
                    .tag(SidebarItem.all)
            }
            
            // 年月
            Section("year and month") {
                yearStepper
                monthGrid
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: (NSScreen.main?.visibleFrame.width ?? 1000) * 0.8)
    }
    
    // 年度ステッパー
    private var yearStepper: some View {
        HStack {
            Button { selectedYear -= 1 } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
            
            Spacer()
            
            Text(verbatim: String(selectedYear))
                .font(.headline)
            
            Spacer()
            
            Button { selectedYear += 1 } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var monthGrid: some View {
        let cols = [GridItem(.adaptive(minimum: 44), spacing: 6)]
        LazyVGrid(columns: cols, spacing: 6) {
            ForEach(1...12, id: \.self) { m in
                Button {
                    selection = .month(selectedYear, m)
                } label: {
                    Text("\(m)")
                        .font(.callout)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .foregroundColor(isSelectedMonth(m) ? .white : .primary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .background(isSelectedMonth(m) ? Color.accentColor.opacity(0.15) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelectedMonth(m) ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func isSelectedMonth(_ m: Int) -> Bool {
        guard case let .month(y, mm) = selection else { return false }
        return y == selectedYear && mm == m
    }
    
    @ViewBuilder
    private var profileSheet: some View {
        VStack(spacing: 16) {
            Text("プロフィール編集").font(.headline)
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 220, height: 220)
#if os(macOS)
                if let img = store.avatar {
                    Image(nsImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 220, height: 220)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 48))
                        Text("ここに画像をドロップ")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                }
#endif
            }
#if os(macOS)
            .onDrop(of: [UTType.image, UTType.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }
#endif
            TextField("名前", text: $store.personName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
            
            HStack(spacing: 8) {
#if os(macOS)
                Button("ファイルから選ぶ…") { pickImageWithPanel() }
                Button("クリップボードから貼り付け") { pasteFromClipboard() }
#endif
                if store.avatar != nil {
                    Button("画像を削除", role: .destructive) { store.avatar = nil }
                }
                Spacer()
                Button("完了") { showNameEditor = false }
                    .keyboardShortcut(.return)
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }
}

#if os(macOS)
private extension SidebarView {
    func pickImageWithPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { resp in
            guard resp == .OK,
                  let url = panel.url,
                  let data = try? Data(contentsOf: url),
                  let img = NSImage(data: data) else { return }
            store.avatar = img
        }
    }
    
    func pasteFromClipboard() {
        let pb = NSPasteboard.general
        if let img = pb.readObjects(forClasses: [NSImage.self])?.first as? NSImage {
            store.avatar = img
            return
        }
        if let data = pb.data(forType: .tiff),
           let img = NSImage(data: data) {
            store.avatar = img
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                if let data, let img = NSImage(data: data) {
                    DispatchQueue.main.async { store.avatar = img }
                }
            }
            return true
        }
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let urlData = item as? Data,
                      let url = URL(dataRepresentation: urlData, relativeTo: nil),
                      let data = try? Data(contentsOf: url),
                      let img = NSImage(data: data) else { return }
                DispatchQueue.main.async { store.avatar = img }
            }
            return true
        }
        return false
    }
}
#endif

#Preview {
    SidebarView(selection: .constant(.today))
        .environmentObject(AppStore())
}
