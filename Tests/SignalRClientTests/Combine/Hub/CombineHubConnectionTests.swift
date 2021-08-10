//
//  CombineHubConnectionTests.swift
//  
//
//  Created by Eduardo Bocato on 15/07/21.
//

#if canImport(Combine)
import Combine
@testable import SignalRClient
import XCTest

final class CombineHubConnectionTests: XCTestCase {
    // MARK: - Properties

    private let hubConnectionSpy: HubConnectionSpy = .init()
    private var subscriptions: Set<AnyCancellable> = .init()

    // MARK: - Tests

    func test_init_shouldSetupHubConnectionProperly() throws {
        // Given
        let url = try getDummyURL()

        // When
        let sut: CombineHubConnection = .init(url: url)

        // Then
        let reconnectableConnection = try XCTUnwrap(
            Mirror(reflecting: sut.hubConnection)
                .firstChild(of: Connection.self) as? ReconnectableConnection
        )

        let reconnectPolicy = Mirror(reflecting: reconnectableConnection).firstChild(of: ReconnectPolicy.self)
        XCTAssertTrue(reconnectPolicy is DefaultReconnectPolicy)

        let underlyingConnection = try XCTUnwrap(
            Mirror(reflecting: reconnectableConnection)
                .firstChild(of: Connection.self, in: "underlyingConnection")
        )
        let transportFactory = Mirror(reflecting: underlyingConnection).firstChild(of: TransportFactory.self)
        XCTAssertTrue(transportFactory is DefaultTransportFactory)

        let hubProtocol = Mirror(reflecting: sut.hubConnection).firstChild(of: HubProtocol.self)
        XCTAssertTrue(hubProtocol is JSONHubProtocol)

        XCTAssertTrue(sut.hubConnection.delegate === sut)
    }

    func test_start_shouldStartHubConnection() throws {
        // Given
        let sut = CombineHubConnection(hubConnection: hubConnectionSpy)

        // When
        sut.start()

        // Then
        XCTAssertTrue(hubConnectionSpy.startCalled)
    }

    func test_send_shouldSendDataToHttpConnection() {
        // Given
        let sut = CombineHubConnection(hubConnection: hubConnectionSpy)

        // When
        _ = sut.send(method: "method", arguments: ["args"])

        // Then
        XCTAssertTrue(hubConnectionSpy.sendCalled)
        XCTAssertEqual(hubConnectionSpy.sendMethodPassed, "method")
        XCTAssertEqual(hubConnectionSpy.sendArgumentsPassed?.asJSON(), ["args"].asJSON())
    }

    // MARK: - Helper Functions

    private func getDummyURL() throws -> URL {
        return try XCTUnwrap(.init(string: "www.testdummy.com"))
    }

}

// MARK: - Test Doubles

final class HubConnectionSpy: HubConnectionProtocol {
    var delegate: HubConnectionDelegate?
    var connectionId: String?

    private(set) var startCalled = false
    func start() {
        startCalled = true
    }

    private(set) var onCalled = false
    private(set) var onMethodPassed: String?
    private(set) var onCallbackPassed: ((ArgumentExtractor) throws -> Void)?
    func on(method: String, callback: @escaping (ArgumentExtractor) throws -> Void) {
        onCalled = true
        onMethodPassed = method
        onCallbackPassed = callback
    }

    private(set) var sendCalled = false
    private(set) var sendMethodPassed: String?
    private(set) var sendArgumentsPassed: [Encodable]?
    private(set) var sendDidCompletePassed: ((Error?) -> Void)?
    func send(method: String, arguments: [Encodable], sendDidComplete: @escaping (Error?) -> Void) {
        sendCalled = true
        sendMethodPassed = method
        sendArgumentsPassed = arguments
        sendDidCompletePassed = sendDidComplete
    }

    private(set) var invokeCalled = false
    private(set) var invokeMethodPassed: String?
    private(set) var invokeArgumentsPassed: [Encodable]?
    private(set) var invokeInvocationDidCompletePassed: ((Error?) -> Void)?
    func invoke(method: String, arguments: [Encodable], invocationDidComplete: @escaping (Error?) -> Void) {
        invokeCalled = true
        invokeMethodPassed = method
        invokeArgumentsPassed = arguments
        invokeInvocationDidCompletePassed = invocationDidComplete
    }

    private(set) var invokeTCalled = false
    private(set) var invokeTMethodPassed: String?
    private(set) var invokeTArgumentsPassed: [Encodable]?
    private(set) var invokeTResultTypePassed: Any?
    private(set) var invokeTInvocationDidCompletePassed: Any?
    func invoke<T>(method: String, arguments: [Encodable], resultType: T.Type, invocationDidComplete: @escaping (T?, Error?) -> Void) where T : Decodable {
        invokeTCalled = true
        invokeTMethodPassed = method
        invokeTArgumentsPassed = arguments
        invokeTResultTypePassed = resultType
        invokeTInvocationDidCompletePassed = invocationDidComplete
    }

    private(set) var streamTCalled = false
    private(set) var streamTMethodPassed: String?
    private(set) var streamTArgumentsPassed: [Encodable]?
    private(set) var streamTStreamItemReceivedPassed: Any?
    private(set) var streamTInvocationDidCompletePassed: ((Error?) -> Void)?
    func stream<T>(method: String, arguments: [Encodable], streamItemReceived: @escaping (T) -> Void, invocationDidComplete: @escaping (Error?) -> Void) -> StreamHandle where T : Decodable {
        streamTCalled = true
        streamTMethodPassed = method
        streamTArgumentsPassed = arguments
        streamTStreamItemReceivedPassed = streamItemReceived
        streamTInvocationDidCompletePassed = invocationDidComplete
        return .init(invocationId: "dummy")
    }

    private(set) var cancelStreamInvocationCalled = false
    private(set) var streamHandlePassed: StreamHandle?
    private(set) var cancelDidFailPassed: ((Error) -> Void)?
    func cancelStreamInvocation(streamHandle: StreamHandle, cancelDidFail: @escaping (Error) -> Void) {
        cancelStreamInvocationCalled = true
        streamHandlePassed = streamHandle
        cancelDidFailPassed = cancelDidFail
    }

    private(set) var stopCalled = false
    func stop() {
        stopCalled = true
    }
}

extension Mirror {
    func firstChild<T>(of type: T.Type, in label: String? = nil) -> T? {
        children.lazy.compactMap {
            guard let value = $0.value as? T
            else { return nil }
            guard let label = label
            else { return value }
            return $0.label == label ? value : nil
        }.first
    }
}
#endif
