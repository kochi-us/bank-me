//
//  CardSettlementSheet.swift
//  bank-management
//
//  Created by KOCHI HASHIMOTO on 2025/10/31.
//　新規利用のモーダルシート

import SwiftUI

/// カード支払い登録シート（純UI）
/// - 親側が状態・保存ロジックを保持し、このビューは見た目と入力だけを担当
struct CardSettlementSheet: View {
    // 入出力
    let accounts: [Account]
    @Binding var amountText: String
    @Binding var accountID: UUID?
    @Binding var date: Date

    // 有効/無効やアクションは親から渡す
    let canCommit: Bool
    let onCommit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("カード支払いを登録").font(.headline)

            HStack {
                Text("合計")
                TextField("0", text: $amountText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .accentColor(.red)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red, lineWidth: 2)
                    )
                    .onSubmit { onCommit() }
            }

            Picker("決済口座", selection: $accountID) {
                Text("— 口座を選択 —").tag(UUID?.none)
                ForEach(accounts, id: \.id) { a in
                    Text(a.name).tag(Optional(a.id))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 300)
            .disabled(accounts.isEmpty)

            DatePicker("決済日", selection: $date, displayedComponents: .date)
                .datePickerStyle(.field)
                .onSubmit { onCommit() }

            HStack {
                Spacer()
                Button("キャンセル") { onCancel() }
                Button("反映") { onCommit() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCommit)
            }
            .padding(.top, 6)
        }
        .padding(16)
        .frame(minWidth: 420)
    }
}
