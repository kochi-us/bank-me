//
//  Category.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

//
//  Category.swift
//  bank-management
//
//  SwiftData model
//

import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    
    // ✅ deleteRule が先、inverse が後！
    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction] = []
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
