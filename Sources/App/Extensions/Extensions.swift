//
//  Extensions.swift
//
//
//  Created by Andrew Wang on 2022/8/22.
//

import Foundation

extension Date {

    func startOfMonth() -> Date {
        let components = Calendar.current.dateComponents(
            [.year, .month],
            from: Calendar.current.startOfDay(for: self))
        return Calendar.current.date(from: components)!
    }

    func endOfMonth() -> Date {
        Calendar.current.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth())!
    }
    
    func startOfPreviousMonth() -> Date {
        Calendar.current.date(byAdding: DateComponents(month: -1), to: startOfMonth())!
    }
    
    func endOfPreviousMonth() -> Date {
        Calendar.current.date(byAdding: DateComponents(second: -1), to: startOfMonth())!
    }

}

extension Decimal {
    
    var stringValue: String {
        (self as NSDecimalNumber).stringValue
    }
    
    var intValue: Int {
        Int((self as NSDecimalNumber).intValue)
    }
    
}
