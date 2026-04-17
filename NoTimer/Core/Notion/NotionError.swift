import Foundation

enum NotionError: Error, LocalizedError {
    case emptyToken
    case missingToken
    case invalidDatabaseId
    case badResponse(status: Int, body: String)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .emptyToken:
            return "Token 不能为空"
        case .missingToken:
            return "尚未配置 Notion Integration Token"
        case .invalidDatabaseId:
            return "数据库 ID / URL 格式不正确，需要 32 位十六进制"
        case .badResponse(let status, let body):
            return "Notion 接口返回 \(status): \(body)"
        case .decoding(let error):
            return "响应解析失败: \(error.localizedDescription)"
        case .transport(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}
