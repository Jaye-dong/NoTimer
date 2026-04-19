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
    let pushQueue: PushQueue
    let syncEngine: SyncEngine
    let timerController: TimerController
    let notifications: TimerNotifications
    let backgroundSync: BackgroundSyncScheduler

    init(
        database: AppDatabase,
        keychain: KeychainStore,
        notionAuth: NotionAuth,
        notionClient: NotionClient,
        timeRecords: TimeRecordRepository,
        nextActions: NextActionRepository,
        selectOptions: SelectOptionRepository,
        pullStrategy: PullStrategy,
        pushQueue: PushQueue,
        syncEngine: SyncEngine,
        timerController: TimerController,
        notifications: TimerNotifications,
        backgroundSync: BackgroundSyncScheduler
    ) {
        self.database = database
        self.keychain = keychain
        self.notionAuth = notionAuth
        self.notionClient = notionClient
        self.timeRecords = timeRecords
        self.nextActions = nextActions
        self.selectOptions = selectOptions
        self.pullStrategy = pullStrategy
        self.pushQueue = pushQueue
        self.syncEngine = syncEngine
        self.timerController = timerController
        self.notifications = notifications
        self.backgroundSync = backgroundSync
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
            let push = PushQueue(
                client: client,
                auth: auth,
                timeRecords: timeRecords
            )
            let sync = SyncEngine(pull: pull, push: push)
            let liveActivity = LiveActivityManager()
            let notifications = TimerNotifications()
            let timer = TimerController(
                database: database,
                timeRecords: timeRecords,
                liveActivity: liveActivity,
                notifications: notifications,
                onStop: { [sync] in
                    Task { await sync.pushOnly() }
                }
            )
            timer.restore()
            let backgroundSync = BackgroundSyncScheduler(syncEngine: sync)
            return AppDependencies(
                database: database,
                keychain: keychain,
                notionAuth: auth,
                notionClient: client,
                timeRecords: timeRecords,
                nextActions: nextActions,
                selectOptions: selectOptions,
                pullStrategy: pull,
                pushQueue: push,
                syncEngine: sync,
                timerController: timer,
                notifications: notifications,
                backgroundSync: backgroundSync
            )
        } catch {
            fatalError("Failed to bootstrap app: \(error)")
        }
    }
}
