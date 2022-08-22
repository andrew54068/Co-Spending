import Foundation
import FluentKit

extension FieldKey {
    
    public init(_ value: FieldKeys) {
        self.init(stringLiteral: value.rawValue)
    }

}
