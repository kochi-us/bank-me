//
//  TransactionListView.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

import SwiftUI
import Combine
import Foundation
import AppKit

struct TransactionListView: View {
    @EnvironmentObject private var store: AppStore
    let scope: TransactionScope
    
    // 親ビューと同期
    @Binding var searchText: String
    
    @State private var selection = Set<Transaction.ID>()
    @State private var editing: Transaction? = nil
    @State private var didCopySummary: Bool = false
    
    // 右ペイン用：期間セレクタ（今日 / 今月 / 月指定 / すべて）
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
    // Sidebar から渡された scope を上書きする（ユーザーが右ペインで切り替えた時）
    @State private var overrideScope: TransactionScope? = nil
    
    private var base: [Transaction] {
        let effective = overrideScope ?? scope
        switch effective {
        case .today:
            return store.transactions.filter { Calendar.current.isDateInToday($0.date) }
        case .month(let y, let m):
            let cal = Calendar.current
            // 月が 1...12 の範囲外で来ても安全に処理
            let clampedMonth = max(1, min(m, 12))
            guard let firstDay = cal.date(from: DateComponents(year: y, month: clampedMonth, day: 1)) else {
                return []
            }
            // タイムゾーン／DST 跨ぎに強い開始・終了の決め方
            let start = cal.startOfDay(for: firstDay)
            guard let nextMonth = cal.date(byAdding: DateComponents(month: 1), to: start) else {
                return []
            }
            let end = cal.startOfDay(for: nextMonth)
            // ✅ 半開区間に変更（当月のみを厳密に絞る）
            return store.transactions.filter { (start ..< end).contains($0.date) }
        case .all:
            return store.transactions
        }
    }
    
    // 検索用ノーマライズ（全角→半角・小文字化）
    private func norm(_ s: String?) -> String {
        guard let s = s, !s.isEmpty else { return "" }
        let half = s.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? s
        return half.lowercased()
    }
    private func norm(_ s: String) -> String {
        let half = s.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? s
        return half.lowercased()
    }
    
    // 種類検索用のキーワード群（日本語/英語の別名も含める）
    private func kindKeywords(_ kind: TransactionKind) -> [String] {
        switch kind {
        case .income:
            return ["収入", "入金", "income", "+", "プラス"]
        case .expense:
            return ["支出", "出金", "expense", "-", "マイナス"]
        case .transfer:
            return ["資金移動", "振替", "transfer", "移動"]
        case .cardUsage:
            return ["クレジット利用", "クレジット", "カード", "card", "credit"]  // ← これを追加！
        case .cardPayment:
            return ["クレジット決済", "クレジット", "カード", "credit"]
        case .carryOver:
            return ["繰越", "繰り越し", "carryover", "前月繰越", "翌月繰越"]
        case .balance:
            return ["口座残高", "残高", "balance", "bank", "口座"]
        }
    }
    // カード検索用のキーワード群
    private func cardKeywords() -> [String] {
        ["card", "カード", "クレジット", "credit", "デビット", "debit"]
    }
    
    // 検索ロジック（複数キーワード AND・全角スペース対応）
    private var filtered: [Transaction] {
        let sorted = base.sorted { $0.date > $1.date }
        let qNorm = norm(searchText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !qNorm.isEmpty else { return sorted }
        
        // 半角/全角スペースや改行で分割
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "　"))
        let tokens = qNorm.components(separatedBy: separators).filter { !$0.isEmpty }
        
