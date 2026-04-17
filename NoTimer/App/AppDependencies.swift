import Foundation
import Observation

@Observable
final class AppDependencies {
    let database: AppDatabase
    let keychain: KeychainStore
    let notionAuth: NotionAuth
    let notionClient: NotionClient
    let timeRecords: TimeRecordRepository
    let nextActions: NextActionRepository

    init(
        database: AppDatabase,
        keychain: KeychainStore,
        notionAuth: NotionAuth,
        notionClient: NotionClient,
        timeRecords: TimeRecordRepository,
        nextActions: NextActionRepository
    ) {
        self.database = database
        self.keychain = keychain
        self.notionAuth = notionAuth
        self.notionClient = notionClient
        self.timeRecords = timeRecords
        self.nextActions = nextActions
    }

    static func bootstrap() -> AppDependencies {
        do {
            let database = try AppDatabase.onDisk()
            let keychain = KeychainStore(service: "com.jayedong.notimer")
            let auth = NotionAuth(keychain: keychain)
            let client = NotionClient(auth: auth)
            return AppDependencies(
                database: database,
                keychain: keychain,
                notionAuth: auth,
                notionClient: client,
                timeRecords: TimeRecordRepository(database: database),
                nextActions: NextActionRepository(database: database)
            )
        } catch {
            fatalError("Failed to bootstrap app: \(error)")
        }
    }
}
