import Fluent

struct CreateSpending: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Spending.schema)
            .id()
            .field(.init(Spending.CustomFieldKey.messageId), .int, .required)
            .field(.init(Spending.CustomFieldKey.title), .string, .required)
            .field(.init(Spending.CustomFieldKey.cost), .string, .required)
            .field(.init(Spending.CustomFieldKey.identity), .string, .required)
            .field(.init(Spending.CustomFieldKey.createdAt), .date, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Spending.schema).delete()
    }
}
