import Combine
@testable import SignalRClient
import XCTest

final class CombineHTTPConnectionTests: XCTestCase {
    // MARK: - Properties

    private let httpConnectionSpy: HTTPConnectionSpy = .init()
    private var subscriptions: Set<AnyCancellable> = .init()

    // MARK: - Tests

    func test_init_shouldSetTheDependenciesAsExpected() throws {
        // Given
        let dummyURL = try getDummyURL()

        // When
        let sut = CombineHTTPConnection(url: dummyURL)

        // Then
        let sutMirror = Mirror(reflecting: sut)
        let httpConnection = try XCTUnwrap(sutMirror.firstChild(of: HttpConnection.self))
        let httpConnectionMirror = Mirror(reflecting: httpConnection)

        let url = httpConnectionMirror.firstChild(of: URL.self, in: "url")
        XCTAssertEqual(url, dummyURL)

        XCTAssertNotNil(httpConnectionMirror.firstChild(of: HttpConnectionOptions.self, in: "options"))

        let transportFactory = httpConnectionMirror.firstChild(of: TransportFactory.self, in: "transportFactory")
        XCTAssertTrue(transportFactory is DefaultTransportFactory)

        let logger = httpConnectionMirror.firstChild(of: Logger.self, in: "logger")
        XCTAssertTrue(logger is NullLogger)

        XCTAssertTrue(httpConnection.delegate === sut)
    }

    func test_start_shouldStartHttpConnection() throws {
        // Given
        let sut = CombineHTTPConnection(httpConnection: httpConnectionSpy)

        // When
        sut.start()

        // Then
        XCTAssertTrue(httpConnectionSpy.startCalled)
    }

    func test_send_shouldSendDataToHttpConnection() {
        // Given
        let sut = CombineHTTPConnection(httpConnection: httpConnectionSpy)
        let mockData: Data = .init()

        // When
        sut.send(data: mockData)

        // Then
        XCTAssertTrue(httpConnectionSpy.sendCalled)
        XCTAssertEqual(httpConnectionSpy.sendDataPassed, mockData)
    }

    func test_send_whenAnErrorOccursOnHttpConnection_shouldReceiveFailedToSendDataEvent() {
        // Given
        let sut = CombineHTTPConnection(httpConnection: httpConnectionSpy)

        let mockData: Data = .init()
        sut.send(data: mockData)

        let errorMock: NSError = .init(domain: "Tests", code: -1, userInfo: nil)

        var eventReceived: ReactiveConnectionEvent?
        let expectation = createExpectationForPublisher(sut.publisher) { result in
            eventReceived = try? result.get()
        }

        // When
        httpConnectionSpy.sendDidCompletePassed?(errorMock)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(eventReceived, .failedToSendData(mockData, errorMock))
    }

    func test_send_whenSendSucceedsInConnection_shouldReceiveSuccesfullySentDataEvent() {
        // Given
        let sut = CombineHTTPConnection(httpConnection: httpConnectionSpy)

        let mockData: Data = .init()
        sut.send(data: mockData)

        var eventReceived: ReactiveConnectionEvent?
        let expectation = createExpectationForPublisher(sut.publisher) { result in
            eventReceived = try? result.get()
        }

        // When
        httpConnectionSpy.sendDidCompletePassed?(nil)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(eventReceived, .succesfullySentData(mockData))
    }

    func test_stop_shouldStopHttpConnection() {
        // Given
        let sut = CombineHTTPConnection(httpConnection: httpConnectionSpy)
        let errorMock: NSError = .init(domain: "Tests", code: -1, userInfo: nil)

        // When
        sut.stop(withError: errorMock)

        // Then
        XCTAssertTrue(httpConnectionSpy.stopCalled)
        XCTAssertEqual(errorMock, httpConnectionSpy.stopErrorPassed as NSError?)
    }

    func test_connectionDidOpen_shouldSendEventsToPublisher() throws {
        // Given
        let sut = CombineHTTPConnection(httpConnection: httpConnectionSpy)

        var eventReceived: ReactiveConnectionEvent?
        let expectation = createExpectationForPublisher(sut.publisher) { result in
            eventReceived = try? result.get()
        }

        // When
        httpConnectionSpy.delegate?.connectionDidOpen(connection: httpConnectionSpy)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(eventReceived, .opened(httpConnectionSpy))
    }

    func test_connectionDidFailToOpen_shouldSendEventsToPublisher() throws {
        // Given
        let sut = CombineHTTPConnection(httpConnection: httpConnectionSpy)
        let errorMock: NSError = .init(domain: "Tests", code: -1, userInfo: nil)

        var eventReceived: Result<ReactiveConnectionEvent, ReactiveConnectionFailure>?
        let expectation = createExpectationForPublisher(sut.publisher) { result in
            eventReceived = result
        }

        // When
        httpConnectionSpy.delegate?.connectionDidFailToOpen(error: errorMock)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(eventReceived, .failure(.failedToOpen(errorMock)))
    }

