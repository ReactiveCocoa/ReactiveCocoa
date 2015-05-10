//
//  SignalProducer.swift
//  Rex
//
//  Created by Neil Pankey on 5/9/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

/// Buckets each received value into a group based on the key returned
/// from `grouping`. Termination events on the original signal are
/// also forwarded to each producer group.
public func groupBy<K: Hashable, T, E>(grouping: T -> K)(producer: SignalProducer<T, E>) -> SignalProducer<(K, SignalProducer<T, E>), E> {

    return SignalProducer { observer, disposable in
        var groups: [K: Signal<T, E>.Observer] = [:]

        let lock = NSRecursiveLock()
        lock.name = "me.neilpa.rex.groupBy"

        producer.start(next: { value in
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

/// Prints all signal events
public func printAll<T, E>(signal: SignalProducer<T, E>) -> SignalProducer<T, E> {
    return signal
        |> on(started: {
            println("started")
            }, error: {
                println("error: \($0)")
            }, completed: {
                println("completed")
            }, interrupted: {
                println("interrupted")
            }, next: {
                println("next \($0)")
        })
}

/// Prints all nexts of signal
public func printNext<T, E>(signal: SignalProducer<T, E>) -> SignalProducer<T, E> {
    return signal
        |> on(next: {
            println("next \($0)")
        })
}

/// Prints all errors of signal
public func printError<T, E>(signal: SignalProducer<T, E>) -> SignalProducer<T, E> {
    return signal
        |> on(error: {
            println("error: \($0)")
        })
}
