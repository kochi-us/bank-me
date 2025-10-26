//
//  CategoryManagerView.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

//
//  CategoryManagerView.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

import Foundation

//
//  CategoryManagerView.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var modelContext
    @State private var newName: String = ""
    @State private var editing: Category? = nil
    @State private var editName: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("新しいカテゴリ名", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { add() }
                    .submitLabel(.done)
                    .frame(minWidth: 220)
                Button("追加") { add() }
                    .keyboardShortcut(.return)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.top,40)
            .padding(.bottom, 13)
            List {
                ForEach(store.categories, id: \.id) { c in
                    HStack {
                        RoundedRectangle(cornerRadius: 6).fill(.secondary).frame(width: 16, height: 16)
                        Text(c.name)
                        Spacer()
                        Button {
                            // 編集開始：シート表示用に一時値へコピー
                            editing = c
                            editName = c.name
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .help("編集")
                        
                        Button(role: .destructive) { delete(c) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .help("削除")
                    }
                }
            }
        }
        .padding()
        .sheet(
            isPresented: Binding(
                get: { editing != nil },
                set: { if !$0 { editing = nil } }
            )
        ) {
            if let cat = editing {
                VStack(alignment: .leading, spacing: 12) {
                    Text("カテゴリを編集").font(.headline)
                    TextField("カテゴリ名", text: $editName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            saveEditedCategory(cat)
                        }
                    
                    HStack {
                        Spacer()
                        Button("キャンセル") {
                            editing = nil
                        }
                        Button("保存") {
                            saveEditedCategory(cat)
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding(.top, 8)
                }
                .padding(16)
                .frame(minWidth: 320)
            } else {
                // 安全策：nil の場合は空ビュー
                EmptyView()
            }
        }
        .navigationTitle("カテゴリ管理")
    }
    
    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard name.isEmpty == false else { return }
        let new = Category(name: name)
        modelContext.insert(new)
        try? modelContext.save()
        store.categories.append(new)
        newName = ""
        store.save()
    }
    
    private func delete(_ c: Category) {
        store.categories.removeAll { $0.id == c.id }
        for i in store.transactions.indices {
            if store.transactions[i].category?.id == c.id { store.transactions[i].category = nil }
        }
        modelContext.delete(c)
        try? modelContext.save()
        store.save()
    }
    
    private func saveEditedCategory(_ original: Category) {
        let name = editName.trimmingCharacters(in: .whitespaces)
        guard name.isEmpty == false else { return }
        
        // SwiftData 側を更新
        original.name = name
        try? modelContext.save()
        
        // @Published 配列の発火対策として差し替え（同一要素の再代入）＋ 明示保存
        if let i = store.categories.firstIndex(where: { $0.id == original.id }) {
            store.categories[i] = store.categories[i]
            store.save()
        } else {
            // 念のため: 見つからないケースでは append して保存
            store.categories.append(original)
            store.save()
        }
        
        editing = nil
    }
}

#Preview {
    CategoryManagerView()
        .environmentObject(AppStore())
}
