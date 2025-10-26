//
//  TransactionKind.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

import Foundation

enum TransactionKind: String, CaseIterable, Identifiable, Codable {
    case expense   = "支出"
    case income    = "収入"
    case transfer  = "資金移動"
    case cardUsage = "クレジット利用"   // ← 追加
    case cardPayment  = "クレジット決済"
    case carryOver = "繰越"
    case balance   = "口座残高"
    
    
    var id: String { rawValue }
    
    /// UI用アイコン名（SF Symbols）
    var symbolName: String {
        switch self {
        case .expense:   return "arrow.down.circle.fill"
        case .income:    return "arrow.up.circle.fill"
        case .transfer:  return "arrow.left.arrow.right.circle.fill"
        case .cardUsage: return "creditcard.circle.fill"   // ← 追加
        case .cardPayment:  return "banknote.circle.fill"
        case .carryOver: return "arrow.triangle.2.circlepath.circle.fill"
        case .balance:
            if #available(iOS 16.0, macOS 13.0, *) {
                return "banknote.fill"
            } else {
                return "yensign.circle.fill"
            }
        }
    }
    
    /// 色名（必要なら使う）
    var colorName: String {
        switch self {
        case .expense:   return "red"
        case .income:    return "green"
        case .transfer:  return "blue"
        case .cardUsage: return "indigo"   // ← 追加
        case .cardPayment:  return "orange"
        case .carryOver: return "purple"
        case .balance:   return "teal"
        }
    }
    
    /// 集計の符号：支出=-1, 収入=+1, それ以外=0
    var cashflowSign: Int {
        switch self {
        case .income:     return +1
        case .expense:    return -1
        case .transfer:   return 0
        case .cardUsage:  return 0   // ← 追加（支出扱い）
        case .cardPayment:   return -1
        case .carryOver:  return +1
        case .balance:    return +1
        }
    }
    
    /// クレジット利用集計に含めるか（クレジット決済は除外）
    var affectsCreditUsage: Bool {
        switch self {
        case .cardUsage:
            return true
        default:
            return false
        }
    }
}
