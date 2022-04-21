//
//  DecodableWrapper.swift
//  SignalRClient
//
//  Created by Eduardo Bocato on 14/07/21.
//  Copyright © 2021 Pawel Kadluczka. All rights reserved.
//

import Foundation

struct WrappedDecodable: Equatable {
    let wrappedValue: Any
    let isEqual: (WrappedDecodable) -> Bool

    init<T: Decodable>(_ value: T) {
        self.wrappedValue = value
        isEqual = { otherWrappedDecodable in
            guard let other = otherWrappedDecodable.wrappedValue as? T else { return false }
            return other as? AnyHashable == value as? AnyHashable
        }
    }

    func decoded<T: Decodable>(as: T.Type) -> T? {
        self.wrappedValue as? T
    }

    static func == (lhs: WrappedDecodable, rhs: WrappedDecodable) -> Bool {
        lhs.isEqual(rhs)
    }
}
