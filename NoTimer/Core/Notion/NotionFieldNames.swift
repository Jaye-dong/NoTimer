import Foundation

/// 硬编码的 Notion 数据库字段名。M7 会做字段映射 UI，让用户自定义。
///
/// 注意 — title 字段**不**在这里列出。Notion 每个数据库有且仅有一个
/// type=title 的属性，但名字因数据库而异（"记录" / "Task name" / "标题" / "Name"），
/// 所以我们在 `NotionPage.titleValue` 里按类型查找，不依赖名字。
enum NotionFieldNames {
    enum TimeRecord {
        static let dateRange = "时间段"
        static let category = "分类"
        static let nextActionRelation = "下一步行动"
    }

    enum NextAction {
        static let status = "Status"
        static let projectRelation = "Project"
    }
}
