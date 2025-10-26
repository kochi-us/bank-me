//
//  AccountManagerView.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

import SwiftUI

struct AccountManagerView: View {
    @EnvironmentObject private var store: AppStore
    @State private var newName: String = ""
    @State private var newNumber: String = ""
    @State private var newBranchName: String = ""
    @State private var newBranchCode: String = ""
    @State private var editing: Account? = nil
    @State private var editName: String = ""
    @State private var editNumber: String = ""
    @State private var editBranchName: String = ""
    @State private var editBranchCode: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("新しい口座名", text: $newName).textFieldStyle(.roundedBorder).frame(minWidth: 160).onSubmit { add() }
                TextField("口座番号（任意）", text: $newNumber).textFieldStyle(.roundedBorder).frame(minWidth: 120).onSubmit { add() }
                TextField("支店名（任意）", text: $newBranchName).textFieldStyle(.roundedBorder).frame(minWidth: 140).onSubmit { add() }
                TextField("店番（任意/3桁）", text: $newBranchCode).textFieldStyle(.roundedBorder).frame(minWidth: 120).onSubmit { add() }
                Button("追加") { add() }
                    .keyboardShortcut(.return)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || store.accounts.count >= 4)
                    .help(store.accounts.count >= 4 ? "口座は最大4件までです" : "新しい口座を追加")
                if store.accounts.count >= 4 {
                    Text("")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            List {
                ForEach(store.accounts, id: \.id) { a in
                    HStack {
                        Image(systemName: "building.columns")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(a.name)
                            HStack(spacing: 8) {
                                if let num = a.number, !num.isEmpty { Text(num) }
                                if let bn = a.branchName, !bn.isEmpty { Text("/ \(bn)") }
                                if let bc = a.branchCode, !bc.isEmpty { Text("(店番: \(bc))") }
                            }.foregroundStyle(.secondary).font(.caption)
                        }
                        Spacer()
                        Button {
                            // 編集開始：シート表示用に一時値へコピー
                            editing = a
                            editName = a.name
                            editNumber = a.number ?? ""
                            editBranchName = a.branchName ?? ""
                            editBranchCode = a.branchCode ?? ""
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        .help("編集")
                        
                        Button(role: .destructive) { delete(a) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .help("削除")
                    }
                }
            }
        }
        .padding()
        .safeAreaInset(edge: .top) {
            // 右上のサイドバー/インスペクタの開閉ボタンと重ならないように上に余白を追加
            Color.clear.frame(height: 36)
        }
        .sheet(item: $editing) { acc in
            VStack(alignment: .leading, spacing: 12) {
                Text("口座を編集").font(.headline)
                TextField("口座名", text: $editName)
                    .textFieldStyle(.roundedBorder)
                TextField("口座番号（任意）", text: $editNumber)
                    .textFieldStyle(.roundedBorder)
                TextField("支店名（任意）", text: $editBranchName)
                    .textFieldStyle(.roundedBorder)
                TextField("店番（任意/3桁）", text: $editBranchCode)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Spacer()
                    Button("キャンセル") {
                        editing = nil
                    }
                    Button("保存") {
                        // 既存要素の差し替え（@Published発火）＋ 明示保存
                        if let i = store.accounts.firstIndex(where: { $0.id == acc.id }) {
                            // 直接プロパティを更新
                            store.accounts[i].name = editName.trimmingCharacters(in: .whitespaces)
                            store.accounts[i].number = editNumber.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editNumber.trimmingCharacters(in: .whitespaces)
                            store.accounts[i].branchName = editBranchName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editBranchName.trimmingCharacters(in: .whitespaces)
                            store.accounts[i].branchCode = editBranchCode.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editBranchCode.trimmingCharacters(in: .whitespaces)
                            // 念のため再代入で発火を確実化
                            store.accounts[i] = store.accounts[i]
                            store.save()
                        }
                        editing = nil
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 8)
            }
            .padding(16)
            .padding(.top, 16)
            .frame(minWidth: 360)
        }
        .toolbar {
#if os(macOS)
            ToolbarItem(placement: .automatic) {
                Button {
                    store.revealStateFile()
                } label: {
                    Label("保存ファイルを表示", systemImage: "folder")
                }
                .help("保存先の state.json を Finder で開く")
            }
#endif
        }
        .navigationTitle("口座管理")
    }
    
    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard store.accounts.count < 4 else { return }
        guard name.isEmpty == false else { return }
        store.accounts.append(Account(
            name: name,
            number: newNumber.trimmingCharacters(in: .whitespaces),
            branchName: newBranchName.trimmingCharacters(in: .whitespaces),
            branchCode: newBranchCode.trimmingCharacters(in: .whitespaces)
        ))
        newName = ""; newNumber = ""; newBranchName = ""; newBranchCode = ""
        store.save()
    }
    
    private func delete(_ a: Account) {
        store.accounts.removeAll { $0.id == a.id }
        for i in store.transactions.indices {
            if store.transactions[i].account?.id == a.id {
                store.transactions[i].account = nil
            }
        }
        store.save()
    }
}

#Preview {
    AccountManagerView()
        .environmentObject(AppStore())
}
