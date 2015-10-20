//
//  Signal.swift
//  Rex
//
//  Created by Neil Pankey on 5/9/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa

extension SignalType {

    /// Bring back the `observe` overload. The `observeNext` or pattern matching
    /// on `observe(Event)` is still annoying in practice and more verbose. This is
    /// also likely to change in a later RAC 4 alpha.
    internal func observe(next next: (Value -> ())? = nil, error: (Error -> ())? = nil, completed: (() -> ())? = nil, interrupted: (() -> ())? = nil) -> Disposable? {
        return self.observe { (event: Event<Value, Error>) in
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
    public func filterMap<U>(transform: Value -> U?) -> Signal<U, Error> {
        return Signal<U, Error> { observer in
            return self.observe(next: { value in
                if let val = transform(value) {
                    observer.sendNext(val)
                }
            }, error: { error in
                observer.sendError(error)
            }, completed: {
                observer.sendCompleted()
            }, interrupted: {
                observer.sendInterrupted()
            })
        }
    }

    /// Returns a signal that drops `Error` sending `replacement` terminal event
    /// instead, defaulting to `Completed`.
    public func ignoreError(replacement replacement: Event<Value, NoError> = .Completed) -> Signal<Value, NoError> {
        precondition(replacement.isTerminating)

        return Signal<Value, NoError> { observer in
            return self.observe { event in
                switch event {
                case let .Next(value):
                    observer.sendNext(value)
                case .Error:
                    observer.action(replacement)
                case .Completed:
                    observer.sendCompleted()
                case .Interrupted:
                    observer.sendInterrupted()
                }
            }
        }
    }

    /// Forwards events from `signal` until `interval`. Then if signal isn't completed yet,
    /// terminates with `event` on `scheduler`.
    ///
    /// If the interval is 0, the timeout will be scheduled immediately. The signal
    /// must complete synchronously (or on a faster scheduler) to avoid the timeout.
    public func timeoutAfter(interval: NSTimeInterval, withEvent event: Event<Value, Error>, onScheduler scheduler: DateSchedulerType) -> Signal<Value, Error> {
        precondition(interval >= 0)
        precondition(event.isTerminating)

        return Signal { observer in
            let disposable = CompositeDisposable()

            let date = scheduler.currentDate.dateByAddingTimeInterval(interval)
            disposable += scheduler.scheduleAfter(date) {
                observer.action(event)
            }

            disposable += self.observe(observer)
            return disposable
        }
    }
}

extension SignalType where Value: SequenceType {
    /// Returns a signal that flattens sequences of elements. The inverse of `collect`.
    public func uncollect() -> Signal<Value.Generator.Element, Error> {
        return Signal<Value.Generator.Element, Error> { observer in
            return self.observe { event in
                switch event {
                case let .Next(sequence):
                    sequence.forEach { observer.sendNext($0) }
                case let .Error(error):
                    observer.sendError(error)
                case .Completed:
                    observer.sendCompleted()
                case .Interrupted:
                    observer.sendInterrupted()
                }
            }
        }
    }
}
