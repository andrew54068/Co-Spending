import Fluent
import Vapor

public protocol FieldKeys {
    var rawValue: String { get }
}

final class Spending: Model {
    static let schema = "spendings"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: .init(CustomFieldKey.messageId))
    var messageId: Int
    
    @Field(key: .init(CustomFieldKey.title))
    var title: String
    
    @Field(key: .init(CustomFieldKey.cost))
    var cost: String
    
    @Enum(key: .init(CustomFieldKey.identity))
    var identity: Identity
    
    @Timestamp(key: .init(CustomFieldKey.createdAt), on: .create)
    var createdAt: Date?
    
    public enum CustomFieldKey: String, FieldKeys {
        case messageId = "message_id"
        case title
        case cost
        case identity
        case createdAt = "created_at"
    }

    init() {}

    init(
        messageId: Int,
        title: String,
        cost: Decimal,
        identity: Identity
    ) {
        self.id = nil
        self.messageId = messageId
        self.title = title
        self.cost = NSDecimalNumber(decimal: cost).stringValue
        self.identity = identity
        self.createdAt = nil
    }
}
