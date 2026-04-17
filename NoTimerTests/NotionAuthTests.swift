import XCTest
@testable import NoTimer

final class NotionAuthTests: XCTestCase {
    func testExtractsIdFromURL() {
        let url = "https://www.notion.so/workspace/My-DB-1a2b3c4d5e6f7890abcdef1234567890?v=xxx"
        XCTAssertEqual(
            NotionAuth.extractDatabaseId(from: url),
            "1a2b3c4d5e6f7890abcdef1234567890"
        )
    }

    func testExtractsIdFromHyphenatedForm() {
        let input = "1a2b3c4d-5e6f-7890-abcd-ef1234567890"
        XCTAssertEqual(
            NotionAuth.extractDatabaseId(from: input),
            "1a2b3c4d5e6f7890abcdef1234567890"
        )
    }

    func testReturnsNilForInvalid() {
        XCTAssertNil(NotionAuth.extractDatabaseId(from: "not an id"))
        XCTAssertNil(NotionAuth.extractDatabaseId(from: "abc123"))
    }
}
