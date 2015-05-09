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
        var groups: Dictionary<K, Signal<T, E>.Observer> = [:]

        producer.start(next: { value in
            let key = grouping(value)
            var group = groups[key]

            if group == nil {
                let (producer, sink) = SignalProducer<T, E>.buffer()
                groups[key] = sink
                group = sink

                sendNext(observer, (key, producer))
            }
            sendNext(group!, value)

            }, error: { error in
                sendError(observer, error)
                groups.values.map { sendError($0, error) }

            }, completed: { _ in
                sendCompleted(observer)
                groups.values.map { sendCompleted($0) }

            }, interrupted: { _ in
                groups.values.map { sendInterrupted($0) }
                sendInterrupted(observer)
        })
    }
}
