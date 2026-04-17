import Foundation

enum SyncState: Int, Codable, Sendable {
    case synced = 0
    case pendingPush = 1
    case conflict = 2
    case tombstone = 3
}
