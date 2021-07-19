//
//  ReactiveHubConnection.swift
//  SignalRClient
//
//  Created by Eduardo Bocato on 14/07/21.
//  Copyright © 2021 Pawel Kadluczka. All rights reserved.
//

import Combine
import Foundation

@available(iOS 13.0, macOS 10.15, *)
public protocol ReactiveHubConnection: AnyObject {
    var connectionId: String? { get }
    var connectionPublisher: AnyPublisher<ReactiveHubConnectionEvent, ReactiveHubConnectionFailure> { get }
    func start()
    func send(method: String, arguments:[Encodable]) -> AnyPublisher<Void, Error>
    func on(method: String) -> AnyPublisher<ArgumentExtractor, Never>
    func invoke(method: String, arguments: [Encodable]) -> AnyPublisher<Void, Error>
    func invoke<T: Decodable>(method: String, arguments: [Encodable], resultType: T.Type) -> AnyPublisher<T?, Error>
    func stream<T: Decodable>(method: String, arguments: [Encodable]) -> AnyPublisher<ReactiveHubStreamOutput<T>, Error>
    func stop()
}
