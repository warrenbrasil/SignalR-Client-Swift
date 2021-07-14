//
//  ReactiveHubConnectionEvent.swift
//  SignalRClient
//
//  Created by Eduardo Bocato on 14/07/21.
//  Copyright © 2021 Pawel Kadluczka. All rights reserved.
//

import Foundation

public enum ReactiveHubConnectionEvent: Equatable {
    case opened(HubConnection)
    case willReconnectAfterFailure(Error) // estranho mas como vai reconectar, não posso terminar o stream...
    case streamInvocationFailed(forHandle: StreamHandle, withError: Error)
    case reconnected
    case closed
}

extension ReactiveHubConnectionEvent {
    public static func == (lhs: ReactiveHubConnectionEvent, rhs: ReactiveHubConnectionEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.opened(c1), .opened(c2)):
            return c1.connectionId == c2.connectionId
        case let (.willReconnectAfterFailure(e1), .willReconnectAfterFailure(e2)):
            return e1 as NSError == e2 as NSError
        case let (.streamInvocationFailed(h1, e1), .streamInvocationFailed(h2, e2)):
            return h1.invocationId == h2.invocationId && e1 as NSError == e2 as NSError
        case (.reconnected, .reconnected), (.closed, .closed):
            return true
        default:
            return false
        }
    }
}
