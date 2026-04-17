import XCTest
@testable import NoTimer

final class NotionMapperTests: XCTestCase {
    func testTimeRecordMapperExtractsAllFields() throws {
        let json = """
        {
          "id": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
          "last_edited_time": "2026-04-17T08:30:00.000Z",
          "archived": false,
          "properties": {
            "标题": {
              "id": "title",
              "type": "title",
              "title": [
                { "plain_text": "写 " },
                { "plain_text": "代码" }
              ]
            },
            "时间段": {
              "id": "date",
              "type": "date",
              "date": {
                "start": "2026-04-17T09:00:00.000+08:00",
                "end": "2026-04-17T10:30:00.000+08:00",
                "time_zone": null
              }
            },
            "分类": {
              "id": "sel",
              "type": "select",
              "select": { "id": "opt1", "name": "工作", "color": "blue" }
            },
            "下一步行动": {
              "id": "rel",
              "type": "relation",
              "relation": [{ "id": "action-page-id" }]
            }
          }
        }
        """

        let page = try JSONDecoder.notion.decode(NotionPage.self, from: Data(json.utf8))
        let record = TimeRecordMapper.toLocal(page: page, existing: nil)

        XCTAssertEqual(record.notionPageId, "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        XCTAssertEqual(record.title, "写 代码")
        XCTAssertEqual(record.category, "工作")
        XCTAssertEqual(record.nextActionPageId, "action-page-id")
        XCTAssertNotNil(record.startAt)
        XCTAssertNotNil(record.endAt)
        XCTAssertEqual(record.syncState, .synced)
    }

    func testTimeRecordMapperHandlesActiveRecordWithoutEnd() throws {
        let json = """
        {
          "id": "page-1",
          "last_edited_time": "2026-04-17T08:30:00.000Z",
          "archived": false,
          "properties": {
            "标题": { "id": "t", "type": "title", "title": [{ "plain_text": "专注" }] },
            "时间段": {
              "id": "d", "type": "date",
              "date": { "start": "2026-04-17T09:00:00.000+08:00", "end": null, "time_zone": null }
            },
            "分类": { "id": "s", "type": "select", "select": null },
            "下一步行动": { "id": "r", "type": "relation", "relation": [] }
          }
        }
        """

        let page = try JSONDecoder.notion.decode(NotionPage.self, from: Data(json.utf8))
        let record = TimeRecordMapper.toLocal(page: page, existing: nil)

        XCTAssertNil(record.endAt)
        XCTAssertNil(record.category)
        XCTAssertNil(record.nextActionPageId)
        XCTAssertTrue(record.isActive)
    }

    func testNextActionMapperExtractsStatusAndProject() throws {
        let json = """
        {
          "id": "next-1",
          "last_edited_time": "2026-04-17T08:30:00.000Z",
          "archived": false,
          "properties": {
            "标题": { "id": "t", "type": "title", "title": [{ "plain_text": "写 M2 同步" }] },
            "Status": {
              "id": "st", "type": "status",
              "status": { "id": "s1", "name": "In progress", "color": "yellow" }
            },
            "Project": {
              "id": "p", "type": "relation",
              "relation": [{ "id": "project-page-id" }]
            }
          }
        }
        """

        let page = try JSONDecoder.notion.decode(NotionPage.self, from: Data(json.utf8))
        let action = NextActionMapper.toLocal(page: page, existing: nil)

        XCTAssertEqual(action.title, "写 M2 同步")
        XCTAssertEqual(action.status, "In progress")
        XCTAssertEqual(action.projectPageId, "project-page-id")
        XCTAssertEqual(action.syncState, .synced)
    }

    func testMapperPreservesExistingLocalId() throws {
        let json = """
        {
          "id": "next-1",
          "last_edited_time": "2026-04-17T08:30:00.000Z",
          "archived": false,
          "properties": {
            "标题": { "id": "t", "type": "title", "title": [{ "plain_text": "foo" }] },
            "Status": { "id": "st", "type": "status", "status": null },
            "Project": { "id": "p", "type": "relation", "relation": [] }
          }
        }
        """
        let page = try JSONDecoder.notion.decode(NotionPage.self, from: Data(json.utf8))
        let existing = NextAction(
            id: "existing-local-id",
            notionPageId: "next-1",
            title: "old",
            status: nil,
            projectPageId: nil,
            projectName: "Cached Project",
            notionLastEdited: nil,
            localUpdatedAt: Date(),
            syncState: .synced
        )
        let action = NextActionMapper.toLocal(page: page, existing: existing)
        XCTAssertEqual(action.id, "existing-local-id")
        XCTAssertEqual(action.projectName, "Cached Project", "缓存的项目名应保留直到显式刷新")
    }

    func testTitleLookupByTypeNotName() throws {
        // 真实数据库里 title 字段名可能是 "记录" / "Task name" 等而不是 "标题"。
        // 我们按 type=title 查找，所以名字无所谓。
        let json = """
        {
          "id": "p-1",
          "last_edited_time": "2026-04-17T08:30:00.000Z",
          "archived": false,
          "properties": {
            "记录": { "id": "t", "type": "title", "title": [{ "plain_text": "写日报" }] },
            "时间段": {
              "id": "d", "type": "date",
              "date": { "start": "2026-04-17T09:00:00.000+08:00", "end": null, "time_zone": null }
            }
          }
        }
        """
        let page = try JSONDecoder.notion.decode(NotionPage.self, from: Data(json.utf8))
        XCTAssertEqual(page.titleValue, "写日报")

        let record = TimeRecordMapper.toLocal(page: page, existing: nil)
        XCTAssertEqual(record.title, "写日报")

        // 下一步行动同理 — title 字段名可以是 "Task name"
        let actionJson = """
        {
          "id": "a-1",
          "last_edited_time": "2026-04-17T08:30:00.000Z",
          "archived": false,
          "properties": {
            "Task name": { "id": "t", "type": "title", "title": [{ "plain_text": "修 bug" }] },
            "Status": { "id": "s", "type": "status", "status": { "id": "s1", "name": "Done", "color": "green" } },
            "Project": { "id": "p", "type": "relation", "relation": [] }
          }
        }
        """
        let apage = try JSONDecoder.notion.decode(NotionPage.self, from: Data(actionJson.utf8))
        let action = NextActionMapper.toLocal(page: apage, existing: nil)
        XCTAssertEqual(action.title, "修 bug")
        XCTAssertEqual(action.status, "Done")
    }

    func testQueryResponsePagination() throws {
        let json = """
        {
          "object": "list",
          "results": [],
          "next_cursor": "cursor-xyz",
          "has_more": true
        }
        """
        let response = try JSONDecoder.notion.decode(NotionQueryResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.nextCursor, "cursor-xyz")
        XCTAssertTrue(response.hasMore)
    }
}
