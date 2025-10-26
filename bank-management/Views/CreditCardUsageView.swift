//
//  CreditCardUsageView.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/21.
//

import SwiftUI
import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// クレジットカードの利用明細ビュー（カード別・期間別・検索対応）
struct CreditCardUsageView: View {
    @EnvironmentObject private var store: AppStore
    
    // 絞り込み
    @Binding var searchText: String
    @State private var selectedCardID: UUID? = nil
    @State private var scope: Scope = .thisMonth
    @State private var showManager = false
    @State private var copiedNotice = false
    @State private var selectedYear  = Calendar.current.component(.year,  from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var editing: Transaction? = nil
    
    enum Scope: String, CaseIterable, Identifiable {
        case today = "今日"
        case thisMonth = "今月"
        case byMonth = "月指定"
        case all = "すべて"
        var id: String { rawValue }
    }
    
    // 表示対象：カードが設定されたトランザクションのみ
    private var filtered: [Transaction] {
        let base = store.transactions.filter {
            $0.card != nil && $0.kind.affectsCreditUsage
        }
        let ranged: [Transaction] = {
            switch scope {
            case .today:
                let cal = Calendar(identifier: .gregorian)
                return base.filter { cal.isDateInToday($0.date) }
            case .thisMonth:
                let cal = Calendar(identifier: .gregorian)
                let comps = cal.dateComponents([.year, .month], from: Date())
                guard let start = cal.date(from: comps),
                      let end   = cal.date(byAdding: .month, value: 1, to: start) else {
                    return base
                }
                return base.filter { $0.date >= start && $0.date < end }
            case .byMonth:
                let cal = Calendar(identifier: .gregorian)
                let y = selectedYear
                let m = max(1, min(selectedMonth, 12))
                guard let start = cal.date(from: DateComponents(year: y, month: m, day: 1)),
                      let end   = cal.date(byAdding: .month, value: 1, to: start) else {
                    return []
                }
                return base.filter { $0.date >= start && $0.date < end }
            case .all:
                return base
            }
        }()
        let byCard = selectedCardID == nil ? ranged : ranged.filter { $0.card?.id == selectedCardID }
        return applySearch(byCard, query: searchText).sorted(by: { $0.date > $1.date })
    }
    
    // 利用額合計（支出を正の額として見せるため abs 合算）
    private var totalAmount: Double {
        filtered.reduce(0) { $0 + abs($1.amount) }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // トップマージンを追加してサイドバー開閉ボタンと重ならないようにする
            headerBar
                .padding(.top, 35)
                .padding(.bottom, 15)
            
            List {
                if groupedByCard.count > 1 && selectedCardID == nil {
                    // 「すべてのカード」時はカードごとに区切る
                    ForEach(
                        groupedByCard.keys.sorted { cardName(for: $0) < cardName(for: $1) },
                        id: \.self
                    ) { cid in
                        Section(header: sectionHeader(cid)) {
                            ForEach(groupedByCard[cid] ?? [], id: \.id) { t in
                                row(t)
                            }
                        }
                    }
                } else {
                    // 単一カード指定 or カード1枚しかない場合
                    ForEach(filtered, id: \.id) { t in
                        row(t)
                    }
                }
            }
            .listStyle(.inset)
            .safeAreaInset(edge: .bottom) {
                footerBar
                    .background(.bar) // 小さめのフッターとして画面下に固定
            }
        }
        .padding()
        .navigationTitle("クレジットカード利用")
        .sheet(isPresented: $showManager) {
            CreditCardManagerView()
                .environmentObject(store)
                .frame(minWidth: 520, minHeight: 420)
        }
        .sheet(item: $editing) { t in
            TransactionFormView(editing: t) { result in
                if let idx = store.transactions.firstIndex(where: { $0.id == result.id }) {
                    store.transactions[idx] = result
                } else {
                    store.transactions.insert(result, at: 0)
                }
                store.save()
            }
            .frame(minWidth: 520, minHeight: 420)
        }
    }
    
    // MARK: - UI
    
