//
//  Account.swift
//  bank-management
//
//  SwiftData model
//

import Foundation
import SwiftData

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    /// 口座番号（任意）
    var number: String?
    /// 支店名（任意）
    var branchName: String?
    /// 支店コード（任意）
    var branchCode: String?
    
    // 親(Account) → 子(Transaction.account)
    // 口座削除は履歴保護のため「不可（deny）」にする
    @Relationship(deleteRule: .deny, inverse: \Transaction.account)
    var transactions: [Transaction] = []
    
    // 資金移動の出庫側（fromAccount）
    @Relationship(deleteRule: .deny, inverse: \Transaction.fromAccount)
    var transfersOut: [Transaction] = []
    
    // 資金移動の入庫側（toAccount）
    @Relationship(deleteRule: .deny, inverse: \Transaction.toAccount)
    var transfersIn: [Transaction] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        number: String? = nil,
        branchName: String? = nil,
        branchCode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.number = number
        self.branchName = branchName
        self.branchCode = branchCode
    }
    
    // （任意）便利プロパティ
    var hasAnyTransactions: Bool {
        !(transactions.isEmpty && transfersOut.isEmpty && transfersIn.isEmpty)
    }
}
