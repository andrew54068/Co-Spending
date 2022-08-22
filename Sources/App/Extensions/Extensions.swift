//
//  Extensions.swift
//
//
//  Created by Andrew Wang on 2022/8/22.
//

import Foundation

extension Date {

    func startOfMonth() -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Calendar.current.startOfDay(for: self)))!
    }

    func endOfMonth() -> Date {
        Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth())!
    }

}

extension Decimal {
    
    var stringValue: String {
        (self as NSDecimalNumber).stringValue
    }
    
    var intValue: Int {
        Int((self as NSDecimalNumber).floatValue)
    }
    
}
