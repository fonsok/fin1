import Foundation

// MARK: - Bank Contra Account Posting Service

final class BankContraAccountPostingService: BankContraAccountPostingServiceProtocol, @unchecked Sendable {

    private let queue = DispatchQueue(label: "com.fin.app.bankContraAccount", attributes: .concurrent)
    private var postings: [BankContraAccountPosting] = []
    private let fileManager: FileManager
    private let storageURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Initialization

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let storageURL = BankContraAccountPostingService.makeStorageURL(using: fileManager)
        self.storageURL = storageURL

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        self.postings = BankContraAccountPostingService.loadExistingPostings(
            from: storageURL,
            decoder: decoder
        )
    }

    // MARK: - ServiceLifecycle

    func start() {
        print("🏦 BankContraAccountPostingService started (ledger path: \(self.storageURL.path))")
    }

    func stop() {
        print("🏦 BankContraAccountPostingService stopped")
    }

    func reset() {
        self.queue.async(flags: .barrier) {
            self.postings.removeAll()
            self.persistPostingsLocked()
        }
        print("🏦 BankContraAccountPostingService ledger cleared")
    }

    // MARK: - Recording

    @discardableResult
    func recordAppServiceChargePosting(
        investorId: String,
        batchId: String,
        investmentIds: [String],
        grossAmount: Double,
        netAmount: Double,
        vatAmount: Double
    ) -> BankContraPostingPair {
        let reference = "PSC-\(batchId)"
        let createdAt = Date()

        let netPosting = BankContraAccountPosting(
            account: .appServiceChargeNet,
            side: .credit,
            amount: netAmount,
            investorId: investorId,
            batchId: batchId,
            investmentIds: investmentIds,
            reference: reference,
            createdAt: createdAt,
            metadata: [
                "component": "net",
                "grossAmount": "\(grossAmount)"
            ]
        )

        let vatPosting = BankContraAccountPosting(
            account: .appServiceChargeVAT,
            side: .credit,
            amount: vatAmount,
            investorId: investorId,
            batchId: batchId,
            investmentIds: investmentIds,
            reference: reference,
            createdAt: createdAt,
            metadata: [
                "component": "vat",
                "grossAmount": "\(grossAmount)"
            ]
        )

        self.queue.async(flags: .barrier) {
            self.postings.append(netPosting)
            self.postings.append(vatPosting)
            self.persistPostingsLocked()
        }

        let netText = netAmount.formatted(.currency(code: "EUR"))
        let vatText = vatAmount.formatted(.currency(code: "EUR"))
        print("🏦 Recorded contra postings for batch \(batchId): NET \(netText) | VAT \(vatText)")

        return BankContraPostingPair(netPosting: netPosting, vatPosting: vatPosting)
    }

    @discardableResult
    func recordPlatformServiceChargePosting(
        investorId: String,
        batchId: String,
        investmentIds: [String],
        grossAmount: Double,
        netAmount: Double,
        vatAmount: Double
    ) -> BankContraPostingPair {
        self.recordAppServiceChargePosting(
            investorId: investorId,
            batchId: batchId,
            investmentIds: investmentIds,
            grossAmount: grossAmount,
            netAmount: netAmount,
            vatAmount: vatAmount
        )
    }

    // MARK: - Retrieval

    func getPostings(
        account: BankContraAccount? = nil,
        investorId: String? = nil
    ) -> [BankContraAccountPosting] {
        self.queue.sync {
            self.postings.filter { posting in
                let matchesAccount = account.map { $0 == posting.account } ?? true
                let matchesInvestor = investorId.map { $0 == posting.investorId } ?? true
                return matchesAccount && matchesInvestor
            }
            .sorted { $0.createdAt < $1.createdAt }
        }
    }

    func getAllPostings() -> [BankContraAccountPosting] {
        self.getPostings()
    }

    // MARK: - Persistence Helpers

    private func persistPostingsLocked() {
        do {
            let data = try encoder.encode(self.postings)
            try data.write(to: self.storageURL, options: .atomic)
        } catch {
            print("⚠️ BankContraAccountPostingService: failed to persist ledger - \(error)")
        }
    }

    private static func makeStorageURL(using fileManager: FileManager) -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())

        let ledgerDirectory = baseDirectory.appendingPathComponent("AccountingLedger", isDirectory: true)

        if !fileManager.fileExists(atPath: ledgerDirectory.path) {
            do {
                try fileManager.createDirectory(at: ledgerDirectory, withIntermediateDirectories: true)
            } catch {
                print("⚠️ BankContraAccountPostingService: failed to create ledger directory - \(error)")
            }
        }

        return ledgerDirectory.appendingPathComponent("bank-contra-ledger.json", isDirectory: false)
    }

    private static func loadExistingPostings(
        from url: URL,
        decoder: JSONDecoder
    ) -> [BankContraAccountPosting] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([BankContraAccountPosting].self, from: data)
        } catch {
            print("⚠️ BankContraAccountPostingService: failed to load existing ledger - \(error)")
            return []
        }
    }
}
