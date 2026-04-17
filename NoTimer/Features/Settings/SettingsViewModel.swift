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

    var tokenInput: String = ""
    var timeRecordsInput: String = ""
    var nextActionsInput: String = ""
    var state: ValidationState = .idle

    private let auth: NotionAuth
    private let client: NotionClient

    init(auth: NotionAuth, client: NotionClient) {
        self.auth = auth
        self.client = client
        self.timeRecordsInput = auth.timeRecordsDatabaseId
        self.nextActionsInput = auth.nextActionsDatabaseId
        if auth.hasToken {
            self.tokenInput = "••••••••••••"
        }
    }

    var canValidate: Bool {
        !tokenInput.isEmpty && !timeRecordsInput.isEmpty && !nextActionsInput.isEmpty
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
        } catch {
            state = .failure(error.localizedDescription)
        }
    }

    func clearToken() {
        do {
            try auth.clearToken()
            tokenInput = ""
            state = .idle
        } catch {
            state = .failure(error.localizedDescription)
        }
    }
}
