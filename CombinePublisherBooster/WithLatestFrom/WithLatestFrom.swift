//
//  WithLatestFrom.swift
//
//
//  Created by Mike Welsh on 2023-12-28.
//

import Combine
import Foundation

/// Extension to declare methods to create a WIthLatestFrom publisher.
public extension Publisher {
  /// Creates a publisher which emits a value whenever `self` would emit a value and includes the latest value received from
  /// `other` when possible, or `nil` if no value has been captured. If `other` completes, it is ignored regardless of error state.
  /// This publisher will complete when `self` completes.
  func withLatestFrom<OtherPublisherType>(_ other: OtherPublisherType) ->
      AnyPublisher<(Output, OtherPublisherType.Output?), Failure> where
      OtherPublisherType: Publisher, OtherPublisherType.Failure == Failure {
    WithLatestFromPublisher(self, other).eraseToAnyPublisher()
  }
}

/// Implementation for creating `WithLatsetFrom` similar to [RxSwift](https://github.com/ReactiveX/RxSwift/blob/main/RxSwift/Observables/WithLatestFrom.swift)
struct WithLatestFromPublisher<A, B>: Publisher where A: Publisher, B: Publisher,
                                                      A.Failure == B.Failure {

  init(_ publisher: A, _ other: B) {
    self.publisher = publisher
    self.other = other
  }

  typealias Output = (A.Output, B.Output?)
  typealias Failure = A.Failure

  /// We need a reference and hold on to A and B here so that upstream users of `WithLatestFrom` do not need to maintain
  /// referencse to A and B
  let publisher: A
  let other: B

  func receive<S>(subscriber: S) where S : Subscriber, A.Failure == S.Failure, (A.Output, B.Output?) == S.Input {
    subscriber.receive(subscription: WithLatestFromPublisherSubscription(subscriber: subscriber,
                                                                         publisher: publisher,
                                                                         other: other))
  }
}

/// Extension used to declare the subscription class.
extension WithLatestFromPublisher {
  /// Represents a subscription to the `WithLatestFromPublisher`
  final class WithLatestFromPublisherSubscription<S: Subscriber>: Subscription where A.Failure == B.Failure,
                                                                                     A.Failure == S.Failure,
                                                                                     S.Input == (A.Output, B.Output?) {
    @discardableResult
    init(subscriber: S, publisher: A, other: B) {
      self.subscriber = subscriber
      self.publisher = publisher
      self.other = other
    }

    /// The subscriber who wants to receive values
    var subscriber: S?
    /// Hold onto internal subscriptions
    var internalSubscriptions = Set<AnyCancellable>()
    /// The publisher which triggers emitting values
    let publisher: A
    /// The publisher that we want to get the latest value from.
    let other: B
    /// Capture the latest value from `other` - this should _only_ be accessed through the `safetyLock`
    var latestOutput: B.Output? = nil
    /// Lock to perform internal actions that may not inherently be threadsafe.
    let safetyLock = NSRecursiveLock()

    /// This is _not_ threadsafe to call as the mutation on `internalSubscription` is not guarded.
    func request(_ demand: Subscribers.Demand) {
      // We don't care what the particular demand is, we connect to the other publisher to
      // start capturing values.
      other.sink { _ in
        // We don't care about the `latestFrom` completing. We just want the values.
      } receiveValue: { [weak self] value in
        // If self no longer exists, don't do any work!
        guard let self else { return }
        safetyLock.lock()
        latestOutput = value
        safetyLock.unlock()
      }
      .store(in: &internalSubscriptions)

      publisher.sink { [weak self] completion in
        guard let self else { return }
        subscriber?.receive(completion: completion)
        // The subscriber can be released now, as we don't expect future values anymore.
        subscriber = nil
      } receiveValue: { [weak self] value in
        // If self no longer exists, don't do any work!
        guard let self else { return }
        // Capture the latest value safely.
        var captureValue: B.Output?
        safetyLock.lock()
        captureValue = latestOutput
        safetyLock.unlock()
        _ = subscriber?.receive((value, captureValue))
      }
      .store(in: &internalSubscriptions)

    }

    /// This is _not_ threadsafe to call as the mutation on `internalSubscription` is not guarded.
    func cancel() {
      self.subscriber = nil
      self.internalSubscriptions.forEach { $0.cancel() }
      self.internalSubscriptions.removeAll()
    }
  }
}
