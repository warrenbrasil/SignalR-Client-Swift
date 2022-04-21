//
//  CombineHubConnection.swift
//  SignalRClient
//
//  Created by Eduardo Bocato on 14/07/21.
//  Copyright © 2021 Pawel Kadluczka. All rights reserved.
//

#if canImport(Combine)
import Combine
import Foundation

@available(iOS 13.0, macOS 10.15, *)
public final class CombineHubConnection: ReactiveHubConnection {
    // MARK: - Dependencies

    private(set) var hubConnection: HubConnectionProtocol

    // MARK: - Public Properties

    public var connectionId: String? { hubConnection.connectionId }
    public var connectionPublisher: AnyPublisher<ReactiveHubConnectionEvent, ReactiveHubConnectionFailure> {
        connectionSubject.removeDuplicates().eraseToAnyPublisher()
    }

    // MARK: - Internal Properties

    let connectionSubject: PassthroughSubject<ReactiveHubConnectionEvent, ReactiveHubConnectionFailure> = .init()
    private(set) var onMethodSubjects: [String: PassthroughSubject<ArgumentExtractorProtocol, Never>] = [:]
    private(set) var streamSubjects: [String: PassthroughSubject<ReactiveHubStreamOutputBox, Error>] = [:]
    private(set) var simpleInvocationSubjects: [String: PassthroughSubject<Void, Error>] = [:]
    private(set) var decodableInvocationSubjects: [String: PassthroughSubject<WrappedDecodable?, Error>] = [:]

    // MARK: - Initialization

    init(hubConnection: HubConnectionProtocol) {
        self.hubConnection = hubConnection
        self.hubConnection.delegate = self
    }

    public convenience init(
        url: URL,
        options: HttpConnectionOptions = HttpConnectionOptions(),
        permittedTransportTypes: TransportType = .all,
        reconnectPolicy: ReconnectPolicy? = nil,
        logger: Logger = NullLogger()
    ) {
        let reconnectPolicy = reconnectPolicy ?? DefaultReconnectPolicy()
        let transportFactory = DefaultTransportFactory(
            logger: logger,
            permittedTransportTypes: permittedTransportTypes
        )
        let connectionFactory: () -> HttpConnection = {
            // HttpConnection may overwrite some properties (most notably accessTokenProvider
            // when connecting to Azure SingalR Service) so needs its own copy to not corrupt
            // the instance provided by the user
            let httpConnectionOptionsCopy = HttpConnectionOptions()
            httpConnectionOptionsCopy.headers = options.headers
            httpConnectionOptionsCopy.accessTokenProvider = options.accessTokenProvider
            httpConnectionOptionsCopy.httpClientFactory = options.httpClientFactory
            httpConnectionOptionsCopy.skipNegotiation = options.skipNegotiation
            httpConnectionOptionsCopy.requestTimeout = options.requestTimeout
            return HttpConnection(
                url: url,
                options: httpConnectionOptionsCopy,
                transportFactory: transportFactory,
                logger: logger
            )
        }
        let reconnectableConnection = ReconnectableConnection(
            connectionFactory: connectionFactory,
            reconnectPolicy: reconnectPolicy,
            logger: logger
        )
        self.init(
            hubConnection: HubConnection(
                connection: reconnectableConnection,
                hubProtocol: JSONHubProtocol(logger: logger),
                logger: logger
            )
        )
    }

    deinit {
        onMethodSubjects.removeAll()
        streamSubjects.removeAll()
        simpleInvocationSubjects.removeAll()
        decodableInvocationSubjects.removeAll()
    }

    // MARK: - Public API

    public func start() {
        hubConnection.start()
    }

    public func send(method: String, arguments: [Encodable]) -> AnyPublisher<Void, Error> {
        Future<Void, Error> { [hubConnection] promisse in
            hubConnection.send(
                method: method,
                arguments: arguments,
                sendDidComplete: { error in
                    if let error = error {
                        promisse(.failure(error))
                    } else {
                        promisse(.success(()))
                    }
                }
            )
        }
        .eraseToAnyPublisher()
    }

    public func on(method: String) -> AnyPublisher<ArgumentExtractorProtocol, Never> {
        let subject: PassthroughSubject<ArgumentExtractorProtocol, Never>
        if let subjectInMemory = onMethodSubjects[method] {
            subject = subjectInMemory
        } else {
            subject = .init()
            onMethodSubjects[method] = subject
        }
        hubConnection.on(
            method: method,
            callback: { subject.send($0) }
        )
        return subject.eraseToAnyPublisher()
    }