    private var headerBar: some View {
        HStack(spacing: 12) {
            Picker("カード", selection: $selectedCardID) {
                Text("すべて").tag(UUID?.none)
                ForEach(store.creditCards, id: \.id) { card in
                    Text(card.name).tag(UUID?.some(card.id))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)
            
            Spacer().frame(width: 20)
            
            Picker("期間", selection: $scope) {
                Text(Scope.today.rawValue).tag(Scope.today)
                Text(Scope.thisMonth.rawValue).tag(Scope.thisMonth)
                Text(Scope.byMonth.rawValue).tag(Scope.byMonth)
                Text(Scope.all.rawValue).tag(Scope.all)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            Spacer().frame(width: 12)
            
            if scope == .byMonth {
                monthSelector
                    .transition(.opacity)
            }
            
            Spacer()
            
            Button {
                showManager = true
            } label: {
                Label("追加", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("クレジットカードを追加")
        }
    }
    
    @ViewBuilder
    private var monthSelector: some View {
        HStack(spacing: 16) {
            Button { selectedYear -= 1 } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
            Text(String(selectedYear))
                .font(.headline)
                .monospacedDigit()
            Button { selectedYear += 1 } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
            Spacer().frame(width: 50)
            Picker("", selection: $selectedMonth) {
                ForEach(1...12, id: \.self) { m in
                    Text("\(m)").tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.leading, 8)
            .frame(width: 260)
        }
    }
    
    private var footerBar: some View {
        let totalStr = Fmt.currency.string(from: NSNumber(value: totalAmount)) ?? "-"
        return HStack(spacing: 8) {
            Spacer()
            Text("件数: \(filtered.count)件")
            Divider().frame(height: 16)
            HStack(spacing: 6) {
                Text("合計: \(totalStr)")
                    .fontWeight(.semibold)
                Button {
                    copyToClipboard(totalStr)
                    withAnimation(.easeInOut(duration: 0.2)) { copiedNotice = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.easeInOut(duration: 0.2)) { copiedNotice = false }
                    }
                } label: {
                    Image(systemName: copiedNotice ? "checkmark.circle.fill" : "doc.on.doc")
                }
                .foregroundStyle(copiedNotice ? .green : .secondary)
                .buttonStyle(.borderless)
                .help("合計をコピー")
                .accessibilityLabel("合計コピー")
                if copiedNotice {
                    Text("コピーしました")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
        .textSelection(.enabled)
    }
    
    // セクション見出し（UUID? ベース）
    private func sectionHeader(_ cardID: UUID?) -> some View {
        HStack {
            Image(systemName: "creditcard")
            Text(cardName(for: cardID))
            Spacer()
            let sum = (groupedByCard[cardID] ?? []).reduce(0) { $0 + abs($1.amount) }
            Text(Fmt.currency.string(from: NSNumber(value: sum)) ?? "-")
                .foregroundStyle(.secondary)
        }
    }
    
    private func row(_ t: Transaction) -> some View {
        HStack(spacing: 12) {
            Text(Fmt.date.string(from: t.date)).monospaced()
                .frame(width: 150, alignment: .leading)
            Text(t.card?.name ?? "—")
                .frame(width: 140, alignment: .leading)
            Text(t.memo.isEmpty ? "（メモなし）" : t.memo)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(t.category?.name ?? "未分類")
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(Fmt.decimal.string(from: NSNumber(value: t.amount)) ?? "-")
                .monospaced()
                .frame(width: 120, alignment: .trailing)
            Button {
                delete(t)
            } label: {
                Image(systemName: "trash")
                    .imageScale(.medium)
                    .padding(4)
            }
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .help("削除")
            .frame(width: 28, alignment: .trailing)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                editing = t
            } label: {
                Label("編集", systemImage: "pencil")
            }
            Button(role: .destructive) {
                delete(t)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
        .onTapGesture(count: 2) {
            // 既存の編集フローに合わせて拡張予定（必要になったら指示してください）
        }
    }
    
    // MARK: - Helpers
    
    // カードIDでグループ化（安定）
    private var groupedByCard: [UUID?: [Transaction]] {
        Dictionary(grouping: filtered, by: { $0.card?.id })
    }
    
    private func cardName(for id: UUID?) -> String {
        guard let id else { return "不明のカード" }
        return store.creditCards.first(where: { $0.id == id })?.name ?? "不明のカード"
    }
    
    private func delete(_ t: Transaction) {
        if let idx = store.transactions.firstIndex(where: { $0.id == t.id }) {
            store.transactions.remove(at: idx)
            store.save()
        }
    }
    
    // —— 検索（シンプル＆堅牢）——
    private func applySearch(_ list: [Transaction], query: String) -> [Transaction] {
        let q = normalize(query)
        guard !q.isEmpty else { return list }
        let tokens = q.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        return list.filter { t in
            tokens.allSatisfy { token in
                contains(normalize(t.memo), token) ||
                contains(normalize(t.category?.name), token) ||
                contains(normalize(t.card?.name), token) ||
                contains(normalize(t.account?.name), token) ||
                contains(normalize(t.account?.number), token) ||
                contains(normalize(t.account?.branchName), token) ||
                contains(normalize(t.account?.branchCode), token)
            }
        }
    }
    private func normalize(_ s: String?) -> String {
        guard let s = s, !s.isEmpty else { return "" }
        let half = s.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? s
        return half.lowercased()
    }
    private func contains(_ field: String, _ token: String) -> Bool {
        guard !field.isEmpty else { return false }
        return field.contains(token.lowercased())
    }
    private func copyToClipboard(_ s: String) {
#if os(macOS)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
#else
        UIPasteboard.general.string = s
#endif
    }
}

#Preview {
    CreditCardUsageView(searchText: .constant(""))
        .environmentObject(AppStore())
}
