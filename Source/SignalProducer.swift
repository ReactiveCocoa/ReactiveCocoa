//
//  SignalProducer.swift
//  Rex
//
//  Created by Neil Pankey on 5/9/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

extension SignalProducer {
    /// Buckets each received value into a group based on the key returned
    /// from `grouping`. Termination events on the original signal are
    /// also forwarded to each producer group.
    public func groupBy<K: Hashable>(grouping: T -> K) -> SignalProducer<(K, SignalProducer<T, E>), E> {
        return SignalProducer<(K, SignalProducer<T, E>), E> { observer, disposable in
            var groups: [K: Signal<T, E>.Observer] = [:]

            let lock = NSRecursiveLock()
            lock.name = "me.neilpa.rex.groupBy"

            self.start(next: { value in
                let key = grouping(value)

                lock.lock()
                var group = groups[key]
                if group == nil {
                    let (producer, sink) = SignalProducer<T, E>.buffer()
                    sendNext(observer, (key, producer))

                    groups[key] = sink
                    group = sink
                }
                lock.unlock()

                sendNext(group!, value)

            }, error: { error in
                sendError(observer, error)
                groups.values.map { sendError($0, error) }

            }, completed: { _ in
                sendCompleted(observer)
                groups.values.map { sendCompleted($0) }

            }, interrupted: { _ in
                sendInterrupted(observer)
                groups.values.map { sendInterrupted($0) }
            })
        }
    }

    /// Returns a signal that drops `Error` events, replacing them with `Completed`.
    public func ignoreError(replacement: Event<T, NoError> = .Completed) -> SignalProducer<T, NoError> {
        return lift { $0.ignoreError(replacement: replacement) }
    }

    /// Returns a signal that prints the signal events
    public func print() -> SignalProducer<T, E> {
        return on(event: { Swift.print($0) })
    }

    /// Returns a signal that prints the signal `Next` events
    public func printNext() -> SignalProducer<T, E> {
        return on(event: { event in
            if case .Next(_) = event {
                Swift.print(event)
            }
        })
    }

    /// Returns a signal that prints the signal `Error` events
    public func printError() -> SignalProducer<T, E> {
        return on(event: { event in
            if case .Error(_) = event {
                Swift.print(event)
            }
        })
    }
}
