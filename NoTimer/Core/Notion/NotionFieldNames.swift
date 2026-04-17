import Foundation

/// 硬编码的 Notion 数据库字段名。M7 会做字段映射 UI，让用户自定义。
enum NotionFieldNames {
    enum TimeRecord {
        static let title = "标题"
        static let dateRange = "时间段"
        static let category = "分类"
        static let nextActionRelation = "下一步行动"
    }

    enum NextAction {
        static let title = "标题"
        static let status = "Status"
        static let projectRelation = "Project"
    }
}
