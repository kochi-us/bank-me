//
//  SidebarItem.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//



//
//  SidebarItem.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

import Foundation

/// サイドバーの項目を表す列挙型
/// - ポイント:
///   - Account本体ではなく UUID 参照を保持（安全・軽量）
///   - Hashable / Identifiable / Codable に準拠して状態保持しやすく
enum SidebarItem: Hashable, Identifiable, Codable {
    case today
    case all
    case categories
    case accounts
    case creditCards
    case accountID(UUID)            // ← Account参照ではなくIDを保持
    case month(Int, Int)
    
    // MARK: - Identifiable
    var id: String {
        switch self {
        case .today:                return "today"
        case .all:                  return "all"
        case .categories:           return "categories"
        case .accounts:             return "accounts"
        case .creditCards:          return "creditCards"
        case .accountID(let id):    return "account_\(id.uuidString)"
        case .month(let y, let m):  return String(format: "month_%04d_%02d", y, m)
        }
    }
    
    // MARK: - 表示名（必要に応じて）
    var title: String {
        switch self {
        case .today:                return "今日"
        case .all:                  return "すべての取引"
        case .categories:           return "カテゴリ"
        case .accounts:             return "口座"
        case .creditCards:          return "クレジットカード"
        case .accountID:            return "口座"
        case .month(let y, let m):  return "\(y)年\(m)月"
        }
    }
    
    var systemImage: String {
        switch self {
        case .today:                return "sun.max"
        case .all:                  return "list.bullet.rectangle"
        case .categories:           return "square.grid.2x2"
        case .accounts:             return "banknote"
        case .creditCards:          return "creditcard"
        case .accountID:            return "banknote.fill"
        case .month:                return "calendar"
        }
    }
}

// MARK: - 便利ヘルパー
extension SidebarItem {
    /// Account から SidebarItem を作る（旧コード互換）
    static func account(_ account: Account) -> SidebarItem {
        .accountID(account.id)
    }
    
    /// UUID から Account 実体を取得する
    func resolvedAccount(in accounts: [Account]) -> Account? {
        guard case let .accountID(id) = self else { return nil }
        return accounts.first(where: { $0.id == id })
    }
    
    /// 今日の年月を持つショートカット
    static var thisMonth: SidebarItem {
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        return .month(comps.year ?? 1970, comps.month ?? 1)
    }
}
