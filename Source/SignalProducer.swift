//
//  SignalProducer.swift
//  Rex
//
//  Created by Neil Pankey on 5/9/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

extension SignalProducerType {

    /// Bring back the `start` overload. The `startNext` or pattern matching
    /// on `start(Event)` is annoying in practice and more verbose. This is also
    /// likely to change in a later RAC 4 alpha.
    internal func start(next next: (Value -> ())? = nil, error: (Error -> ())? = nil, completed: (() -> ())? = nil, interrupted: (() -> ())? = nil) -> Disposable? {
        return self.start { (event: Event<Value, Error>) in
            switch event {
            case let .Next(value):
                next?(value)
            case let .Error(err):
                error?(err)
            case .Completed:
                completed?()
            case .Interrupted:
                interrupted?()
            }
        }
    }

    /// Buckets each received value into a group based on the key returned
    /// from `grouping`. Termination events on the original signal are
    /// also forwarded to each producer group.
    public func groupBy<Key: Hashable>(grouping: Value -> Key) -> SignalProducer<(Key, SignalProducer<Value, Error>), Error> {
        return SignalProducer<(Key, SignalProducer<Value, Error>), Error> { observer, disposable in
            var groups: [Key: Signal<Value, Error>.Observer] = [:]

            let lock = NSRecursiveLock()
            lock.name = "me.neilpa.rex.groupBy"

            self.start(next: { value in
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

            }, error: { error in
                observer.sendError(error)
                groups.values.forEach { $0.sendError(error) }

            }, completed: { _ in
                observer.sendCompleted()
                groups.values.forEach { $0.sendCompleted() }

            }, interrupted: { _ in
                observer.sendInterrupted()
                groups.values.forEach { $0.sendInterrupted() }
            })
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
}

extension SignalProducerType where Value: SequenceType {
    /// Returns a producer that flattens sequences of elements. The inverse of `collect`.
    public func uncollect() -> SignalProducer<Value.Generator.Element, Error> {
        return lift { $0.uncollect() }
    }
}

