//
//  SignalProducer.swift
//  Rex
//
//  Created by Neil Pankey on 5/9/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import enum Result.NoError

extension SignalProducerType {

    /// Buckets each received value into a group based on the key returned
    /// from `grouping`. Termination events on the original signal are
    /// also forwarded to each producer group.
    @warn_unused_result(message="Did you forget to call `start` on the producer?")
    public func groupBy<Key: Hashable>(grouping: Value -> Key) -> SignalProducer<(Key, SignalProducer<Value, Error>), Error> {
        return SignalProducer<(Key, SignalProducer<Value, Error>), Error> { observer, disposable in
            var groups: [Key: Signal<Value, Error>.Observer] = [:]

            let lock = NSRecursiveLock()
            lock.name = "me.neilpa.rex.groupBy"

            self.start { event in
                switch event {
                case let .Next(value):
                    let key = grouping(value)

                    lock.lock()
                    var group = groups[key]
                    if group == nil {
                        let (producer, innerObserver) = SignalProducer<Value, Error>.buffer(Int.max)
                        observer.sendNext(key, producer)

                        groups[key] = innerObserver
                        group = innerObserver
                    }
                    lock.unlock()
                    
                    group!.sendNext(value)

                case let .Failed(error):
                    observer.sendFailed(error)
                    groups.values.forEach { $0.sendFailed(error) }

                case .Completed:
                    observer.sendCompleted()
                    groups.values.forEach { $0.sendCompleted() }

                case .Interrupted:
                    observer.sendInterrupted()
                    groups.values.forEach { $0.sendInterrupted() }
                }
            }
        }
    }

    /// Applies `transform` to values from self with non-`nil` results unwrapped and
    /// forwared on the returned producer.
    @warn_unused_result(message="Did you forget to call `start` on the producer?")
    public func filterMap<U>(transform: Value -> U?) -> SignalProducer<U, Error> {
        return lift { $0.filterMap(transform) }
    }

    /// Returns a producer that drops `Error` sending `replacement` terminal event
    /// instead, defaulting to `Completed`.
    @warn_unused_result(message="Did you forget to call `start` on the producer?")
    public func ignoreError(replacement replacement: Event<Value, NoError> = .Completed) -> SignalProducer<Value, NoError> {
        precondition(replacement.isTerminating)
        return lift { $0.ignoreError(replacement: replacement) }
    }

    /// Forwards events from self until `interval`. Then if producer isn't completed yet,
    /// terminates with `event` on `scheduler`.
    ///
    /// If the interval is 0, the timeout will be scheduled immediately. The producer
    /// must complete synchronously (or on a faster scheduler) to avoid the timeout.
    @warn_unused_result(message="Did you forget to call `start` on the producer?")
    public func timeoutAfter(interval: NSTimeInterval, withEvent event: Event<Value, Error>, onScheduler scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
        return lift { $0.timeoutAfter(interval, withEvent: event, onScheduler: scheduler) }
    }

    /// Forwards a value and then mutes the producer by dropping all subsequent values
    /// for `interval` seconds. Once time elapses the next new value will be forwarded
    /// and repeat the muting process. Error events are immediately forwarded even while
    /// the producer is muted.
    ///
    /// This operator could be used to coalesce multiple notifications in a short time
    /// frame by only showing the first one.
    @warn_unused_result(message="Did you forget to call `start` on the producer?")
    public func muteFor(interval: NSTimeInterval, clock: DateSchedulerType) -> SignalProducer<Value, Error> {
        return lift { $0.muteFor(interval, clock: clock) }
    }

    /// Delays the start of the producer by `interval` on the provided scheduler.
    @warn_unused_result(message="Did you forget to call `start` on the producer?")
    public func deferred(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
        return SignalProducer.empty
            .delay(interval, onScheduler: scheduler)
            .concat(self.producer)
    }

    /// Delays retrying on failure by `interval` up to `count` attempts.
    @warn_unused_result(message="Did you forget to call `start` on the producer?")
    public func deferredRetry(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType, count: Int = .max) -> SignalProducer<Value, Error> {
        precondition(count >= 0)

        if count == 0 {
            return producer
        }

        var retries = count
        return flatMapError { error in
                // The final attempt shouldn't defer the error if it fails
                var producer = SignalProducer<Value, Error>(error: error)
                if retries > 0 {
                    producer = producer.deferred(interval, onScheduler: scheduler)
                }

                retries -= 1
                return producer
            }
            .retry(count)
    }
}

extension SignalProducerType where Value: SequenceType {
    /// Returns a producer that flattens sequences of elements. The inverse of `collect`.
    @warn_unused_result(message="Did you forget to call `start` on the producer?")
    public func uncollect() -> SignalProducer<Value.Generator.Element, Error> {
        return lift { $0.uncollect() }
    }
}
