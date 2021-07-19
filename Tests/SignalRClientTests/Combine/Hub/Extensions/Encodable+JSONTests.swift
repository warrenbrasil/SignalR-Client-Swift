//
//  Encodable+JSONTests.swift.swift
//  
//
//  Created by Eduardo Bocato on 15/07/21.
//

@testable import SignalRClient
import XCTest

final class EncodableJSONTests: XCTestCase {
    // MARK: - Properties

    private let sut: MyEntity = .init(
        name: "name",
        number: 1
    )

    // MARK: - Tests

    func test_asJSON_whenEnconderFails_itShouldReturnNil() {
        // Given
        let failingEncoder: FailingJSONEncoder = .init()

        // When
        let json = sut.asJSON(using: failingEncoder)

        // Then
        XCTAssertNil(json)
    }

    func test_asJSON_whenJSONSerializerFails_itShouldReturnNil() {
        // Given
        let failingJSONSerializer = FailingJSONSerialization.self

        // When
        let json = sut.asJSON(jsonSerializer: failingJSONSerializer)

        // Then
        XCTAssertNil(json)
    }

    func test_asJSON_shouldReturnExpectedDictionary() {
        // Given
        let expectedJSON = [
            "name": "name",
            "number": 1
        ] as NSDictionary

        // When
        let json = sut.asJSON()

        // Then
        XCTAssertEqual(json, expectedJSON)
    }

}

// MARK: - Test Helpers

struct MyEntity: Codable {
    let name: String
    let number: Int
}


final class FailingJSONEncoder: JSONEncoder {
    override func encode<T>(_ value: T) throws -> Data where T : Encodable {
        throw NSError(domain: "FailingJSONEncoder", code: -1, userInfo: nil)
    }
}

final class FailingJSONSerialization: JSONSerialization {
    override class func jsonObject(with data: Data, options opt: JSONSerialization.ReadingOptions = []) throws -> Any {
        throw NSError(domain: "FailingJSONSerialization", code: -1, userInfo: nil)
    }
}
