//
//  AccountDetailView.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

import SwiftUI

struct AccountDetailView: View {
    @EnvironmentObject private var store: AppStore
    var account: Account
    @Binding var searchText: String
    
    
    @State private var editing: Transaction? = nil
    @State private var selection = Set<Transaction.ID>()
    
    // 期間セレクタ用の状態
    private enum UIScope: String, CaseIterable, Identifiable {
        case today = "今日"
        case thisMonth = "今月"
        case byMonth = "月指定"
        case all = "すべて"
        var id: String { rawValue }
    }
    @State private var uiScope: UIScope = .thisMonth
    @State private var selectedYear  = Calendar.current.component(.year,  from: Date())
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    
    // MARK: - データ構築
    // 1) この口座に関係するトランザクションを抽出
    private var relatedTransactions: [Transaction] {
        store.transactions.filter { t in
            if let acc = t.account, acc.id == account.id { return true }      // 通常取引
            if let f = t.fromAccount, f.id == account.id { return true }      // 振替: 出金側
            if let to = t.toAccount, to.id == account.id { return true }      // 振替: 入金側
            return false
        }
    }
    
    // 2) 振替は「ペアID（pairID）」で重複排除し、口座視点で代表1件に正規化
    private var items: [Transaction] {
        var result: [Transaction] = []
        var usedPair = Set<UUID>()
        
        // pairID があるものはペア化、無いものは単独扱い
        for t in relatedTransactions {
            if let pid = t.pairID {
                if usedPair.contains(pid) { continue } // すでに同ペアを追加済み
                
                // 同じ pairID の相方を探す
                let pair = store.transactions.filter { $0.pairID == pid }
                
                // 表示・集計は「この口座に対して意味のある側」を代表にする
                // 優先：この口座への入金（to）> この口座からの出金（from）> どちらでもない（保険）
                if let incoming = pair.first(where: { $0.toAccount?.id == account.id }) {
                    result.append(incoming)
                } else if let outgoing = pair.first(where: { $0.fromAccount?.id == account.id }) {
                    result.append(outgoing)
                } else {
                    // ここに来るのは異常ケースだが、t を入れておく
                    result.append(t)
                }
                usedPair.insert(pid)
            } else {
                // 非ペア（通常取引や carryOver / balance）
                result.append(t)
            }
        }
        
        return result.sorted { $0.date > $1.date }
    }
    
    // 2.5) 期間セレクタによる日付フィルタ（境界は [start, end) の半開区間で厳密に）
    private var dateFilteredItems: [Transaction] {
        let cal = Calendar.current
        func monthBounds(year: Int, month: Int) -> (start: Date, end: Date)? {
            let m = max(1, min(month, 12))
            guard let rawStart = cal.date(from: DateComponents(year: year, month: m, day: 1)) else { return nil }
            // 念のため 0:00 に正規化
            let start = cal.startOfDay(for: rawStart)
            guard let end = cal.date(byAdding: .month, value: 1, to: start) else { return nil }
            return (start, end)
        }
        
        switch uiScope {
        case .today:
            // 当日 0:00 〜 翌日 0:00（半開区間）
            let todayStart = cal.startOfDay(for: Date())
            let todayEnd = cal.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
            return items.filter { $0.date >= todayStart && $0.date < todayEnd }
            
        case .thisMonth:
            let comps = cal.dateComponents([.year, .month], from: Date())
            if let y = comps.year, let m = comps.month, let (start, end) = monthBounds(year: y, month: m) {
                return items.filter { $0.date >= start && $0.date < end }
            }
            return items
            
        case .byMonth:
            if let (start, end) = monthBounds(year: selectedYear, month: selectedMonth) {
                return items.filter { $0.date >= start && $0.date < end }
            }
            return items
            
        case .all:
            return items
        }
    }
    
    // 3) 合計（振替はネット額のみ計上：from=-amount / to=+amount の片側だけ）
    private var total: Double {
        dateFilteredItems.reduce(0) { acc, t in
            // 金額は絶対値に統一してから符号を与える（負値が混ざっても二重符号にならないように）
            let amt = abs(t.amount)
            switch t.kind {
            case .income:
                return acc + amt
            case .expense:
                return acc - amt
            case .transfer:
                if t.fromAccount?.id == account.id { return acc - amt }
                if t.toAccount?.id   == account.id { return acc + amt }
                return acc
            case .cardUsage:
                // クレジット利用は口座残高に影響しない（支払い確定時に反映）
                return acc
            case .cardPayment:
                return acc - amt
            case .carryOver, .balance:
                // 期首残高/繰越はプラスとして扱う
                return acc + amt
            }
        }
    }
    
    private var subtitle: String {
        let num = account.number?.isEmpty == false ? account.number! : "-"
        let brn = account.branchName?.isEmpty == false ? account.branchName! : "-"
        let brc = account.branchCode?.isEmpty == false ? account.branchCode! : "-"
        return "口座番号: \(num)  /  支店: \(brn)  /  店番: \(brc)"
    }
    
