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
}
