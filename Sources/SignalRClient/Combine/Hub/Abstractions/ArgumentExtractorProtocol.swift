//
//  ArgumentExtractorProtocol.swift
//  SignalRClient
//
//  Created by Andre Bocato on 30/07/21.
//  Copyright © 2021 Pawel Kadluczka. All rights reserved.
//

import Foundation

public protocol ArgumentExtractorProtocol {
    func getArgument<T: Decodable>(type: T.Type) throws -> T
    func hasMoreArgs() -> Bool
}
