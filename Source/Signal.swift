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

/// Lifts values from `signal` into an optional.
public func optionalize<T, E>(signal: Signal<T, E>) -> Signal<T?, E> {
    return signal |> map { Optional($0) }
}

/// Forwards events from `signal` until `interval`. Then if signal isn't completed yet,
/// terminates with `event` on `scheduler`.
///
/// If the interval is 0, the timeout will be scheduled immediately. The signal
/// must complete synchronously (or on a faster scheduler) to avoid the timeout.
public func timeoutAfter<T, E>(interval: NSTimeInterval, withEvent event: Event<T, E>, onScheduler scheduler: DateSchedulerType) -> Signal<T, E> -> Signal<T, E> {
    precondition(interval >= 0)
    precondition(event.isTerminating)

    return { signal in
        return Signal { observer in
            let disposable = CompositeDisposable()

            let date = scheduler.currentDate.dateByAddingTimeInterval(interval)
            disposable += scheduler.scheduleAfter(date) {
                observer.put(event)
            }

            disposable += signal.observe(observer)
            return disposable
        }
    }
}

/// Returns a signal that flattens sequences of elements. The inverse of `collect`.
public func uncollect<S: SequenceType, E>(signal: Signal<S, E>) -> Signal<S.Generator.Element, E> {
    return Signal { observer in
        return signal.observe(Signal.Observer { event in
            switch event {
            case let .Next(sequence):
                map(sequence.value) { sendNext(observer, $0) }
            case let .Error(error):
                sendError(observer, error.value)
            case .Completed:
                sendCompleted(observer)
            case .Interrupted:
                sendInterrupted(observer)
            }
        })
    }
}
