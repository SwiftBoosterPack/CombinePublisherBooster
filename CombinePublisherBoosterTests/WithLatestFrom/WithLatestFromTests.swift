//
//  WithLatestFromTests.swift
//
//
//  Created by Mike Welsh on 2023-12-28.
//

import Combine
import Foundation
import XCTest
import CombinePublisherBooster

class WithLatestFromTests: XCTestCase {
  var subscriptions = Set<AnyCancellable>()

  override func tearDown() {
    subscriptions.forEach { $0.cancel() }
    subscriptions.removeAll()
  }

  func test_withLatestFrom_deallocateInternals() {
    // Arrange
    weak var _currentValueSubject: CurrentValueSubject<String, Never>?
    weak var _latestFrom: CurrentValueSubject<Int, Never>?
    weak var _subject: AnyObject?

    // Act
    do {
      let currentValueSubject = CurrentValueSubject<String, Never>("First")
      let latestFrom = CurrentValueSubject<Int, Never>(1)
      let subject = currentValueSubject.withLatestFrom(latestFrom)

      _currentValueSubject = currentValueSubject
      _latestFrom = latestFrom
      _subject = subject as AnyObject
    }

    // Assert
    XCTAssertNil(_currentValueSubject)
    XCTAssertNil(_latestFrom)
    XCTAssertNil(_subject)
  }

  func test_withLatestFrom_emitsOnlyFromSelf() {
    // Arrange
    let passthrough = PassthroughSubject<String, Never>()
    let latestFrom = PassthroughSubject<Int, Never>()

    let subject = passthrough.withLatestFrom(latestFrom)

    let completionExpectation = expectation(description: "Completion")
    let valueExpectation = expectation(description: "Value")

    subject.sink(receiveCompletion: { _ in
      completionExpectation.fulfill()
    }, receiveValue: { _ in
      valueExpectation.fulfill()
    })
    .store(in: &subscriptions)

    // Act
    passthrough.send("Second")
    // Updating the latest from should not emit new values or complete.
    latestFrom.send(1)
    latestFrom.send(completion: .finished)
    // End by completing the passthrough
    passthrough.send(completion: .finished)

    // Assert
    waitForExpectations(timeout: 0.1)
  }

  func test_withLatestFrom_emittedValues() {
    // Arrange
    let passthrough = PassthroughSubject<String, Never>()
    let latestFrom = PassthroughSubject<Int, Never>()
    var capturedValues: [(String, Int?)] = []

    let subject = passthrough.withLatestFrom(latestFrom)

    let completionExpectation = expectation(description: "Completion")

    subject
      .sink(receiveCompletion: { _ in
      completionExpectation.fulfill()
    }, receiveValue: {
      capturedValues.append($0)
    })
    .store(in: &subscriptions)

    // Act
    passthrough.send("First")
    // Updating the latest from should not emit new values or complete.
    latestFrom.send(1)
    latestFrom.send(2)
    latestFrom.send(3)
    passthrough.send("Second")
    passthrough.send("Third")
    latestFrom.send(completion: .finished)
    // End by completing the passthrough
    passthrough.send(completion: .finished)

    // Assert
    waitForExpectations(timeout: 0.1)
    XCTAssertEqual(capturedValues.count, 3)
    XCTAssertEqual("First", capturedValues[0].0)
    XCTAssertNil(capturedValues[0].1)
    XCTAssertEqual("Second", capturedValues[1].0)
    XCTAssertEqual(3, capturedValues[1].1)
    XCTAssertEqual("Third", capturedValues[2].0)
    XCTAssertEqual(3, capturedValues[2].1)
  }

  func test_withLatestFrom_chain() {
    // Arrange
    let passthrough = PassthroughSubject<String, Never>()
    let latestFrom = PassthroughSubject<Int, Never>()
    let secondLatestFrom = PassthroughSubject<Float, Never>()
    var capturedValues: [(String, Int?, Float?)] = []

    let subject = passthrough.withLatestFrom(latestFrom)
      .withLatestFrom(secondLatestFrom)
    // Because it's chained, it's going to create two tuples. Flatten it here for easier
    // validation.
      .map { ($0.0.0, $0.0.1, $0.1)}

    let completionExpectation = expectation(description: "Completion")

    subject.sink(receiveCompletion: { _ in
      completionExpectation.fulfill()
    }, receiveValue: {
      capturedValues.append($0)
    })
    .store(in: &subscriptions)

    // Act
    passthrough.send("First")
    // Updating the latest from should not emit new values or complete.
    latestFrom.send(1)
    secondLatestFrom.send(1.1)
    latestFrom.send(2)
    passthrough.send("Second")
    secondLatestFrom.send(3.3)
    passthrough.send("Third")
    latestFrom.send(completion: .finished)
    // End by completing the passthrough
    passthrough.send(completion: .finished)

    // Assert
    waitForExpectations(timeout: 0.1)
    XCTAssertEqual(capturedValues.count, 3)
    XCTAssertEqual("First", capturedValues[0].0)
    XCTAssertNil(capturedValues[0].1)
    XCTAssertNil(capturedValues[0].2)
    XCTAssertEqual("Second", capturedValues[1].0)
    XCTAssertEqual(2, capturedValues[1].1)
    XCTAssertEqual(1.1, capturedValues[1].2)
    XCTAssertEqual("Third", capturedValues[2].0)
    XCTAssertEqual(2, capturedValues[2].1)
    XCTAssertEqual(3.3, capturedValues[2].2)
  }
}
