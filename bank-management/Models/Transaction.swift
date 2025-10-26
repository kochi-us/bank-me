//
//  Transaction.swift
//  bank-management
//
//  SwiftData model
//

import Foundation
import SwiftData

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    /// 取引日
    var date: Date
    /// 金額（正の値）
    var amount: Double
    /// メモ
    var memo: String
    /// 種別（支出 / 収入 / 資金移動）
    var kind: TransactionKind
    
    // 親が消えても履歴は残す（参照だけ nil にする）
    @Relationship(deleteRule: .nullify)
    var category: Category?
    
    /// 関連カード（任意）※現状 Category で代用
    @Relationship(deleteRule: .nullify)
    var card: Category?
    
    @Relationship(deleteRule: .nullify)
    var person: Person?
    
    /// 使用口座（通常取引用）
    @Relationship(deleteRule: .nullify)
    var account: Account?
    
    /// 資金移動用（from → to で2明細を持つ）
    @Relationship(deleteRule: .nullify)
    var fromAccount: Account?
    
    @Relationship(deleteRule: .nullify)
    var toAccount: Account?
    
    /// ペア振替識別子（資金移動の2明細を同一グループとして紐付け）
    var pairID: UUID?
    
    init(
        id: UUID = UUID(),
        date: Date = .now,
        amount: Double = 0,
        memo: String = "",
        kind: TransactionKind = .expense,
        category: Category? = nil,
        card: Category? = nil,
        person: Person? = nil,
        account: Account? = nil,
        fromAccount: Account? = nil,
        toAccount: Account? = nil,
        pairID: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.memo = memo
        self.kind = kind
        self.category = category
        self.card = card
        self.person = person
        self.account = account
        self.fromAccount = fromAccount
        self.toAccount = toAccount
        self.pairID = pairID
    }
}