    public func stream<T>(
        method: String,
        arguments: [Encodable]
    ) -> AnyPublisher<ReactiveHubStreamOutput<T>, Error> where T : Decodable {
        let subject: PassthroughSubject<ReactiveHubStreamOutputBox, Error>
        if let subjectInMemory = streamSubjects[method] {
            subject = subjectInMemory
        } else {
            subject = .init()
            streamSubjects[method] = subject
        }
        let streamHandle = hubConnection.stream(
            method: method,
            arguments: arguments,
            streamItemReceived: { (value: T) in
                subject.send(.itemReceived(.init(value)))
            },
            invocationDidComplete: { error in
                if let error = error {
                    subject.send(completion: .failure(error))
                } else {
                    subject.send(.invocationCompleted)
                }
            }
        )
        return subject
            .handleEvents(
                receiveCancel: { [weak self] in
                    self?.cancelStreamInvocation(streamHandle: streamHandle)
                    self?.streamSubjects.removeValue(forKey: method)
                }
            )
            .map { wrappedValue -> ReactiveHubStreamOutput<T> in
                switch wrappedValue {
                case let .itemReceived(wrappedItem):
                    guard let decodedItem = wrappedItem.decoded(as: T.self) else {
                        preconditionFailure("THIS SHOULD NEVER HAPPEN!")
                    }
                    return .itemReceived(decodedItem)
                case .invocationCompleted:
                    return .invocationCompleted
                }
            }
            .eraseToAnyPublisher()
    }

    public func invoke(method: String, arguments: [Encodable]) -> AnyPublisher<Void, Error> {
        let subject: PassthroughSubject<Void, Error>
        if let subjectInMemory = simpleInvocationSubjects[method] {
            subject = subjectInMemory
        } else {
            subject = .init()
            simpleInvocationSubjects[method] = subject
        }
        hubConnection.invoke(
            method: method,
            arguments: arguments,
            invocationDidComplete: { [weak self] error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    self?.simpleInvocationSubjects.removeValue(forKey: method)
                } else {
                    subject.send(())
                }
            }
        )
        return subject
            .handleEvents(
                receiveCancel: { [weak self] in
                    self?.simpleInvocationSubjects.removeValue(forKey: method)
                }
            )
            .eraseToAnyPublisher()
    }

    public func invoke<T>(method: String, arguments: [Encodable], resultType: T.Type) -> AnyPublisher<T?, Error> where T : Decodable {
        let subject: PassthroughSubject<WrappedDecodable?, Error>
        if let subjectInMemory = decodableInvocationSubjects[method] {
            subject = subjectInMemory
        } else {
            subject = .init()
            decodableInvocationSubjects[method] = subject
        }
        hubConnection.invoke(
            method: method,
            arguments: arguments,
            resultType: resultType,
            invocationDidComplete: { [weak self] response, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    self?.decodableInvocationSubjects.removeValue(forKey: method)
                } else if let response = response {
                    subject.send(.init(response))
                } else {
                    subject.send(nil)
                }
            }
        )
        return subject
            .handleEvents(
                receiveCancel: { [weak self] in
                    self?.decodableInvocationSubjects.removeValue(forKey: method)
                }
            )
            .removeDuplicates()
            .map { $0?.decoded(as: resultType) }
            .eraseToAnyPublisher()
    }

    public func stop() {
        hubConnection.stop()
    }

    // MARK: - Private API

    private func cancelStreamInvocation(streamHandle: StreamHandle) {
        hubConnection.cancelStreamInvocation(
            streamHandle: streamHandle,
            cancelDidFail: { [weak self] error in
                self?.connectionSubject.send(.streamInvocationFailed(forHandle: streamHandle, withError: error))
            }
        )
    }
}

@available(iOS 13.0, macOS 10.15, *)
extension CombineHubConnection: HubConnectionDelegate {
    public func connectionDidOpen(hubConnection: HubConnection) {
        connectionSubject.send(.opened(hubConnection))
    }

    public func connectionDidFailToOpen(error: Error) {
        connectionSubject.send(completion: .failure(.failedToOpen(error)))
    }

    public func connectionDidClose(error: Error?) {
        if let error = error {
            connectionSubject.send(completion: .failure(.closedWithError(error)))
        } else {
            connectionSubject.send(.closed)
        }
    }

    public func connectionWillReconnect(error: Error) {
        connectionSubject.send(.willReconnectAfterFailure(error))
    }

    public func connectionDidReconnect() {
        connectionSubject.send(.reconnected)
    }
}
#endif
