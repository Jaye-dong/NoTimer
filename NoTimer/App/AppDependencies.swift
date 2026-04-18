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
    let selectOptions: SelectOptionRepository
    let pullStrategy: PullStrategy
    let timerController: TimerController

    init(
        database: AppDatabase,
        keychain: KeychainStore,
        notionAuth: NotionAuth,
        notionClient: NotionClient,
        timeRecords: TimeRecordRepository,
        nextActions: NextActionRepository,
        selectOptions: SelectOptionRepository,
        pullStrategy: PullStrategy,
        timerController: TimerController
    ) {
        self.database = database
        self.keychain = keychain
        self.notionAuth = notionAuth
        self.notionClient = notionClient
        self.timeRecords = timeRecords
        self.nextActions = nextActions
        self.selectOptions = selectOptions
        self.pullStrategy = pullStrategy
        self.timerController = timerController
    }

    @MainActor
    static func bootstrap() -> AppDependencies {
        do {
            let database = try AppDatabase.onDisk()
            let keychain = KeychainStore(service: "com.jayedong.notimer")
            let auth = NotionAuth(keychain: keychain)
            let client = NotionClient(auth: auth)
            let timeRecords = TimeRecordRepository(database: database)
            let nextActions = NextActionRepository(database: database)
            let selectOptions = SelectOptionRepository(database: database)
            let pull = PullStrategy(
                client: client,
                auth: auth,
                timeRecords: timeRecords,
                nextActions: nextActions,
                selectOptions: selectOptions
            )
            let liveActivity = LiveActivityManager()
            let timer = TimerController(
                database: database,
                timeRecords: timeRecords,
                liveActivity: liveActivity
            )
            timer.restore()
            return AppDependencies(
                database: database,
                keychain: keychain,
                notionAuth: auth,
                notionClient: client,
                timeRecords: timeRecords,
                nextActions: nextActions,
                selectOptions: selectOptions,
                pullStrategy: pull,
                timerController: timer
            )
        } catch {
            fatalError("Failed to bootstrap app: \(error)")
        }
    }
}
