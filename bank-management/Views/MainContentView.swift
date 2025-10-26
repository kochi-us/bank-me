//
//  MainContentView.swift
//  bank-management
//
//  Created by KOCHI on 2025/10/14.
//

import SwiftUI
import Combine

struct MainContentView: View {
    @EnvironmentObject private var store: AppStore
    
    // 起動/復帰時にサイドバー選択を復元（SidebarItem は Codable）
    @SceneStorage("sidebarSelection")
    private var selectionData: Data?
    
    @State private var selection: SidebarItem? = .today
    @State private var showNewForm = false
    @State private var editing: Transaction? = nil
    @State private var searchText: String = ""
    @State private var showInspector: Bool = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selection: Binding(
                get: { selection },
                set: { newValue in
                    selection = newValue
                    persistSelection()
                }
            ))
        } detail: {
            detail
        }
        .sheet(isPresented: $showNewForm) {
            TransactionFormView(editing: editing, preferredAccount: nil) { result in
                upsert(result)
                store.save()
            }
            .environmentObject(store) // ← Preview/実機でのクラッシュ防止
        }
        .overlay(alignment: .trailing) {
            if showInspector {
                RightInspectorView(onClose: { withAnimation { showInspector = false } })
                    .frame(width: 250)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .background(.thinMaterial)
                    .shadow(radius: 8)
            }
        }
        .overlay(alignment: .topTrailing) {
            InspectorToggleButton(isOpen: $showInspector)
                .padding(12)
        }
        .toolbar {
            // 🔍 検索
            ToolbarItem(placement: .principal) {
                TextField("search", text: $searchText)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 320)
            }
            // ➕ 追加
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = nil
                    showNewForm = true
                } label: {
                    Label("新規", systemImage: "plus")
                }
            }
        }
        .onAppear(perform: restoreSelection)
    }
    
    // MARK: - Detail Router
    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .today:
            TransactionListView(scope: .today, searchText: $searchText)
                .id(selection) // ensure refresh when switching Today ⇄ Month
        case .all:
            TransactionListView(scope: .all, searchText: $searchText)
                .id(selection) // ensure refresh when switching All ⇄ Month
        case .categories:
            CategoryManagerView()
        case .accounts:
            AccountManagerView()
        case .creditCards:
            CreditCardUsageView(searchText: $searchText)
        case .accountID(let id):
            if let acc = store.accounts.first(where: { $0.id == id }) {
                AccountDetailView(account: acc, searchText: $searchText)
            } else {
                ContentUnavailableView("口座が見つかりません", systemImage: "exclamationmark.triangle", description: Text("サイドバーから別の項目を選択してください"))
            }
        case .month(let y, let m):
            TransactionListView(scope: .month(y, m), searchText: $searchText)
                .id("month-\(y)-\(m)") // force rebuild when changing month-to-month
        case .none:
            ContentPlaceholderView()
        }
    }
    
    // MARK: - Persist selection
    private func persistSelection() {
        guard let sel = selection else {
            selectionData = nil
            return
        }
        selectionData = try? JSONEncoder().encode(sel)
    }
    
    private func restoreSelection() {
        if let data = selectionData,
           let sel = try? JSONDecoder().decode(SidebarItem.self, from: data) {
            selection = sel
        } else {
            selection = .today
        }
    }
    
    // MARK: - Upsert
    private func upsert(_ t: Transaction) {
        if let idx = store.transactions.firstIndex(where: { $0.id == t.id }) {
            store.transactions[idx] = t
        } else {
            store.transactions.insert(t, at: 0)
        }
    }
}

// 既存のままでOK（呼び出し元があるなら維持）
enum TransactionScope { case today; case month(Int, Int); case all }

struct ContentPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray").font(.system(size: 48))
            Text("左のサイドバーから表示したい項目を選んでください。")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Right Inspector
private struct RightInspectorView: View {
    var onClose: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("calculator")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            CalculatorPane()
                .padding(12)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Toggle Button
private struct InspectorToggleButton: View {
    @Binding var isOpen: Bool
    var body: some View {
        Button {
            withAnimation(.easeInOut) { isOpen.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                Image(systemName: "chevron.right")
            }
            .font(.title3)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .help(isOpen ? "右サイドバーを閉じる" : "右サイドバーを開く")
    }
}

// MARK: - Calculator
private struct CalculatorPane: View {
    @State private var display: String = "0"
    @State private var lastResult: String = ""
    
    private let rows: [[String]] = [
        ["7","8","9","÷"],
        ["4","5","6","×"],
        ["1","2","3","−"],
        ["0",".","C","＋"],
        ["="]
    ]
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            VStack(alignment: .trailing, spacing: 4) {
                Text(display)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                if !lastResult.isEmpty {
                    Text(lastResult)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 10))
            
            VStack(spacing: 8) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { key in
                            Button { tap(key) } label: {
                                Text(key)
                                    .font(.title3)
                                    .frame(maxWidth: key == "=" ? .infinity : .infinity, minHeight: 36)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }
    
    private func tap(_ key: String) {
        switch key {
        case "C":
            display = "0"
            lastResult = ""
        case "=":
            evaluate()
        case "＋","−","×","÷":
            let op = (key == "＋" ? "+" : key == "−" ? "-" : key == "×" ? "*" : "/")
            append(op)
        default:
            append(key)
        }
    }
    
    private func append(_ s: String) {
        if display == "0", s != ".", s != "+", s != "-", s != "*", s != "/" {
            display = s
        } else {
            display += s
        }
    }
    
    private func evaluate() {
        let expr = display
            .replacingOccurrences(of: "＋", with: "+")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
        
        if let num = NSExpression(format: expr).expressionValue(with: nil, context: nil) as? NSNumber {
            let n = num.doubleValue
            if n.isFinite {
                display = formatNumber(n)
                lastResult = "= \(display)"
            } else {
                lastResult = "エラー"
            }
        } else {
            lastResult = "エラー"
        }
    }
    private func formatNumber(_ x: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 6
        return f.string(from: .init(value: x)) ?? "\(x)"
    }
}

#Preview {
    MainContentView()
        .environmentObject(AppStore())
}
