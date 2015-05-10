//
//  Signal.swift
//  Rex
//
//  Created by Neil Pankey on 5/9/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

/// Applies `transform` to values from `signal` with non-`nil` results unwrapped and
/// forwared on the returned signal.
public func filterMap<T, U, E>(transform: T -> U?)(signal: Signal<T, E>) -> Signal<U, E> {
    return Signal { observer in
        signal.observe(next: { value in
            if let val = transform(value) {
                sendNext(observer, val)
            }
        }, error: { error in
            sendError(observer, error)
        }, completed: {
            sendCompleted(observer)
        }, interrupted: {
            sendInterrupted(observer)
        })
    }
}

/// Returns a signal that drops `Error` events, replacing them with `Completed`.
public func ignoreError<T, E>(signal: Signal<T, E>) -> Signal<T, NoError> {
    return signal |> ignoreError(replacement: .Completed)
}

/// Returns a signal that drops `Error` sending `replacement` terminal event instead.
public func ignoreError<T, E>(#replacement: Event<T, NoError>)(signal: Signal<T, E>) -> Signal<T, NoError> {
    precondition(replacement.isTerminating)

    return Signal { observer in
        return signal.observe(Signal.Observer { event in
            switch event {
            case let .Next(value):
                sendNext(observer, value.value)
            case .Error:
                observer.put(replacement)
            case .Completed:
                sendCompleted(observer)
            case .Interrupted:
                sendInterrupted(observer)
            }
        })
    }
}
