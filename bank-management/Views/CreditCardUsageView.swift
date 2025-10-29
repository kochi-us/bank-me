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
    // 支払い登録シート用
    @State private var showSettlementSheet = false
    @State private var settleAmountText = ""
    @State private var settleAccountID: UUID? = nil
    @State private var settleDate: Date = Date()
    
    enum Scope: String, CaseIterable, Identifiable {
        case today = "to day"
        case thisMonth = "this month"
        case byMonth = "by month"
        case all = "all"
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
        .sheet(isPresented: $showSettlementSheet) {
            VStack(alignment: .leading, spacing: 12) {
                Text("カード支払いを登録").font(.headline)
                HStack {
                    Text("合計")
                    TextField("0", text: $settleAmountText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .accentColor(.red)
                        .onSubmit { commitSettlement() }
                }
                Picker("決済口座", selection: $settleAccountID) {
                    Text("— 口座を選択 —").tag(UUID?.none)
                    ForEach(store.accounts, id: \.id) { a in
                        Text(a.name).tag(Optional(a.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 300)
                .disabled(store.accounts.isEmpty)
                DatePicker("決済日", selection: $settleDate, displayedComponents: .date)
                    .datePickerStyle(.field)
                    .onSubmit { commitSettlement() }
                HStack {
                    Spacer()
                    Button("キャンセル") { showSettlementSheet = false }
                    Button("反映") { commitSettlement() }
                        .keyboardShortcut(.return)
                        .buttonStyle(.borderedProminent)
                        .disabled(!canCommit)
                }
                .padding(.top, 6)
            }
            .padding(16)
            .frame(minWidth: 420)
            .onAppear {
                // 既定口座（カードに結び付いているもの）が有効ならそれ、なければ先頭口座
                if let preset = store.defaultSettlementAccountID(for: selectedCardID),
                   store.accounts.contains(where: { $0.id == preset }) {
                    settleAccountID = preset
                } else {
                    settleAccountID = store.accounts.first?.id
                }
            }
        }
        // —— Defensive: マスター配列の差し替えで選択が孤立しないように保護 ——
        .onReceive(store.$accounts) { _ in
            if let id = settleAccountID, !store.accounts.contains(where: { $0.id == id }) {
                // 消えた口座IDを検知したら、先頭 or nil にフォールバック
                settleAccountID = store.accounts.first?.id
            }
        }
        .onReceive(store.$creditCards) { _ in
            if let cid = selectedCardID, !store.creditCards.contains(where: { $0.id == cid }) {
                // 消えたカードIDを検知したら、"すべて"（nil）へフォールバック
                selectedCardID = nil
            }
        }
.onChange(of: showSettlementSheet) { oldValue, newValue in
    if newValue, settleAccountID == nil {
        if let preset = store.defaultSettlementAccountID(for: selectedCardID),
           store.accounts.contains(where: { $0.id == preset }) {
            settleAccountID = preset
        } else {
            settleAccountID = store.accounts.first?.id
        }
    }
}
    }
    
    // MARK: - UI
    
    private var headerBar: some View {
        HStack(spacing: 12) {
            // 左：カード選択（固定幅）
            Picker("", selection: $selectedCardID) {
                Text("all").tag(UUID?.none)
                ForEach(store.creditCards, id: \.id) { card in
                    Text(card.name).tag(UUID?.some(card.id))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 55)

            // 中：期間 + 年月選択（可変幅・左寄せ）
            HStack(spacing: 16) {
                Picker("", selection: $scope) {
                    Text(Scope.today.rawValue).tag(Scope.today)
                    Text(Scope.thisMonth.rawValue).tag(Scope.thisMonth)
                    Text(Scope.byMonth.rawValue).tag(Scope.byMonth)
                    Text(Scope.all.rawValue).tag(Scope.all)
                }
                .pickerStyle(.segmented)
                .frame(width: 360)

                if scope == .byMonth {
                    monthSelector
                        .transition(.opacity)
                        .layoutPriority(2) // 年が欠けないよう優先度を上げる
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 右：アクションボタン群

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
        HStack(spacing: 8) {
            Button { selectedYear -= 1 } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
            Text(String(selectedYear))
                .font(.headline)
                .monospacedDigit()
            Button { selectedYear += 1 } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
            Spacer(minLength: 4)
            Picker("", selection: $selectedMonth) {
                ForEach(1...12, id: \.self) { m in
                    Text("\(m)").tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.leading, 1)
            .frame(minWidth: 360, maxWidth: 560)
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
            Divider().frame(height: 16)
            Button {
                // 一括決済（現在の絞り込み結果の合計をまとめて登録）
                let amt = max(0, totalAmount)
                if let s = Fmt.decimal.string(from: NSNumber(value: amt)) {
                    settleAmountText = s
                } else {
                    settleAmountText = String(Int(amt))
                }
                // 既定口座: カードの既定 → 先頭
                settleAccountID = store.defaultSettlementAccountID(for: selectedCardID)
                    ?? store.accounts.first?.id
                // 決済日: 表示中スコープの月末（失敗時は今日）
                let (y, m) = currentYearMonth()
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = .current
                if let start = cal.date(from: DateComponents(year: y, month: m, day: 1)),
                   let next  = cal.date(byAdding: .month, value: 1, to: start),
                   let eom   = cal.date(byAdding: .day, value: -1, to: next) {
                    settleDate = eom
                } else {
                    settleDate = Date()
                }
                showSettlementSheet = true
            } label: {
                Label("まとめて決済…", systemImage: "checklist")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("表示中の利用合計でカード支払いを登録")
            .disabled(store.accounts.isEmpty || filtered.isEmpty)
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
    
    private var canCommit: Bool {
        parsedSettleAmount > 0 && store.account(id: settleAccountID) != nil
    }

    private var parsedSettleAmount: Double {
        let s = settleAmountText
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "円", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(s) ?? 0
    }

    private func currentYearMonth() -> (Int, Int) {
        switch scope {
        case .byMonth:
            return (selectedYear, max(1, min(selectedMonth, 12)))
        case .thisMonth, .today:
            let comps = Calendar.current.dateComponents([.year, .month], from: Date())
            return (comps.year ?? selectedYear, comps.month ?? selectedMonth)
        case .all:
            let comps = Calendar.current.dateComponents([.year, .month], from: Date())
            return (comps.year ?? selectedYear, comps.month ?? selectedMonth)
        }
    }

    private func commitSettlement() {
        guard canCommit, let acc = store.account(id: settleAccountID) else { return }
        let amount = parsedSettleAmount
        // ヘッダーが「すべて」でも、一覧が単一カードならそのカードを自動選択
        let effectiveCardID: UUID? = {
            if let id = selectedCardID { return id }
            let ids = Set(filtered.compactMap { $0.card?.id })
            return ids.count == 1 ? ids.first : nil
        }()
        let cardRef = effectiveCardID.flatMap { cid in store.creditCards.first(where: { $0.id == cid }) }
        let memo = "" // メモは空欄
        let tx = Transaction(
            id: UUID(),
            date: settleDate,
            amount: amount,
            memo: memo,
            kind: .cardPayment,
            category: nil,
            card: cardRef,
            person: nil,
            account: acc,
            fromAccount: nil,
            toAccount: nil,
            pairID: nil
        )
        store.upsertTransaction(tx)
        // 今回選んだ口座を、このカードの既定として覚える
        store.setDefaultSettlementAccountID(settleAccountID, for: effectiveCardID)
        store.save()
        showSettlementSheet = false
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
