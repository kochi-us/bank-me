//
//  TransactionFormView.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/13.
//

import SwiftUI
import Combine

struct TransactionFormView: View {
    @EnvironmentObject private var store: AppStore
    
    var editing: Transaction?
    var preferredAccount: Account?
    var onSave: (Transaction) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var date: Date = Date()
    @State private var amountText: String = ""
    @FocusState private var amountFocused: Bool
    
    // 半角化 + 記号整理
    private func halfwidthAndClean(_ s: String) -> String {
        var x = s.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? s
        x = x.replacingOccurrences(of: "円", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        // マイナス/プラスの全角互換
        x = x.replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "ー", with: "-")
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: "＋", with: "+")
        return x
    }
    
    // 「1億2,345万6789」形式の簡易対応（億・万・下位）
    private func parseWithManOku(_ s: String) -> Double? {
        let x = halfwidthAndClean(s)
        if x.isEmpty { return nil }
        // まずシンプル数値ならそのまま
        if let simple = Double(x) { return simple }
        // 億/万を拾う
        var rest = x
        var total: Double = 0
        if let range = rest.range(of: "億") {
            let head = String(rest[..<range.lowerBound])
            if let v = Double(head) { total += v * 100_000_000 }
            rest = String(rest[range.upperBound...])
        }
        if let range = rest.range(of: "万") {
            let head = String(rest[..<range.lowerBound])
            if let v = Double(head) { total += v * 10_000 }
            rest = String(rest[range.upperBound...])
        }
        // 残りは数値として解釈
        let tail = rest
        if let v = Double(tail) { total += v }
        return total
    }
    
    // 表示用フォーマッタ（フォーカス外れたら3桁区切り）
    private let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.maximumFractionDigits = 2
        return f
    }()
    
    private func normalizedAmountText(_ s: String) -> String {
        let x = halfwidthAndClean(s)
        // 入力中は符号・数字・小数点・億/万のみ許可
        let allowed = Set("+-0123456789.億万")
        let filtered = String(x.filter { allowed.contains($0) })
        return filtered
    }
    
    private func parseAmount(_ s: String) -> Double? {
        // 億・万対応込み
        return parseWithManOku(s)
    }
    @State private var memo: String = ""
    @State private var kind: TransactionKind = .expense
    
    @State private var account: Account? = nil
    @State private var fromAccount: Account? = nil
    @State private var toAccount: Account? = nil
    
    @State private var category: Category? = nil
    // カテゴリ検索 UI 用
    @State private var showCategorySearch = false
    @State private var categoryQuery: String = ""
    @State private var card: Category? = nil
    @State private var person: Person? = nil
    
    init(editing: Transaction?, preferredAccount: Account? = nil, onSave: @escaping (Transaction) -> Void) {
        self.editing = editing
        self.preferredAccount = preferredAccount
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Form {
                // 編集前プレビュー
                if let e = editing {
                    Section(header: Text("編集前の内容")) {
                        HStack { Text("日付"); Spacer(); Text(e.date, style: .date) }
                        HStack { Text("種類"); Spacer(); Text(e.kind.rawValue) }
                        HStack {
                            Text("金額"); Spacer()
                            Text(Fmt.decimal.string(from: NSNumber(value: e.amount)) ?? String(Int(e.amount)))
                        }
                        HStack {
                            Text("メモ"); Spacer();
                            Text(e.memo.isEmpty ? "なし" : e.memo)
                                .foregroundStyle(.secondary)
                        }
                        if e.kind == .transfer {
                            HStack {
                                Text("資金移動"); Spacer()
                                Text("\(e.fromAccount?.name ?? "-") → \(e.toAccount?.name ?? "-")")
                            }
                        } else {
                            HStack { Text("口座"); Spacer(); Text(e.account?.name ?? "-") }
                        }
                        // 参考情報（あれば表示）
                        if let c = e.category { HStack { Text("カテゴリ"); Spacer(); Text(c.name) } }
                        if let cd = e.card { HStack { Text("カード"); Spacer(); Text(cd.name) } }
                        if let p = e.person { HStack { Text("人"); Spacer(); Text(p.name) } }
                    }
                }
                Section(header: Text("Record and save")) {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                    
                    Picker("種類", selection: $kind) {
                        ForEach(TransactionKind.allCases) { k in
                            Label(k.rawValue, systemImage: k.symbolName).tag(k)
                        }
                    }
                    
                    HStack {
                        Text("金額")
                        TextField("0", text: $amountText)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 180)
                            .focused($amountFocused)
                            .onChange(of: amountText) { oldValue, newValue in
                                let norm = normalizedAmountText(newValue)
                                if norm != newValue { amountText = norm }
                            }
                            .onSubmit {
                                if let v = parseAmount(amountText) {
                                    amountText = amountFormatter.string(from: NSNumber(value: v)) ?? String(Int(v))
                                }
                            }
                            .onChange(of: amountFocused) { _, focused in
                                if !focused {
                                    if let v = parseAmount(amountText) {
                                        amountText = amountFormatter.string(from: NSNumber(value: v)) ?? String(Int(v))
                                    }
                                }
                            }
#if os(iOS)
                            .keyboardType(.numberPad)
#endif
                    }
                    
                    TextField("メモ", text: $memo)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                }
                
                if kind == .expense || kind == .income || kind == .carryOver || kind == .balance || kind == .cardPayment {
                    Section(header: Text("口座")) {
                        Picker("口座", selection: Binding(
                            get: { account?.id },
                            set: { id in account = store.accounts.first(where: { $0.id == id }) }
                        )) {
                            Text("選択してください").tag(Optional<UUID>(nil))
                            ForEach(store.accounts) { acc in
                                Text(acc.name).tag(Optional<UUID>(acc.id))
                            }
                        }
                    }
                }
                
                if kind == .transfer {
                    Section(header: Text("資金移動")) {
                        Picker("出金(元)口座", selection: Binding(
                            get: { fromAccount?.id },
                            set: { id in fromAccount = store.accounts.first(where: { $0.id == id }) }
                        )) {
                            Text("選択してください").tag(Optional<UUID>(nil))
                            ForEach(store.accounts) { acc in
                                Text(acc.name).tag(Optional<UUID>(acc.id))
                            }
                        }
                        Picker("入金(先)口座", selection: Binding(
                            get: { toAccount?.id },
                            set: { id in toAccount = store.accounts.first(where: { $0.id == id }) }
                        )) {
                            Text("選択してください").tag(Optional<UUID>(nil))
                            ForEach(store.accounts) { acc in
                                Text(acc.name).tag(Optional<UUID>(acc.id))
                            }
                        }
                    }
                }
                
                Section(header: Text("オプション")) {
                    HStack(spacing: 8) {
                        Picker("カテゴリ", selection: Binding(
                            get: { category?.id },
                            set: { id in category = store.categories.first(where: { $0.id == id }) }
                        )) {
                            Text("なし").tag(Optional<UUID>(nil))
                            ForEach(store.categories) { c in
                                Text(c.name).tag(Optional<UUID>(c.id))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        Button {
                            categoryQuery = ""
                            showCategorySearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .help("カテゴリを検索")
                    }
                    Picker("カード", selection: Binding(
                        get: { card?.id },
                        set: { id in card = store.creditCards.first(where: { $0.id == id }) }
                    )) {
                        Text("なし").tag(Optional<UUID>(nil))
                        ForEach(store.creditCards) { c in
                            Text(c.name).tag(Optional<UUID>(c.id))
                        }
                    }
                }
            }
            .onSubmit { if isValid { save() } }
            
            HStack {
                Button("キャンセル") { dismiss() }
                Spacer()
                if editing != nil {
                    Button("元に戻す") { loadEditingIfNeeded() }
                        .help("フォームの入力を編集前の値に戻します")
                }
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .sheet(isPresented: $showCategorySearch) {
            NavigationStack {
                CategorySearchList(
                    categories: store.categories,
                    selected: category,
                    onSelect: { picked in
                        category = picked
                        showCategorySearch = false
                    },
                    onClear: {
                        category = nil
                        showCategorySearch = false
                    },
                    query: $categoryQuery
                )
            }
            .frame(minWidth: 420, minHeight: 520)
        }
        .padding()
        .frame(minWidth: 420, minHeight: 420)
        .onAppear(perform: loadEditingIfNeeded)
        .onReceive(Just(kind).removeDuplicates()) { newKind in
            if newKind == .transfer {
                if fromAccount == nil { fromAccount = account ?? preferredAccount ?? store.accounts.first }
                if toAccount == nil || toAccount?.id == fromAccount?.id {
                    toAccount = store.accounts.first(where: { $0.id != fromAccount?.id })
                    ?? store.accounts.dropFirst().first
                    ?? store.accounts.first
                }
                account = nil
            } else if newKind == .cardUsage {
                // クレジット利用では口座や振替の口座を使わない
                account = nil
                fromAccount = nil
                toAccount = nil
            } else if newKind == .cardPayment {
                // クレジット決済は口座必須・振替口座は不要
                fromAccount = nil
                toAccount = nil
            } else {
                if account == nil { account = preferredAccount ?? store.accounts.first }
                fromAccount = nil; toAccount = nil
            }
        }
    }
    
    private var isValid: Bool {
        let amt = parsedAmount
        guard amt > 0 else { return false }
        switch kind {
        case .expense, .income: return account != nil
        case .transfer: return fromAccount != nil && toAccount != nil && fromAccount?.id != toAccount?.id
        case .carryOver:
            return account != nil
        case .balance:
            return account != nil
        case .cardUsage:
            return card != nil
        case .cardPayment:
            return account != nil && card != nil
        }
    }
    private var parsedAmount: Double { parseAmount(amountText) ?? 0 }
    
    private func loadEditingIfNeeded() {
        guard let e = editing else {
            date = Date()
            amountText = ""
            memo = ""
            kind = .expense
            account = preferredAccount ?? store.accounts.first
            fromAccount = nil
            toAccount = nil
            category = nil
            card = nil
            person = nil
            return
        }
        date = e.date; memo = e.memo
        amountText = Fmt.decimal.string(from: NSNumber(value: e.amount)) ?? ""
        kind = e.kind; category = e.category; card = e.card; person = e.person
        account = e.account; fromAccount = e.fromAccount; toAccount = e.toAccount
    }
    
    private func save() {
        let amt = parsedAmount
        switch kind {
        case .expense, .income, .cardUsage, .cardPayment:
            let result = Transaction(
                id: editing?.id ?? UUID(),
                date: date, amount: amt, memo: memo, kind: kind,
                category: category, card: card, person: person,
                account: account, fromAccount: nil, toAccount: nil, pairID: nil
            )
            onSave(result)
        case .transfer:
            let pid = editing?.pairID ?? UUID()
            let tOut = Transaction(
                id: editing?.id ?? UUID(),
                date: date, amount: amt, memo: memo, kind: .transfer,
                category: nil, card: nil, person: nil,
                account: nil, fromAccount: fromAccount, toAccount: toAccount, pairID: pid
            )
            let tIn = Transaction(
                id: UUID(),
                date: date, amount: amt, memo: memo, kind: .transfer,
                category: nil, card: nil, person: nil,
                account: nil, fromAccount: fromAccount, toAccount: toAccount, pairID: pid
            )
            onSave(tOut); onSave(tIn)
        case .carryOver, .balance:
            guard let account = account else { return }
            // TODO: Implement specific save logic for carryOver/balance if needed
            let result = Transaction(
                id: editing?.id ?? UUID(),
                date: date, amount: amt, memo: memo, kind: kind,
                category: category, card: card, person: person,
                account: account, fromAccount: nil, toAccount: nil, pairID: nil
            )
            onSave(result)
        }
        dismiss()
    }
}

#Preview {
    TransactionFormView(editing: nil, preferredAccount: nil) { _ in }
        .environmentObject(AppStore())
}

private struct CategorySearchList: View {
    let categories: [Category]
    let selected: Category?
    var onSelect: (Category) -> Void
    var onClear: () -> Void
    @Binding var query: String
    
    private var filtered: [Category] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            return categories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        let normQ = (q.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? q).lowercased()
        return categories.filter { c in
            let n = (c.name.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? c.name).lowercased()
            return n.contains(normQ)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        List {
            if selected != nil {
                Section {
                    Button(role: .destructive) { onClear() } label: {
                        Label("カテゴリをクリア（なし）", systemImage: "xmark.circle")
                    }
                }
            }
            Section(header: Text("候補")) {
                ForEach(filtered) { c in
                    Button {
                        onSelect(c)
                    } label: {
                        HStack {
                            Text(c.name)
                            if c.id == selected?.id { Spacer(); Image(systemName: "checkmark") }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, placement: .automatic, prompt: Text("カテゴリ名を検索"))
        .navigationTitle("カテゴリを検索")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { onClear() }
            }
        }
    }
}
