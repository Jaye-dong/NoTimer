import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    enum ValidationState: Equatable {
        case idle
        case checking
        case success(timeRecordsTitle: String, nextActionsTitle: String)
        case failure(String)
    }

    enum SyncState: Equatable {
        case idle
        case running
        case success(timeRecords: Int, nextActions: Int, finishedAt: Date)
        case failure(String)
    }

    var tokenInput: String = ""
    var timeRecordsInput: String = ""
    var nextActionsInput: String = ""
    var state: ValidationState = .idle
    var syncState: SyncState = .idle

    private let auth: NotionAuth
    private let client: NotionClient
    private let pull: PullStrategy

    init(auth: NotionAuth, client: NotionClient, pull: PullStrategy) {
        self.auth = auth
        self.client = client
        self.pull = pull
        self.timeRecordsInput = auth.timeRecordsDatabaseId
        self.nextActionsInput = auth.nextActionsDatabaseId
        if auth.hasToken {
            self.tokenInput = "••••••••••••"
        }
    }

    var canValidate: Bool {
        !tokenInput.isEmpty && !timeRecordsInput.isEmpty && !nextActionsInput.isEmpty
    }

    var canSync: Bool {
        auth.hasToken
        && !auth.timeRecordsDatabaseId.isEmpty
        && !auth.nextActionsDatabaseId.isEmpty
        && syncState != .running
    }

    func validate() async {
        state = .checking

        do {
            if !tokenInput.hasPrefix("•") {
                try auth.saveToken(tokenInput)
            }

            guard let timeId = NotionAuth.extractDatabaseId(from: timeRecordsInput),
                  let actionsId = NotionAuth.extractDatabaseId(from: nextActionsInput) else {
                state = .failure(NotionError.invalidDatabaseId.localizedDescription)
                return
            }

            let timeInfo = try await client.fetchDatabase(id: timeId)
            let actionsInfo = try await client.fetchDatabase(id: actionsId)

            auth.timeRecordsDatabaseId = timeId
            auth.nextActionsDatabaseId = actionsId

            state = .success(
                timeRecordsTitle: timeInfo.displayTitle,
                nextActionsTitle: actionsInfo.displayTitle
            )
            tokenInput = "••••••••••••"

            await syncNow()
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    func syncNow() async {
        syncState = .running
        do {
            let summary = try await pull.runFullPull()
            syncState = .success(
                timeRecords: summary.timeRecordsPulled,
                nextActions: summary.nextActionsPulled,
                finishedAt: Date()
            )
        } catch {
            syncState = .failure(error.localizedDescription)
        }
    }

    func clearToken() {
        do {
            try auth.clearToken()
            tokenInput = ""
            state = .idle
            syncState = .idle
        } catch {
            state = .failure(error.localizedDescription)
        }
    }
}
