import Foundation

enum Error: Swift.Error, LocalizedError {
    case inputInvalid
    case identityInvalid
    case costShouldBeExectlyOne
    case spendingTitleNotFound
    case messageNotFound
    case chetIdNotFound
    case databaseNotFound
    case spendingNotExistInDB
    
    var errorDescription: String? {
        switch self {
        case .inputInvalid:
            return "input invalid"
        case .identityInvalid:
            return "identity not valid"
        case .costShouldBeExectlyOne:
            return "number should be exectly one"
        case .spendingTitleNotFound:
            return "spending title not found"
        case .messageNotFound:
            return "message not found"
        case .chetIdNotFound:
            return "chet id not found"
        case .databaseNotFound:
            return "database not found"
        case .spendingNotExistInDB:
            return "spending not exist in db"
        }
    }
}
