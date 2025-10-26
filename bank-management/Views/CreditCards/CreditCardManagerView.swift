//
//  CreditCardManagerView.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

import SwiftUI

struct CreditCardManagerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var newName: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("新しいクレジットカード名", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { add() }
                    .submitLabel(.done)
                    .frame(minWidth: 260)
                Button("追加") { add() }
                    .keyboardShortcut(.return)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
                .labelStyle(.iconOnly)
                .keyboardShortcut(.cancelAction) // Esc でも閉じる
                .help("閉じる")
            }
            List {
                ForEach(store.creditCards, id: \.id) { c in
                    HStack {
                        Image(systemName: "creditcard")
                        Text(c.name)
                        Spacer()
                        Button(role: .destructive) { delete(c) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                    }
                }
            }
        }
        .padding()
        .navigationTitle("クレジットカード管理")
    }
    
    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard name.isEmpty == false else { return }
        store.creditCards.append(Category(name: name))
        newName = ""
        store.save()
    }
    
    private func delete(_ c: Category) {
        store.creditCards.removeAll { $0.id == c.id }
        for i in store.transactions.indices {
            if store.transactions[i].card?.id == c.id { store.transactions[i].card = nil }
        }
        store.save()
    }
}

#Preview {
    CreditCardManagerView()
        .environmentObject(AppStore())
}
