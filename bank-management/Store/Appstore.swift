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
import UniformTypeIdentifiers
#endif

@MainActor
final class AppStore: ObservableObject {
    // MARK: - Published State
    @Published var categories: [Category] = []
    @Published var accounts: [Account] = []
    @Published var creditCards: [Category] = []
    /// key: カードID, value: 支払い口座ID
    @Published var cardPaymentAccount: [UUID: UUID] = [:]
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
        var cardPaymentAccount: [UUID: UUID]? // v1 では未導入のため Optional で後方互換
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
            cardPaymentAccount: self.cardPaymentAccount,
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
            self.cardPaymentAccount = s.cardPaymentAccount ?? [:]
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
#if os(macOS)
            autoBackupOnLaunch(maxCopies: 7)
#endif
        }
    }

    // MARK: - Utils (macOS)
#if os(macOS)
    /// アプリ起動時に自動バックアップを作成し、古いものはローテーションで削除します。
    /// - Parameter maxCopies: 残すバックアップの最大個数（古い順に削除）
    private func autoBackupOnLaunch(maxCopies: Int = 7) {
        let fm = FileManager.default
        let sourceDir = stateURL.deletingLastPathComponent()
        let backupsRoot = sourceDir.appendingPathComponent("Backups", isDirectory: true)
        do {
            if !fm.fileExists(atPath: backupsRoot.path) {
                try fm.createDirectory(at: backupsRoot, withIntermediateDirectories: true)
            }
            // タイムスタンプフォルダ作成
            let df = DateFormatter()
            df.locale = Locale(identifier: "ja_JP_POSIX")
            df.dateFormat = "yyyyMMdd-HHmmss"
            let stamp = df.string(from: Date())
            let thisBackup = backupsRoot.appendingPathComponent(stamp, isDirectory: true)
            try fm.createDirectory(at: thisBackup, withIntermediateDirectories: true)

            // 対象ファイルだけコピー（state.json / avatar.png が存在すれば）
            let candidates = ["state.json", "avatar.png", "state.preview.json", "avatar.preview.png"]
            for name in candidates {
                let src = sourceDir.appendingPathComponent(name)
                if fm.fileExists(atPath: src.path) {
                    let dst = thisBackup.appendingPathComponent(name)
                    // 既存があれば消してからコピー
                    if fm.fileExists(atPath: dst.path) { try? fm.removeItem(at: dst) }
                    try? fm.copyItem(at: src, to: dst)
                }
            }

            // ローテーション（古い順に削除）
            let entries = (try? fm.contentsOfDirectory(at: backupsRoot, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])) ?? []
            let dirs = entries.filter { url in
                var isDir: ObjCBool = false
                fm.fileExists(atPath: url.path, isDirectory: &isDir)
                return isDir.boolValue
            }
            let sorted = dirs.sorted { (a, b) -> Bool in
                let aDate = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let bDate = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return aDate < bDate
            }
            if sorted.count > maxCopies {
                for url in sorted.prefix(sorted.count - maxCopies) {
                    try? fm.removeItem(at: url)
                }
            }
            print("[AutoBackup] created:", thisBackup.lastPathComponent)
        } catch {
            print("[AutoBackup] error:", error)
        }
    }

    /// アプリのデータフォルダ（Application Support 配下）を選択したフォルダへフルコピーしてバックアップします。
    /// 失敗時はアラートを表示し、成功時は Finder でバックアップ先を開きます。
    func backupToFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "選択"
        panel.message = "バックアップの保存先フォルダを選択"

        guard panel.runModal() == .OK, let dest = panel.url else { return }

        let fm = FileManager.default
        // stateURL が指すファイルの親ディレクトリをバックアップ対象にする
        let sourceDir = stateURL.deletingLastPathComponent()

        let df = DateFormatter()
        df.locale = Locale(identifier: "ja_JP_POSIX")
        df.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = df.string(from: Date())

        // 選択フォルダ直下にタイムスタンプ付きフォルダを作る
        let backupDir = dest.appendingPathComponent("bank-management-backup-\(stamp)", isDirectory: true)

        do {
            try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
            let destSub = backupDir.appendingPathComponent(sourceDir.lastPathComponent, isDirectory: true)
            if fm.fileExists(atPath: destSub.path) {
                try fm.removeItem(at: destSub)
            }
            try fm.copyItem(at: sourceDir, to: destSub)
            // 成功したら Finder で表示
            NSWorkspace.shared.activateFileViewerSelecting([backupDir])
        } catch {
            // 失敗したらアラート
            let alert = NSAlert(error: error)
            alert.messageText = "バックアップに失敗しました"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    func revealStateFile() {
        NSWorkspace.shared.activateFileViewerSelecting([stateURL])
    }
#endif
    }