        return sorted.filter { t in
            // すべてのトークンを満たす（AND 条件）
            tokens.allSatisfy { tok in matches(t, token: tok) }
        }
    }
    
    // 「すべて」切替時などに ID 重複があると Table がクラッシュすることがある。
    // 表示直前でもう一度ユニーク化して安全側に倒す。
    private var filteredUnique: [Transaction] {
        var seen = Set<Transaction.ID>()
        return filtered.filter { seen.insert($0.id).inserted }
    }
    private var rowIDs: [Transaction.ID] { filtered.map(\.id) }
    
    // フィールド包含判定（ノーマライズ込み・オプショナル対応）
    private func fieldContains(_ str: String?, _ tok: String) -> Bool {
        let s = norm(str)
        return !s.isEmpty && s.contains(tok)
    }
    
    private func matches(_ t: Transaction, token: String) -> Bool {
        // 種類（kind）での一致
        let kwords = kindKeywords(t.kind).map(norm)
        if kwords.contains(where: { kw in kw == token || kw.contains(token) || token.contains(kw) }) {
            return true
        }
        
        // ✅ カード関連の語が来たらカード名も強めに当てる
        let cwords = cardKeywords().map(norm)
        if cwords.contains(where: { kw in kw == token || kw.contains(token) || token.contains(kw) }) {
            if fieldContains(t.card?.name, token) { return true }
        }
        
        // メモ / カテゴリ / カード
        if fieldContains(t.memo, token) { return true }
        if fieldContains(t.category?.name, token) { return true }
        if fieldContains(t.card?.name, token) { return true }
        
        // 通常取引の口座
        if let acc = t.account {
            if norm(acc.name).contains(token) { return true }
            if fieldContains(acc.number, token) { return true }
            if fieldContains(acc.branchName, token) { return true }
            if fieldContains(acc.branchCode, token) { return true }
        }
        
        // 資金移動（振替）の from / to 口座
        if let from = t.fromAccount {
            if norm(from.name).contains(token) { return true }
            if fieldContains(from.number, token) { return true }
            if fieldContains(from.branchName, token) { return true }
            if fieldContains(from.branchCode, token) { return true }
        }
        if let to = t.toAccount {
            if norm(to.name).contains(token) { return true }
            if fieldContains(to.number, token) { return true }
            if fieldContains(to.branchName, token) { return true }
            if fieldContains(to.branchCode, token) { return true }
        }
        return false
    }
    
    private var total: Double {
        filtered.reduce(0) { sum, t in
            sum + safeLedgerContribution(t)
        }
    }
    
    // カード・振替などを含む一覧の合計で使う符号規則（安全版）
    // - cardPayment: マイナス（支払い）
    // - transfer / balance / carryOver: 集計対象外（0）
    // - それ以外: プラス
    private func safeLedgerContribution(_ t: Transaction) -> Double {
        // NaN/∞ ガード
        guard t.amount.isFinite else { return 0 }
        switch t.kind {
        case .cardPayment:
            return -t.amount
        case .transfer, .balance, .carryOver:
            return 0
        default:
            return t.amount
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ——— 期間セレクタ（上部に配置）———
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
            .padding(.bottom, 20)
            
            Table(of: Transaction.self, selection: $selection) {
                TableColumn("日付") { tx in
                    Text(dateString(tx.date))
                }
                TableColumn("種類") { tx in
                    Label(tx.kind.rawValue, systemImage: tx.kind.symbolName)
                }
                TableColumn("口座") { tx in
                    Text(tx.account?.name ?? "-")
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
                    Button {
                        delete(tx)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.white)
                            .imageScale(.medium)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .help("削除")
                }
            } rows: {
                ForEach(filteredUnique, id: \.id) { t in
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
            .id("\(searchText)|\(uiScope.rawValue)") // 検索/スコープ切替でリフレッシュ
            .frame(minHeight: 360)
            // 表示行が変わったら、存在しないIDを選択から除去
            .onChange(of: rowIDs) { _, newIDs in
                selection = selection.intersection(Set(newIDs))
            }
            // 期間UIを切り替えたら選択をクリア（安全策）
            .onChange(of: uiScope) { _, _ in
                selection.removeAll()
            }
            
            HStack {
                Spacer()
                HStack(spacing: 16) {
                    Text("件数: \(filtered.count)件")
                    Text("合計: \(money(total))")
                        .monospacedDigit()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            copySummary()
                            didCopySummary = true
                        }
                        // 一定時間後にメッセージを消す
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                didCopySummary = false
                            }
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .help("合計をコピー")
                    
                    if didCopySummary {
                        Label("コピーしました", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .opacity))
                    }
                }
                .font(.footnote)
                .textSelection(.enabled)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .padding(.top, 40)
        .padding(.bottom)
        .onChange(of: searchText) { oldValue, newValue in
#if DEBUG
            print("🔍 searchText:", oldValue, "→", newValue)
#endif
        }
        .sheet(item: $editing) { original in
            TransactionFormView(editing: original) { result in
                if result.kind == .transfer, let pid = result.pairID {
                    // 振替は編集時に旧ペアを丸ごと削除してから、出金/入金の2件を再生成する
                    store.transactions.removeAll { $0.pairID == pid }
                    
                    guard let from = result.fromAccount, let to = result.toAccount else {
                        store.save(); return
                    }
                    let newPID = result.pairID ?? UUID()
                    var baseMemo = result.memo.trimmingCharacters(in: .whitespacesAndNewlines)
                    // 既存の固定語・ラベルを除去（半角/全角両対応）
                    let toStrip = ["(入金)", "(出金)", "（入金）", "（出金）", "資金移動"]
                    for token in toStrip {
                        baseMemo = baseMemo.replacingOccurrences(of: token, with: "")
                    }
                    let cleanMemo = baseMemo.trimmingCharacters(in: .whitespaces)
                    
                    let tOut = Transaction(
                        id: UUID(),
                        date: result.date,
                        amount: result.amount,
                        memo: cleanMemo,
                        kind: .transfer,
                        category: nil,
                        card: nil,
                        person: nil,
                        account: nil,
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
                        category: nil,
                        card: nil,
                        person: nil,
                        account: nil,
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
        .onDeleteCommand { deleteSelected() }
        .onAppear {
            // 初期表示時、Sidebar の指定を UI に反映
            switch scope {
            case .today:
                uiScope = .today
            case .month(let y, let m):
                uiScope = .byMonth
                selectedYear = y
                selectedMonth = max(1, min(m, 12))
            case .all:
                uiScope = .all
            }
            applyUIScope()
        }
        .onChange(of: uiScope) { _, _ in
            applyUIScope()
        }
        .onChange(of: selectedYear) { _, _ in
            applyUIScope()
        }
        .onChange(of: selectedMonth) { _, _ in
            applyUIScope()
        }
    }
    
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
        let selectedPairIDs = Set(store.transactions.filter { ids.contains($0.id) }.compactMap { $0.pairID })
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
    private func applyUIScope() {
        switch uiScope {
        case .today:
            overrideScope = .today
        case .thisMonth:
            let now = Date()
            let cal = Calendar.current
            let y = cal.component(.year, from: now)
            let m = cal.component(.month, from: now)
            overrideScope = .month(y, m)
        case .byMonth:
            let clamped = max(1, min(selectedMonth, 12))
            overrideScope = .month(selectedYear, clamped)
        case .all:
            overrideScope = .all
        }
    }
    private func copySummary() {
        let s = "件数: \(filtered.count)件  合計: \(money(total))"
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }
}

#Preview {
    TransactionListView(scope: .all, searchText: .constant(""))
        .environmentObject(AppStore())
}
