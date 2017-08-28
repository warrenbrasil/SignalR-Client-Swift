//
//  JSONHubProtocol.swift
//  SignalRClient
//
//  Created by Pawel Kadluczka on 8/27/17.
//  Copyright © 2017 Pawel Kadluczka. All rights reserved.
//

import Foundation

public class JSONHubProtocol: HubProtocol {
    private let recordSeparator = "\u{001e}"
    public let name = "json"
    public let type = ProtocolType.Text

    public func parseMessages(input: Data) throws -> [HubMessage] {
        let dataString = String(data: input, encoding: .utf8)!

        var hubMessages = [HubMessage]()
        let messages = dataString.components(separatedBy: recordSeparator)
        for message in messages {
            hubMessages.append(try createHubMessage(payload: message))
        }

        return hubMessages
    }

    private func createHubMessage(payload: String) throws -> HubMessage {
        // TODO: try to avoid double conversion (Data -> String -> Data)
        let json = try JSONSerialization.jsonObject(with: payload.data(using: .utf8)!)
        if let message = json as? NSDictionary, let rawMessageType = message.object(forKey: "messageType") as? Int, let messageType = MessageType(rawValue: rawMessageType) {
            switch messageType {
            case .Invocation:
                return try createInvocationMessage(message: message)
            case .StreamItem:
                return try createStreamItemMessage(message: message)
            case .Completion:
                return try createCompletionMessage(message: message)
            }
        }

        throw SignalRError.unknownMessageType
    }

    private func createInvocationMessage(message: NSDictionary) throws -> InvocationMessage {
        guard let invocationId = message.value(forKey: "invocationId") as? String,
            let target = message.value(forKey: "target") as? String else {
            throw SignalRError.invalidMessage
        }
        let nonBlocking = (message.value(forKey: "nonBlocking") as? Bool) ?? false

        // TODO: handle arguments
        return InvocationMessage(invocationId: invocationId, target: target, arguments: [], nonBlocking: nonBlocking)
    }

    private func createStreamItemMessage(message: NSDictionary) throws -> StreamItemMessage {
        guard let invocationId = message.value(forKey: "invocationId") as? String else {
            throw SignalRError.invalidMessage
        }

        // TODO: handle stream item
        return StreamItemMessage(invocationId: invocationId, item: nil)
    }

    private func createCompletionMessage(message: NSDictionary) throws -> CompletionMessage {
        guard let invocationId = message.value(forKey: "invocationId") as? String else {
            throw SignalRError.invalidMessage
        }

        // TODO: handle result
        return CompletionMessage(invocationId: invocationId, result: nil)
    }

    public func writeMessage(message: HubMessage) throws -> Data {
        guard message.messageType == .Invocation else {
            throw SignalRError.invalidOperation(message: "Unexpected messageType.")
        }

        let invocationMessage = message as! InvocationMessage
        let invocationJSONObject : [String: Any] = [
            "messageType": invocationMessage.messageType.rawValue,
            "invocationId": invocationMessage.invocationId,
            "target": invocationMessage.target,
            // TODO: handle arguments
            "nonBlocking": invocationMessage.nonBlocking]

        return try JSONSerialization.data(withJSONObject: invocationJSONObject)
    }
}
