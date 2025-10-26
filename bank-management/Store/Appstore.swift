//
//  Appstore.swift
//  bank-management
//
//  Clean single-definition version (2025/10/27)
//

import Foundation
import Combine
#if os(macOS)
import AppKit
#endif

@MainActor
final class AppStore: ObservableObject {
    // MARK: - Published State
    @Published var categories: [Category] = []
    @Published var accounts: [Account] = []
    @Published var creditCards: [Category] = []
    @Published var transactions: [Transaction] = []
    @Published var personName: String = "kochi"
    @Published var appTitle: String = "Bank Management"
#if os(macOS)
    @Published var avatar: NSImage? = nil
#endif

    private var bag = Set<AnyCancellable>()

    // MARK: - Preview Guard
    private var isRunningInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    // MARK: - Paths
    private var stateURL: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dirName = Bundle.main.bundleIdentifier ?? "com.example.bank-management"
        let dir = base.appendingPathComponent(dirName, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let filename = isRunningInPreviews ? "state.preview.json" : "state.json"
        return dir.appendingPathComponent(filename)
    }

    private var avatarURL: URL {
        let filename = isRunningInPreviews ? "avatar.preview.png" : "avatar.png"
        return stateURL.deletingLastPathComponent().appendingPathComponent(filename)
    }

    // MARK: - Codable Snapshot
    struct AppState: Codable {
        var version: Int = 1
        struct CategoryState: Codable { var id: UUID; var name: String }
        struct AccountState: Codable {
            var id: UUID
            var name: String
            var number: String?
            var branchName: String?
            var branchCode: String?
        }
        struct TransactionState: Codable {
            var id: UUID
            var date: Date
            var amount: Double
            var memo: String
            var kind: TransactionKind
            var categoryID: UUID?
            var cardID: UUID?
            var personID: UUID?
            var accountID: UUID?
            var fromAccountID: UUID?
            var toAccountID: UUID?
            var pairID: UUID?
        }

        var categories: [CategoryState]
        var accounts: [AccountState]
        var creditCards: [CategoryState]
        var transactions: [TransactionState]
        var personName: String
        var appTitle: String
        var avatarFilename: String?
    }

    // MARK: - Save
    func save() {
        guard !isRunningInPreviews else { return }

        // Save avatar (macOS)
#if os(macOS)
        if let img = avatar, let data = img.pngDataCompat {
            do { try data.write(to: avatarURL, options: .atomic) } catch { print("[Persistence] avatar save error:", error) }
        } else {
            try? FileManager.default.removeItem(at: avatarURL)
        }
#endif

        let catStates = categories.map { AppState.CategoryState(id: $0.id, name: $0.name) }
        let cardStates = creditCards.map { AppState.CategoryState(id: $0.id, name: $0.name) }
        let accStates = accounts.map { AppState.AccountState(id: $0.id, name: $0.name, number: $0.number, branchName: $0.branchName, branchCode: $0.branchCode) }
        let txStates = transactions.map { t in
            AppState.TransactionState(
                id: t.id,
                date: t.date,
                amount: t.amount,
                memo: t.memo,
                kind: t.kind,
                categoryID: t.category?.id,
                cardID: t.card?.id,
                personID: t.person?.id,
                accountID: t.account?.id,
                fromAccountID: t.fromAccount?.id,
                toAccountID: t.toAccount?.id,
                pairID: t.pairID
            )
        }

        let state = AppState(
            categories: catStates,
            accounts: accStates,
            creditCards: cardStates,
            transactions: txStates,
            personName: personName,
            appTitle: appTitle,
            avatarFilename: {
#if os(macOS)
                FileManager.default.fileExists(atPath: avatarURL.path) ? "avatar.png" : nil
#else
                nil
#endif
            }()
        )

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted]
        enc.dateEncodingStrategy = .iso8601

        do {
            let data = try enc.encode(state)
            try data.write(to: stateURL, options: .atomic)
            print("[Persistence] saved:", stateURL.path)
        } catch {
            print("[Persistence] save error:", error)
        }
    }

    // MARK: - Load
    func load() {
        guard !isRunningInPreviews else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: stateURL) else { return }
        do {
            let s0 = try dec.decode(AppState.self, from: data)
            let s: AppState
            switch s0.version {
            case 1: s = s0
            default: s = s0
            }

            let cats = s.categories.map { Category(id: $0.id, name: $0.name) }
            let cards = s.creditCards.map { Category(id: $0.id, name: $0.name) }
            let accs  = s.accounts.map { Account(id: $0.id, name: $0.name, number: $0.number, branchName: $0.branchName, branchCode: $0.branchCode) }

            var catByID: [UUID: Category] = [:]
            cats.forEach { catByID[$0.id] = $0 }
            cards.forEach { catByID[$0.id] = $0 }
            var accByID: [UUID: Account] = [:]
            accs.forEach { accByID[$0.id] = $0 }

            let txs = s.transactions.map { st in
                Transaction(
                    id: st.id,
                    date: st.date,
                    amount: st.amount,
                    memo: st.memo,
                    kind: st.kind,
                    category: st.categoryID.flatMap { catByID[$0] },
                    card: st.cardID.flatMap { catByID[$0] },
                    person: nil,
                    account: st.accountID.flatMap { accByID[$0] },
                    fromAccount: st.fromAccountID.flatMap { accByID[$0] },
                    toAccount: st.toAccountID.flatMap { accByID[$0] },
                    pairID: st.pairID
                )
            }

            self.categories = cats
            self.accounts = accs
            self.creditCards = cards
            self.transactions = txs
            self.personName = s.personName
            self.appTitle = s.appTitle

#if os(macOS)
            if let fn = s.avatarFilename,
               fn == "avatar.png",
               FileManager.default.fileExists(atPath: avatarURL.path),
               let imgData = try? Data(contentsOf: avatarURL),
               let img = NSImage(data: imgData) {
                self.avatar = img
            } else {
                self.avatar = nil
            }
#endif
        } catch {
            print("[Persistence] load error:", error)
        }
    }

    // MARK: - Autosave
    private func setupAutosave() {
        var publishers: [AnyPublisher<Void, Never>] = [
            $categories.map { _ in () }.eraseToAnyPublisher(),
            $accounts.map { _ in () }.eraseToAnyPublisher(),
            $creditCards.map { _ in () }.eraseToAnyPublisher(),
            $transactions.map { _ in () }.eraseToAnyPublisher(),
            $personName.map { _ in () }.eraseToAnyPublisher(),
            $appTitle.map { _ in () }.eraseToAnyPublisher()
        ]
#if os(macOS)
        publishers.append($avatar.map { _ in () }.eraseToAnyPublisher())
#endif
        Publishers.MergeMany(publishers)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] in self?.save() }
            .store(in: &bag)
    }

    // MARK: - Init
    init() {
        if !isRunningInPreviews {
            load()
            setupAutosave()
            revealStateFile()        }
    }

    // MARK: - Utils (macOS)
#if os(macOS)
    func revealStateFile() {
        NSWorkspace.shared.activateFileViewerSelecting([stateURL])
    }
#endif
}
