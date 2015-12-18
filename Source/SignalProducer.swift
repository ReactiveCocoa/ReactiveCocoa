//
//  SignalProducer.swift
//  Rex
//
//  Created by Neil Pankey on 5/9/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

extension SignalProducerType {

    /// Buckets each received value into a group based on the key returned
    /// from `grouping`. Termination events on the original signal are
    /// also forwarded to each producer group.
    public func groupBy<Key: Hashable>(grouping: Value -> Key) -> SignalProducer<(Key, SignalProducer<Value, Error>), Error> {
        return SignalProducer<(Key, SignalProducer<Value, Error>), Error> { observer, disposable in
            var groups: [Key: Signal<Value, Error>.Observer] = [:]

            let lock = NSRecursiveLock()
            lock.name = "me.neilpa.rex.groupBy"

            self.start(Observer(next: { value in
                let key = grouping(value)

                lock.lock()
                var group = groups[key]
                if group == nil {
                    let (producer, sink) = SignalProducer<Value, Error>.buffer()
                    observer.sendNext(key, producer)

                    groups[key] = sink
                    group = sink
                }
                lock.unlock()

                group!.sendNext(value)

            }, failed: { error in
                observer.sendFailed(error)
                groups.values.forEach { $0.sendFailed(error) }

            }, completed: { _ in
                observer.sendCompleted()
                groups.values.forEach { $0.sendCompleted() }

            }, interrupted: { _ in
                observer.sendInterrupted()
                groups.values.forEach { $0.sendInterrupted() }
            }))
        }
    }

    /// Applies `transform` to values from self with non-`nil` results unwrapped and
    /// forwared on the returned producer.
    public func filterMap<U>(transform: Value -> U?) -> SignalProducer<U, Error> {
        return lift { $0.filterMap(transform) }
    }

    /// Returns a producer that drops `Error` sending `replacement` terminal event
    /// instead, defaulting to `Completed`.
    public func ignoreError(replacement replacement: Event<Value, NoError> = .Completed) -> SignalProducer<Value, NoError> {
        precondition(replacement.isTerminating)
        return lift { $0.ignoreError(replacement: replacement) }
    }

    /// Forwards events from self until `interval`. Then if producer isn't completed yet,
    /// terminates with `event` on `scheduler`.
    ///
    /// If the interval is 0, the timeout will be scheduled immediately. The producer
    /// must complete synchronously (or on a faster scheduler) to avoid the timeout.
    public func timeoutAfter(interval: NSTimeInterval, withEvent event: Event<Value, Error>, onScheduler scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
        return lift { $0.timeoutAfter(interval, withEvent: event, onScheduler: scheduler) }
    }

    /// Enforces that at least `interval` time passes before forwarding a value. If a
    /// new value arrives, the previous one is dropped and the `interval` delay starts
    /// again. Error events are immediately forwarded, even if there's a queued value.
    ///
    /// This operator is useful for scenarios like type-to-search where you want to
    /// wait for a "lull" in typing before kicking off a search request.
    public func debounce(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
        return lift { $0.debounce(interval, onScheduler: scheduler) }
    }

    /// Forwards a value and then mutes the producer by dropping all subsequent values
    /// for `interval` seconds. Once time elapses the next new value will be forwarded
    /// and repeat the muting process. Error events are immediately forwarded even while
    /// the producer is muted.
    ///
    /// This operator could be used to coalesce multiple notifications in a short time
    /// frame by only showing the first one.
    public func muteFor(interval: NSTimeInterval, withScheduler scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
        return lift { $0.muteFor(interval, withScheduler: scheduler) }
    }

    /// Delays the start of the producer by `interval` on the provided scheduler.
    public func delayedStart(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType) -> SignalProducer<Value, Error> {
        return SignalProducer.empty
            .delay(interval, onScheduler: scheduler)
            .concat(self.producer)
    }

    /// Delays retrying on failure by `interval`. The last error received is forwarded
    /// if all `attempts` are exhausted.
    public func delayedRetry(interval: NSTimeInterval, onScheduler scheduler: DateSchedulerType, attempts: Int = .max) -> SignalProducer<Value, Error> {
        precondition(attempts > 0)

        return flatMapError {
                // TODO This delays the final error if all attempts are exhausted
                SignalProducer(error: $0).delayedStart(interval, onScheduler: scheduler)
            }
            .retry(attempts - 1)
    }
}

extension SignalProducerType where Value: SequenceType {
    /// Returns a producer that flattens sequences of elements. The inverse of `collect`.
    public func uncollect() -> SignalProducer<Value.Generator.Element, Error> {
        return lift { $0.uncollect() }
    }
}

