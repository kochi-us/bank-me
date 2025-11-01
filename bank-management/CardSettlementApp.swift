//
//  CardSettlementApp.swift
//  bank-management
//
//  Created by KOCHI HASHIMOTO on 2025/10/31.
//　利用登録済みの編集モーダルシート

import SwiftUI

extension View {
    /// 取引編集シート（共通化）
    /// - Parameters:
    ///   - editing: 編集対象トランザクション（nilで非表示）
    ///   - store: AppStore（保存・更新のために利用）
    func transactionEditSheet(
        editing: Binding<Transaction?>,
        store: AppStore
    ) -> some View {
        self.sheet(item: editing) { original in
            TransactionFormView(editing: original) { result in
                if result.kind == .transfer, let pid = result.pairID {
                    // 振替は編集時に旧ペアを削除→2件生成
                    store.transactions.removeAll { $0.pairID == pid }

                    guard let from = result.fromAccount, let to = result.toAccount else {
                        store.save(); return
                    }
                    let newPID = result.pairID ?? UUID()
                    var baseMemo = result.memo.trimmingCharacters(in: .whitespacesAndNewlines)
                    let toStrip = ["(入金)", "(出金)", "（入金）", "（出金）", "資金移動"]
                    for token in toStrip { baseMemo = baseMemo.replacingOccurrences(of: token, with: "") }
                    let cleanMemo = baseMemo.trimmingCharacters(in: .whitespaces)

                    let tOut = Transaction(
                        id: UUID(),
                        date: result.date,
                        amount: result.amount,
                        memo: cleanMemo,
                        kind: .transfer,
                        category: nil,
                        card: nil,
                        person: nil,
                        account: nil,
                        fromAccount: from,
                        toAccount: to,
                        pairID: newPID
                    )
                    let tIn = Transaction(
                        id: UUID(),
                        date: result.date,
                        amount: result.amount,
                        memo: cleanMemo,
                        kind: .transfer,
                        category: nil,
                        card: nil,
                        person: nil,
                        account: nil,
                        fromAccount: from,
                        toAccount: to,
                        pairID: newPID
                    )
                    store.transactions.insert(contentsOf: [tOut, tIn], at: 0)
                } else {
                    // 通常取引は upsert
                    if let idx = store.transactions.firstIndex(where: { $0.id == result.id }) {
                        store.transactions[idx] = result
                    } else {
                        store.transactions.insert(result, at: 0)
                    }
                }
                store.save()
            }
            .frame(minWidth: 520, minHeight: 420)
        }
    }
}
