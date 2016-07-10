//
//  SignalProducer.swift
//  Rex
//
//  Created by Neil Pankey on 5/9/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import enum Result.NoError

extension SignalProducerProtocol {

    /// Buckets each received value into a group based on the key returned
    /// from `grouping`. Termination events on the original signal are
    /// also forwarded to each producer group.
    public func group<Key: Hashable>(by grouping: (Value) -> Key) -> SignalProducer<(Key, SignalProducer<Value, Error>), Error> {
        return SignalProducer<(Key, SignalProducer<Value, Error>), Error> { observer, disposable in
            var groups: [Key: Signal<Value, Error>.Observer] = [:]

            let lock = RecursiveLock()
            lock.name = "me.neilpa.rex.groupBy"

            self.start { event in
                switch event {
                case let .next(value):
                    let key = grouping(value)

                    lock.lock()
                    var group = groups[key]
                    if group == nil {
                        let (producer, innerObserver) = SignalProducer<Value, Error>.bufferingProducer(upTo: Int.max)
                        observer.sendNext(key, producer)

                        groups[key] = innerObserver
                        group = innerObserver
                    }
                    lock.unlock()
                    
                    group!.sendNext(value)

                case let .failed(error):
                    observer.sendFailed(error)
                    groups.values.forEach { $0.sendFailed(error) }

                case .completed:
                    observer.sendCompleted()
                    groups.values.forEach { $0.sendCompleted() }

                case .interrupted:
                    observer.sendInterrupted()
                    groups.values.forEach { $0.sendInterrupted() }
                }
            }
        }
    }

    /// Applies `transform` to values from self with non-`nil` results unwrapped and
    /// forwared on the returned producer.
    public func filterMap<U>(_ transform: (Value) -> U?) -> SignalProducer<U, Error> {
        return lift { $0.filterMap(transform) }
    }

    /// Returns a producer that drops `Error` sending `replacement` terminal event
    /// instead, defaulting to `Completed`.
    public func ignoreError(replacement: Event<Value, NoError> = .completed) -> SignalProducer<Value, NoError> {
        precondition(replacement.isTerminating)
        return lift { $0.ignoreError(replacement: replacement) }
    }

    /// Forwards events from self until `interval`. Then if producer isn't completed yet,
    /// terminates with `event` on `scheduler`.
    ///
    /// If the interval is 0, the timeout will be scheduled immediately. The producer
    /// must complete synchronously (or on a faster scheduler) to avoid the timeout.
    public func timeout(after interval: TimeInterval, with event: Event<Value, Error>, on scheduler: DateSchedulerProtocol) -> SignalProducer<Value, Error> {
        return lift { $0.timeout(after: interval, with: event, on: scheduler) }
    }

    /// Forwards a value and then mutes the producer by dropping all subsequent values
    /// for `interval` seconds. Once time elapses the next new value will be forwarded
    /// and repeat the muting process. Error events are immediately forwarded even while
    /// the producer is muted.
    ///
    /// This operator could be used to coalesce multiple notifications in a short time
    /// frame by only showing the first one.
    public func mute(for interval: TimeInterval, clock: DateSchedulerProtocol) -> SignalProducer<Value, Error> {
        return lift { $0.muteFor(interval, clock: clock) }
    }

    /// Delays the start of the producer by `interval` on the provided scheduler.
    public func `defer`(by interval: TimeInterval, on scheduler: DateSchedulerProtocol) -> SignalProducer<Value, Error> {
        return SignalProducer.empty
            .delay(interval, on: scheduler)
            .concat(self.producer)
    }

    /// Delays retrying on failure by `interval` up to `count` attempts.
    public func deferredRetry(interval: TimeInterval, on scheduler: DateSchedulerProtocol, count: Int = .max) -> SignalProducer<Value, Error> {
        precondition(count >= 0)

        if count == 0 {
            return producer
        }

        var retries = count
        return flatMapError { error in
                // The final attempt shouldn't defer the error if it fails
                var producer = SignalProducer<Value, Error>(error: error)
                if retries > 0 {
                    producer = producer.defer(by: interval, on: scheduler)
                }

                retries -= 1
                return producer
            }
            .retry(upTo: count)
    }
}

