import Foundation

enum NextActionMapper {
    static func toLocal(page: NotionPage, existing: NextAction?) -> NextAction {
        let title = page.title(named: NotionFieldNames.NextAction.title) ?? ""
        let status = page.select(named: NotionFieldNames.NextAction.status)?.name
        let projectId = page.relationIds(named: NotionFieldNames.NextAction.projectRelation).first

        return NextAction(
            id: existing?.id ?? UUID().uuidString,
            notionPageId: page.id,
            title: title,
            status: status,
            projectPageId: projectId,
            projectName: existing?.projectName,
            notionLastEdited: page.lastEditedTime,
            localUpdatedAt: Date(),
            syncState: .synced
        )
    }
}
