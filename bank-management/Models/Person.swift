//
//  Person.swift
//  bank-management
//
//  SwiftData model
//

import Foundation
import SwiftData

@Model
final class Person {
    @Attribute(.unique) var id: UUID
    var name: String
    var note: String = ""
    
    // 親(Person) → 子(Transaction.person)
    // 人物を削除しても取引履歴は残す（参照だけ nil に）
    @Relationship(deleteRule: .nullify, inverse: \Transaction.person)
    var transactions: [Transaction] = []
    
    init(id: UUID = UUID(), name: String, note: String = "") {
        self.id = id
        self.name = name
        self.note = note
    }
}
