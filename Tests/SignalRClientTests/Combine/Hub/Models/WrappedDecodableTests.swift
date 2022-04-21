//
//  WrappedDecodableTests.swift
//  
//
//  Created by Eduardo Bocato on 15/07/21.
//

@testable import SignalRClient
import XCTest

final class WrappedDecodableTests: XCTestCase {
    func test_decoded_shouldReturnTheWrappedValue() {
        // Given
        let decodable = "value"
        let sut: WrappedDecodable = .init(decodable)

        // When
        let decodedValue = sut.decoded(as: String.self)

        // Then
        XCTAssertEqual(decodable, decodedValue)
    }

    func test_isEqual_whenValuesAreNotEqual_shouldReturnFalse() {
        // Given
        let decodable = "value"
        let lhs: WrappedDecodable = .init(decodable)
        let rhs: WrappedDecodable = .init("other value")

        // When
        let isEqual = lhs == rhs

        // Then
        XCTAssertFalse(isEqual)
    }

    func test_isEqual_whenValuesAreEqual_shouldReturnTrue() {
        // Given
        let decodable = "value"
        let lhs: WrappedDecodable = .init(decodable)
        let rhs: WrappedDecodable = .init(decodable)

        // When
        let isEqual = lhs == rhs

        // Then
        XCTAssertTrue(isEqual)
    }
}
