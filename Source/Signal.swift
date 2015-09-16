//
//  Signal.swift
//  Rex
//
//  Created by Neil Pankey on 5/9/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

extension Signal {

    /// Bring back the `observe` overload. The `observeNext` or pattern matching
    /// on `observe(Event)` is still annoying in practice and more verbose. This is
    /// also likely to change in a later RAC 4 alpha.
    internal func observe(next next: (T -> ())? = nil, error: (E -> ())? = nil, completed: (() -> ())? = nil, interrupted: (() -> ())? = nil) -> Disposable? {
        return self.observe { (event: Event<T, E>) in
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

    /// Applies `transform` to values from `signal` with non-`nil` results unwrapped and
    /// forwared on the returned signal.
    public func filterMap<U>(transform: T -> U?) -> Signal<U, E> {
        return Signal<U, E> { observer in
            return self.observe(next: { value in
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

    /// Returns a signal that drops `Error` sending `replacement` terminal event
    /// instead, defaulting to `Completed`.
    public func ignoreError(replacement replacement: Event<T, NoError> = .Completed) -> Signal<T, NoError> {
        precondition(replacement.isTerminating)

        return Signal<T, NoError> { observer in
            return self.observe { event in
                switch event {
                case let .Next(value):
                    sendNext(observer, value)
                case .Error:
                    observer(replacement)
                case .Completed:
                    sendCompleted(observer)
                case .Interrupted:
                    sendInterrupted(observer)
                }
            }
        }
    }

    /// Forwards events from `signal` until `interval`. Then if signal isn't completed yet,
    /// terminates with `event` on `scheduler`.
    ///
    /// If the interval is 0, the timeout will be scheduled immediately. The signal
    /// must complete synchronously (or on a faster scheduler) to avoid the timeout.
    public func timeoutAfter(interval: NSTimeInterval, withEvent event: Event<T, E>, onScheduler scheduler: DateSchedulerType) -> Signal<T, E> {
        precondition(interval >= 0)
        precondition(event.isTerminating)

        return Signal { observer in
            let disposable = CompositeDisposable()

            let date = scheduler.currentDate.dateByAddingTimeInterval(interval)
            disposable += scheduler.scheduleAfter(date) {
                observer(event)
            }

            disposable += self.observe(observer)
            return disposable
        }
    }
}

extension Signal where T: SequenceType {
    /// Returns a signal that flattens sequences of elements. The inverse of `collect`.
    public func uncollect() -> Signal<T.Generator.Element, E> {
        return Signal<T.Generator.Element, E> { observer in
            return self.observe { event in
                switch event {
                case let .Next(sequence):
                    sequence.forEach { sendNext(observer, $0) }
                case let .Error(error):
                    sendError(observer, error)
                case .Completed:
                    sendCompleted(observer)
                case .Interrupted:
                    sendInterrupted(observer)
                }
            }
        }
    }
}
