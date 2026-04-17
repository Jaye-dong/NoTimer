import Foundation

/// 轻量 Notion REST 客户端。当前里程碑仅实现鉴权 + 读取数据库元信息 + 查询数据库分页。
/// 写入 / PATCH 将在 M4 同步引擎中加入。
actor NotionClient {
    private let auth: NotionAuth
    private let session: URLSession
    private let baseURL = URL(string: "https://api.notion.com")!
    private let apiVersion = "2022-06-28"

    init(auth: NotionAuth, session: URLSession = .shared) {
        self.auth = auth
        self.session = session
    }

    // MARK: - Public API

    struct DatabaseInfo: Decodable, Sendable {
        let id: String
        let title: [RichText]
        let properties: [String: PropertySchema]

        struct RichText: Decodable, Sendable {
            let plainText: String

            enum CodingKeys: String, CodingKey { case plainText = "plain_text" }
        }

        var displayTitle: String {
            title.map(\.plainText).joined()
        }
    }

    struct PropertySchema: Decodable, Sendable {
        let id: String
        let name: String
        let type: String
        let select: SelectDefinition?
        let status: StatusDefinition?
        let multiSelect: MultiSelectDefinition?

        enum CodingKeys: String, CodingKey {
            case id, name, type, select, status
            case multiSelect = "multi_select"
        }
    }

    struct SelectDefinition: Decodable, Sendable {
        let options: [Option]
        struct Option: Decodable, Sendable {
            let id: String
            let name: String
            let color: String?
        }
    }

    struct StatusDefinition: Decodable, Sendable {
        let options: [SelectDefinition.Option]
    }

    struct MultiSelectDefinition: Decodable, Sendable {
        let options: [SelectDefinition.Option]
    }

    /// 读取数据库元信息（用于验证 token + 解析 schema）。
    func fetchDatabase(id: String) async throws -> DatabaseInfo {
        let req = try request(method: "GET", path: "/v1/databases/\(id)")
        let (data, response) = try await perform(req)
        try validate(response: response, data: data)
        do {
            return try JSONDecoder.notion.decode(DatabaseInfo.self, from: data)
        } catch {
            throw NotionError.decoding(error)
        }
    }

    // MARK: - Internal

    private func request(method: String, path: String, body: Data? = nil) throws -> URLRequest {
        guard let token = try auth.token(), !token.isEmpty else {
            throw NotionError.missingToken
        }
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(apiVersion, forHTTPHeaderField: "Notion-Version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return req
    }

    private func perform(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: req)
        } catch {
            throw NotionError.transport(error)
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NotionError.badResponse(status: http.statusCode, body: body)
        }
    }
}

extension JSONDecoder {
    static let notion: JSONDecoder = {
        let d = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = formatter.date(from: str) ?? fallback.date(from: str) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unrecognized date format: \(str)"
            )
        }
        return d
    }()
}