    func test_connectionDidReceiveData_shouldSendEventsToPublisher() throws {
        // Given
        let sut = CombineHTTPConnection(httpConnection: httpConnectionSpy)
        let mockData: Data = .init()
        let connection = httpConnectionSpy

        var eventReceived: Result<ReactiveConnectionEvent, ReactiveConnectionFailure>?
        let expectation = createExpectationForPublisher(sut.publisher) { result in
            eventReceived = result
        }

        // When
        httpConnectionSpy.delegate?.connectionDidReceiveData(connection: connection, data: mockData)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(eventReceived, .success(.gotData(fromConnection: connection, data: mockData)))
    }

    func test_connectionDidClose_withError_shouldSendEventsToPublisher() throws {
        // Given
        let sut = CombineHTTPConnection(httpConnection: httpConnectionSpy)
        let errorMock: NSError = .init(domain: "Tests", code: -1, userInfo: nil)

        var eventReceived: Result<ReactiveConnectionEvent, ReactiveConnectionFailure>?
        let expectation = createExpectationForPublisher(sut.publisher) { result in
            eventReceived = result
        }

        // When
        httpConnectionSpy.delegate?.connectionDidClose(error: errorMock)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(eventReceived, .failure(.closedWithError(errorMock)))
    }

    func test_connectionDidClose_withoutError_shouldSendEventsToPublisher() throws {
        // Given
        let sut = CombineHTTPConnection(httpConnection: httpConnectionSpy)

        var eventReceived: Result<ReactiveConnectionEvent, ReactiveConnectionFailure>?
        let expectation = createExpectationForPublisher(sut.publisher) { result in
            eventReceived = result
        }

        // When
        httpConnectionSpy.delegate?.connectionDidClose(error: nil)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(eventReceived, .success(.closed))
    }

    func test_connectionWillReconnect_shouldSendEventsToPublisher() throws {
        // Given
        let sut = CombineHTTPConnection(httpConnection: httpConnectionSpy)
        let errorMock: NSError = .init(domain: "Tests", code: -1, userInfo: nil)

        var eventReceived: Result<ReactiveConnectionEvent, ReactiveConnectionFailure>?
        let expectation = createExpectationForPublisher(sut.publisher) { result in
            eventReceived = result
        }

        // When
        httpConnectionSpy.delegate?.connectionWillReconnect(error: errorMock)

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(eventReceived, .success(.willReconnectAfterFailure(errorMock)))
    }

    func test_connectionDidReconnect_shouldSendEventsToPublisher() throws {
        // Given
        let sut = CombineHTTPConnection(httpConnection: httpConnectionSpy)

        var eventReceived: Result<ReactiveConnectionEvent, ReactiveConnectionFailure>?
        let expectation = createExpectationForPublisher(sut.publisher) { result in
            eventReceived = result
        }

        // When
        httpConnectionSpy.delegate?.connectionDidReconnect()

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(eventReceived, .success(.reconnected))
    }

    // MARK: - Helper Functions

    private func getDummyURL() throws -> URL {
        return try XCTUnwrap(.init(string: "www.testdummy.com"))
    }

    private func createExpectationForPublisher(
        _ publisher: AnyPublisher<ReactiveConnectionEvent, ReactiveConnectionFailure>,
        onFirstEventReceived: @escaping (Result<ReactiveConnectionEvent, ReactiveConnectionFailure>) -> Void
    ) -> XCTestExpectation {
        let connectionPublisherExpectation = expectation(description: "Connection Publisher received and event.")
        publisher.sink(
            receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    onFirstEventReceived(.failure(error))
                }
                connectionPublisherExpectation.fulfill()
            },
            receiveValue: { value in
                onFirstEventReceived(.success(value))
                connectionPublisherExpectation.fulfill()
            }
        )
        .store(in: &subscriptions)
        return connectionPublisherExpectation
    }
}

// MARK: - Test Doubles

final class HTTPConnectionSpy: Connection {
    var delegate: ConnectionDelegate?
    var connectionId: String?

    private(set) var startCalled = false
    func start() -> Void {
        startCalled = true
    }

    private(set) var sendCalled = false
    private(set) var sendDataPassed: Data?
    private(set) var sendDidCompletePassed: ((Error?) -> Void)?
    func send(data: Data, sendDidComplete: @escaping (_ error: Error?) -> Void) -> Void {
        sendCalled = true
        sendDataPassed = data
        sendDidCompletePassed = sendDidComplete
    }

    private(set) var stopCalled = false
    private(set) var stopErrorPassed: Error?
    func stop(stopError: Error?) -> Void {
        stopCalled = true
        stopErrorPassed = stopError
    }
}