extension SignalProducerProtocol where Value: Sequence {
    /// Returns a producer that flattens sequences of elements. The inverse of `collect`.
    public func uncollect() -> SignalProducer<Value.Iterator.Element, Error> {
        return lift { $0.uncollect() }
    }
}

/// Temporary replacement of `buffer(upTo:)`.
/// https://github.com/ReactiveCocoa/ReactiveCocoa/blob/RAC5-swift3/ReactiveCocoa/Swift/SignalProducer.swift

extension SignalProducer {
    private static func bufferingProducer(upTo capacity: Int) -> (SignalProducer, Signal<Value, Error>.Observer) {
        precondition(capacity >= 0, "Invalid capacity: \(capacity)")

        // Used as an atomic variable so we can remove observers without needing
        // to run on a serial queue.
        let state: Atomic<BufferState<Value, Error>> = Atomic(BufferState())

        let producer = self.init { observer, disposable in
            // Assigned to when replay() is invoked synchronously below.
            var token: RemovalToken?

            let replayBuffer = ReplayBuffer<Value>()
            var replayValues: [Value] = []
            var replayToken: RemovalToken?
            var next = state.modify { state in
                replayValues = state.values
                if replayValues.isEmpty {
                    token = state.observers?.insert(observer)
                } else {
                    replayToken = state.replayBuffers.insert(replayBuffer)
                }
            }

            while !replayValues.isEmpty {
                replayValues.forEach(observer.sendNext)

                next = state.modify { state in
                    replayValues = replayBuffer.values
                    replayBuffer.values = []
                    if replayValues.isEmpty {
                        if let replayToken = replayToken {
                            state.replayBuffers.remove(using: replayToken)
                        }
                        token = state.observers?.insert(observer)
                    }
                }
            }

            if let terminationEvent = next.terminationEvent {
                observer.action(terminationEvent)
            }

            if let token = token {
                disposable += {
                    state.modify { state in
                        state.observers?.remove(using: token)
                    }
                }
            }
        }

        let bufferingObserver: Signal<Value, Error>.Observer = Observer { event in
            let originalState = state.modify { state in
                if let value = event.value {
                    state.add(value, upTo: capacity)
                } else {
                    // Disconnect all observers and prevent future
                    // attachments.
                    state.terminationEvent = event
                    state.observers = nil
                }
            }

            originalState.observers?.forEach { $0.action(event) }
        }

        return (producer, bufferingObserver)
    }
}

/// A uniquely identifying token for Observers that are replaying values in
/// BufferState.
private final class ReplayBuffer<Value> {
    private var values: [Value] = []
}

private struct BufferState<Value, Error: ErrorProtocol> {
    /// All values in the buffer.
    var values: [Value] = []

    /// Any terminating event sent to the buffer.
    ///
    /// This will be nil if termination has not occurred.
    var terminationEvent: Event<Value, Error>?
    
    /// The observers currently attached to the buffered producer, or nil if the
    /// producer was terminated.
    var observers: Bag<Signal<Value, Error>.Observer>? = Bag()
    
    /// The set of unused replay token identifiers.
    var replayBuffers: Bag<ReplayBuffer<Value>> = Bag()
    
    /// Appends a new value to the buffer, trimming it down to the given capacity
    /// if necessary.
    mutating func add(_ value: Value, upTo capacity: Int) {
        precondition(capacity >= 0)
        
        for buffer in replayBuffers {
            buffer.values.append(value)
        }
        
        if capacity == 0 {
            values = []
            return
        }
        
        if capacity == 1 {
            values = [ value ]
            return
        }
        
        values.append(value)
        
        let overflow = values.count - capacity
        if overflow > 0 {
            values.removeSubrange(0..<overflow)
        }
    }
}
