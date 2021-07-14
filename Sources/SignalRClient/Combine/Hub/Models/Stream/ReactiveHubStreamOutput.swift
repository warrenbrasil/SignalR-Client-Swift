//
//  ReactiveHubStreamOutput.swift
//  SignalRClient
//
//  Created by Eduardo Bocato on 14/07/21.
//  Copyright © 2021 Pawel Kadluczka. All rights reserved.
//

import Foundation

public enum ReactiveHubStreamOutput<T: Decodable> {
    case itemReceived(T)
    case invocationCompleted
}
extension ReactiveHubStreamOutput: Equatable where T: Equatable {}


enum ReactiveHubStreamOutputBox: Equatable {
    case itemReceived(WrappedDecodable)
    case invocationCompleted
}
