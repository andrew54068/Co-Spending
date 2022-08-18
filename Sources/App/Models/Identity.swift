import Foundation

enum Identity: String, Codable {
    case andrew
    case vivian
    
    init?(id: Int64) {
        switch id {
        case 473_108_217:
            self = .andrew
        case 1_183_370_127:
            self = .vivian
        default:
            return nil
        }
    }
}
