//
//  WithLatestFromTests.swift
//
//
//  Created by Mike Welsh on 2023-12-28.
//

import Combine
import CombineTesting
import Foundation
import XCTest
@testable import CombinePublisherBooster

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
    weak var _cancellable: AnyCancellable?

    // Act
    do {
      let currentValueSubject = CurrentValueSubject<String, Never>("First")
      let latestFrom = CurrentValueSubject<Int, Never>(1)
      let subject = currentValueSubject.withLatestFrom(latestFrom)
      // Create a cancellable so that the subscription is also created to ensure it doesn't cause
      // a memory retention cycle.
      let cancellable = subject.sink(receiveCompletion: { _ in }, receiveValue: { _ in })

      _currentValueSubject = currentValueSubject
      _latestFrom = latestFrom
      _subject = subject as AnyObject
      _cancellable = cancellable
    }

    // Assert
    XCTAssertNil(_currentValueSubject)
    XCTAssertNil(_latestFrom)
    XCTAssertNil(_subject)
    XCTAssertNil(_cancellable)
  }

  func test_subscription_deallocatesOnCancel() {
    // Arrange
    weak var _currentValueSubject: CurrentValueSubject<String, Never>?
    weak var _latestFrom: CurrentValueSubject<Int, Never>?
    weak var _subject: AnyObject?
    weak var _subscriber: CapturingSubscriber<(String, Int?), Never>?

    // Act
    do {
      let currentValueSubject = CurrentValueSubject<String, Never>("First")
      let latestFrom = CurrentValueSubject<Int, Never>(1)
      let capturingSubscriber = CapturingSubscriber<(String, Int?), Never>()
      let subscription = WithLatestFromPublisher.WithLatestFromPublisherSubscription(subscriber: capturingSubscriber,
                                                                                     publisher: currentValueSubject,
                                                                                     other: latestFrom)

      capturingSubscriber.receive(subscription: subscription)
      subscription.cancel()

      _currentValueSubject = currentValueSubject
      _latestFrom = latestFrom
      _subscriber = capturingSubscriber
      _subject = subscription as AnyObject
    }

    // Assert
    XCTAssertNil(_currentValueSubject)
    XCTAssertNil(_latestFrom)
    XCTAssertNil(_subject)
    XCTAssertNil(_subscriber)
  }

  func test_subscription_deallocatesOnFinish() {
    // Arrange
    weak var _currentValueSubject: CurrentValueSubject<String, Never>?
    weak var _latestFrom: CurrentValueSubject<Int, Never>?
    weak var _subject: AnyObject?
    weak var _subscriber: CapturingSubscriber<(String, Int?), Never>?

    // Act
    do {
      let currentValueSubject = CurrentValueSubject<String, Never>("First")
      let latestFrom = CurrentValueSubject<Int, Never>(1)
      let capturingSubscriber = CapturingSubscriber<(String, Int?), Never>()
      let subscription = WithLatestFromPublisher.WithLatestFromPublisherSubscription(subscriber: capturingSubscriber,
                                                                                     publisher: currentValueSubject,
                                                                                     other: latestFrom)

      capturingSubscriber.receive(subscription: subscription)
      // Create demand to connect the subscription.
      // This means that if a subscription is never requested or canceled, then
      // it will cause a retain cycle because the `WithLatestFromPublisherSubscription` will not release
      // the subscriber.
      capturingSubscriber.getSubscription()?.request(.unlimited)
      currentValueSubject.send(completion: .finished)

      _currentValueSubject = currentValueSubject
      _latestFrom = latestFrom
      _subscriber = capturingSubscriber
      _subject = subscription as AnyObject
    }

    // Assert
    XCTAssertNil(_currentValueSubject)
    XCTAssertNil(_latestFrom)
    XCTAssertNil(_subject)
    XCTAssertNil(_subscriber)
  }

  func test_subscription_deallocatesOnError() {
    // Arrange
    weak var _currentValueSubject: CurrentValueSubject<String, Error>?
    weak var _latestFrom: CurrentValueSubject<Int, Error>?
    weak var _subject: AnyObject?
    weak var _subscriber: CapturingSubscriber<(String, Int?), Error>?

    // Act
    do {
      let currentValueSubject = CurrentValueSubject<String, Error>("First")
      let latestFrom = CurrentValueSubject<Int, Error>(1)
      let capturingSubscriber = CapturingSubscriber<(String, Int?), Error>()
      let subscription = WithLatestFromPublisher.WithLatestFromPublisherSubscription(subscriber: capturingSubscriber,
                                                                                     publisher: currentValueSubject,
                                                                                     other: latestFrom)

      capturingSubscriber.receive(subscription: subscription)
      // Create demand to connect the subscription.
      // This means that if a subscription is never requested or canceled, then
      // it will cause a retain cycle because the `WithLatestFromPublisherSubscription` will not release
      // the subscriber.
      capturingSubscriber.getSubscription()?.request(.unlimited)
      currentValueSubject.send(completion: .failure(NSError()))

      _currentValueSubject = currentValueSubject
      _latestFrom = latestFrom
      _subscriber = capturingSubscriber
      _subject = subscription as AnyObject
    }

    // Assert
    XCTAssertNil(_currentValueSubject)
    XCTAssertNil(_latestFrom)
    XCTAssertNil(_subject)
    XCTAssertNil(_subscriber)
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

  func test_withLatestFrom_concurrentDemandAndCancel() {
    // Arrange
    let passthrough = PassthroughSubject<String, Never>()
    let latestFrom = PassthroughSubject<Int, Never>()

    let subject = passthrough.withLatestFrom(latestFrom)
    let queue = DispatchQueue.global()
    let group = DispatchGroup()

    // Act
    // Use a dispatch group to ensure we run through many iterations.
    for _ in 0...50_000 {
      group.enter()
      queue.async {
        // Create demand
        let cancelable = subject.sink(receiveCompletion: { _ in }, receiveValue: { _ in })
        cancelable.cancel()
        // Do _not_ store the cancelable as our storage set here is not threadsafe.
        group.leave()
      }
    }

    // Assert
    group.wait()
    // No need to explicitly assert anything, just validate that we haven't crashed from a bad
    // memory access.
  }
}
