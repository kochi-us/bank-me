//
//  Formatters.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

import Foundation

enum Fmt {
    static let currency: NumberFormatter = {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "ja_JP")
        nf.numberStyle = .currency
        return nf
    }()
    static let decimal: NumberFormatter = {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "ja_JP")
        nf.numberStyle = .decimal
        nf.groupingSeparator = ","
        nf.groupingSize = 3
        return nf
    }()
    static let date: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "yyyy年M月d日(E)"
        return df
    }()
    static let month: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP")
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "yyyy年M月"
        return df
    }()
}

func money(_ value: Double) -> String {
    Fmt.currency.string(from: NSNumber(value: value)) ?? "¥0"
}
func dateString(_ date: Date) -> String {
    Fmt.date.string(from: date)
}
func monthString(_ year: Int, _ month: Int) -> String {
    var comps = DateComponents()
    comps.year = year; comps.month = month; comps.day = 1
    let cal = Calendar(identifier: .gregorian)
    if let d = cal.date(from: comps) { return Fmt.month.string(from: d) }
    return "\(year)年\(month)月"
}
