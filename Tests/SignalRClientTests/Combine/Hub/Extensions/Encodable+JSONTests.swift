//
//  Encodable+JSONTests.swift.swift
//  
//
//  Created by Eduardo Bocato on 15/07/21.
//

@testable import SignalRClient
import XCTest

final class EncodableJSONTests: XCTestCase {

}

import Combine

public protocol MyTradeServiceProtocol {
    var connectionPublisher: AnyPublisher<ReactiveHubConnectionEvent, ReactiveHubConnectionFailure> { get }
    func stop()
    func observePrices() -> AnyPublisher<String, Error>
}

public final class MyTradeService: MyTradeServiceProtocol {
    private let hubConnection: ReactiveHubConnection

    public var connectionPublisher: AnyPublisher<ReactiveHubConnectionEvent, ReactiveHubConnectionFailure> {
        hubConnection.connectionPublisher
    }

    init(hubConnection: ReactiveHubConnection) {
        self.hubConnection = hubConnection
        hubConnection.start()
    }

    deinit {
        hubConnection.stop()
    }

    public convenience init() {
        let options = HttpConnectionOptions()
        options.headers = ["key": "value"]
        options.accessTokenProvider = { "hsdauihdsaiuhdsai" }
        self.init(
            hubConnection: CombineHubConnection(
                url: .init(string: "huisdahudisahdsaisda/trade")!,
                options: options
            )
        )
    }

    func stop() {
        hubConnection.stop()
    }

    func startPricesObservation() -> AnyPublisher<Void, Error> {
        hubConnection.invoke(method: "prices", arguments: ["ascending"])
    }

    func observePrices() -> AnyPublisher<String, Error> {
        hubConnection
            .invoke(method: "prices", arguments: ["ascending"])
            .flatMap { [hubConnection] _  in
                hubConnection
                    .on(method: "prices")
                    .tryMap { $0.getArgument(type: String.self) } // parsing
                    .mapError { $0 }
            }
            .eraseToAnyPublisher()
    }
}