// MARK: - Utils (shared)
extension AppStore {
    /// ID から口座を取得（nil 安全）
    func account(id: UUID?) -> Account? {
        guard let id else { return nil }
        return accounts.first(where: { $0.id == id })
    }

    /// 取引の新規/更新を 1 本化（存在すれば置換／なければ追加）
    func upsertTransaction(_ newValue: Transaction) {
        if let idx = transactions.firstIndex(where: { $0.id == newValue.id }) {
            transactions[idx] = newValue
        } else {
            transactions.append(newValue)
        }
    }

    /// カードに紐づくデフォルト決済口座ID（あれば返す）
    func defaultSettlementAccountID(for cardID: UUID?) -> UUID? {
        guard let cardID else { return nil }
        return cardPaymentAccount[cardID]
    }

    /// カードのデフォルト決済口座IDを更新／削除
    func setDefaultSettlementAccountID(_ accountID: UUID?, for cardID: UUID?) {
        guard let cardID else { return }
        if let accountID {
            cardPaymentAccount[cardID] = accountID
        } else {
            cardPaymentAccount.removeValue(forKey: cardID)
        }
    }
}
// MARK: - Restore (手動復元)
#if os(macOS)
extension AppStore {
    /// バックアップJSONファイルを選択して復元します
    func restoreFromFolder() {
        let panel = NSOpenPanel()
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [UTType.json]
        } else {
            panel.allowedFileTypes = ["json"]
        }
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "復元するJSONファイルを選択"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let dec = JSONDecoder()
                dec.dateDecodingStrategy = .iso8601
                let state = try dec.decode(AppState.self, from: data)

                // JSONデータをAppStoreのプロパティに反映
                self.categories = state.categories.map { Category(id: $0.id, name: $0.name) }
                self.accounts = state.accounts.map {
                    Account(id: $0.id, name: $0.name, number: $0.number, branchName: $0.branchName, branchCode: $0.branchCode)
                }
                self.creditCards = state.creditCards.map { Category(id: $0.id, name: $0.name) }
                self.cardPaymentAccount = state.cardPaymentAccount ?? [:]
                self.transactions = state.transactions.map { t in
                    Transaction(
                        id: t.id,
                        date: t.date,
                        amount: t.amount,
                        memo: t.memo,
                        kind: t.kind,
                        category: self.categories.first { $0.id == t.categoryID },
                        card: self.creditCards.first { $0.id == t.cardID },
                        person: nil,
                        account: self.accounts.first { $0.id == t.accountID },
                        fromAccount: self.accounts.first { $0.id == t.fromAccountID },
                        toAccount: self.accounts.first { $0.id == t.toAccountID },
                        pairID: t.pairID
                    )
                }
                self.personName = state.personName
                self.appTitle = state.appTitle

                self.save()
                print("✅ 復元完了:", url.lastPathComponent)

                // Finderで復元ファイルを表示
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                let alert = NSAlert()
                alert.messageText = "復元に失敗しました"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
                print("⚠️ 復元失敗:", error)
            }
        }
    }
}
#endif
