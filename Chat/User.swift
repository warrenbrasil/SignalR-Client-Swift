//
//  User.swift
//  SignalRClient
//
//  Created by Pawel Kadluczka on 5/9/17.
//  Copyright © 2017 Pawel Kadluczka. All rights reserved.
//

import Foundation

class User {
    let name: String
    let connectionId: String

    init(name: String, connectionId: String) {
        self.name = name
        self.connectionId = connectionId
    }
}