    // 4) 検索フィルタ（Toolbar の searchText を反映）
    private var filteredItems: [Transaction] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return dateFilteredItems }
        let needle = q.lowercased()
        return dateFilteredItems.filter { t in
            // メモ
            if t.memo.lowercased().contains(needle) { return true }
            // 種類（支出/収入/資金移動/クレジット利用/クレジット決済/繰越/残高 など）
            if t.kind.rawValue.lowercased().contains(needle) { return true }
            // 口座名（単独 or 振替の from/to）
            if t.account?.name.lowercased().contains(needle) == true { return true }
            if t.fromAccount?.name.lowercased().contains(needle) == true { return true }
            if t.toAccount?.name.lowercased().contains(needle) == true { return true }
            // カテゴリ名
            if t.category?.name.lowercased().contains(needle) == true { return true }
            // カード名
            if t.card?.name.lowercased().contains(needle) == true { return true }
            return false
        }
    }
    
    // MARK: - UI
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("口座: \(account.name)").font(.title2.bold())
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack {
                Spacer()
                Text("total: \(money(total))")
                    .font(.system(size: 20, weight: .bold))
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            // ——— 期間セレクタ（total の下に配置）———
            HStack(spacing: 12) {
                Picker("期間", selection: $uiScope) {
                    Text(UIScope.today.rawValue).tag(UIScope.today)
                    Text(UIScope.thisMonth.rawValue).tag(UIScope.thisMonth)
                    Text(UIScope.byMonth.rawValue).tag(UIScope.byMonth)
                    Text(UIScope.all.rawValue).tag(UIScope.all)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                
                if uiScope == .byMonth {
                    HStack(spacing: 12) {
                        Button { selectedYear -= 1 } label: { Image(systemName: "chevron.left") }
                            .buttonStyle(.borderless)
                        Text(String(selectedYear))
                            .font(.headline)
                            .monospacedDigit()
                        Button { selectedYear += 1 } label: { Image(systemName: "chevron.right") }
                            .buttonStyle(.borderless)
                        Picker("", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) { m in
                                Text("\(m)").tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(minWidth: 300)
                    }
                    .transition(.opacity)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
            
            Table(of: Transaction.self, selection: $selection) {
                TableColumn("") { t in
                    if t.pairID != nil {
                        Image(systemName: "link").help("振替ペア")
                    }
                }
                .width(28)
                
                TableColumn("日付") { tx in
                    Text(dateString(tx.date))
                }
                
                TableColumn("種類") { tx in
                    Label(tx.kind.rawValue, systemImage: tx.kind.symbolName)
                }
                
                // 振替は「A → B」で表示（代表側のみ表示される）
                TableColumn("口座") { tx in
                    if tx.kind == .transfer {
                        Text("\(tx.fromAccount?.name ?? "?") → \(tx.toAccount?.name ?? "?")")
                    } else {
                        Text(tx.account?.name ?? "-")
                    }
                }
                
                TableColumn("カテゴリ") { tx in
                    Text(tx.category?.name ?? "-")
                }
                
                TableColumn("card") { tx in
                    Text(tx.card?.name ?? "-")
                }
                
                TableColumn("メモ") { tx in
                    Text(tx.memo)
                }
                
                TableColumn("金額") { tx in
                    Text(money(tx.amount))
                }
                TableColumn("") { tx in
                    Button(role: .destructive) {
                        delete(tx)
                    } label: {
                        Image(systemName: "trash.fill")
                            .foregroundStyle(.white)
                            .imageScale(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .help("この取引を削除")
                }
                .width(36)
            } rows: {
                ForEach(filteredItems, id: \.id) { t in
                    TableRow(t)
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
                }
            }
            .frame(minHeight: 340)
        }
        .padding()
        .onDeleteCommand { deleteSelected() }
        
        .sheet(item: $editing) { original in
            TransactionFormView(editing: original, preferredAccount: account) { result in
                if result.kind == .transfer, let pid = result.pairID {
                    // 🔸 振替編集では既存ペアを丸ごと削除してから再挿入
                    store.transactions.removeAll { $0.pairID == pid }
                    
                    guard let from = result.fromAccount, let to = result.toAccount else { return }
                    let newPID = result.pairID ?? UUID()
                    
                    // 振替ではメモを空欄にする（自動入力しない）
                    let cleanMemo = ""
                    
                    let tOut = Transaction(
                        id: UUID(),
                        date: result.date,
                        amount: result.amount,
                        memo: cleanMemo,
                        kind: .transfer,
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
                        fromAccount: from,
                        toAccount: to,
                        pairID: newPID
                    )
                    store.transactions.insert(contentsOf: [tOut, tIn], at: 0)
                } else {
                    // 通常取引は単純 upsert
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
        .navigationTitle(account.name)
    }
    
    // MARK: - Actions
    
    private func delete(_ t: Transaction) {
        let ids: Set<UUID> = (t.pairID != nil)
        ? Set(store.transactions.filter { $0.pairID == t.pairID }.map { $0.id })
        : [t.id]
        store.transactions.removeAll { ids.contains($0.id) }
        store.save()
        selection.subtract(ids)
    }
    
    private func deleteSelected() {
        var ids = selection
        let selectedPairIDs = Set(store.transactions
            .filter { ids.contains($0.id) }
            .compactMap { $0.pairID })
        
        if !selectedPairIDs.isEmpty {
            let pairedIds = store.transactions
                .filter { tx in
                    guard let pid = tx.pairID else { return false }
                    return selectedPairIDs.contains(pid)
                }
                .map { $0.id }
            ids.formUnion(pairedIds)
        }
        
        store.transactions.removeAll { ids.contains($0.id) }
        store.save()
        selection.removeAll()
    }
}

#Preview {
    let store = AppStore()
    let acc = Account(name: "テスト口座", number: "1234567", branchName: "本店", branchCode: "001")
    store.accounts = [acc]
    return AccountDetailView(account: acc, searchText: .constant(""))
        .environmentObject(store)
}
