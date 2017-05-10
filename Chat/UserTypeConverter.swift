//
//  UserTypeConverter.swift
//  SignalRClient
//
//  Created by Pawel Kadluczka on 5/9/17.
//  Copyright © 2017 Pawel Kadluczka. All rights reserved.
//

import Foundation
import SignalRClient

public class UserTypeConverter: JSONTypeConverter {

    public override func convertToWireType(obj: Any?) throws -> Any? {
        if let user = obj as? User? {
            return convertUser(user: user)
        }

        if let users = obj as? [User?] {
            return users.map({u in convertUser(user:u)})
        }

        return try super.convertToWireType(obj: obj)
    }

    private func convertUser(user: User?) -> [String: Any?]? {
        return nil
    }

    public override func convertFromWireType<T>(obj: Any?, targetType: T.Type) throws -> T? {

        if let userArray = obj as? [[String: Any?]?] {

            let result: [User?] = userArray.map({userDictionary in
                if userDictionary == nil {
                    return nil
                }

                let user = userDictionary!

                return User(name: user["Name"] as! String, connectionId: user["ConnectionId"] as! String)
            })

            return result as? T
        }

        return try super.convertFromWireType(obj: obj, targetType: targetType)
    }
}
