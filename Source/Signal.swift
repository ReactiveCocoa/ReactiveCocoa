//
//  Signal.swift
//  Rex
//
//  Created by Neil Pankey on 5/9/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import enum Result.NoError

extension SignalProtocol {

    /// Applies `transform` to values from `signal` with non-`nil` results unwrapped and
    /// forwared on the returned signal.
    public func filterMap<U>(_ transform: (Value) -> U?) -> Signal<U, Error> {
        return Signal<U, Error> { observer in
            return self.observe { event in
                switch event {
                case let .next(value):
                    if let mapped = transform(value) {
                        observer.sendNext(mapped)
                    }
                case let .failed(error):
                    observer.sendFailed(error)
                case .completed:
                    observer.sendCompleted()
                case .interrupted:
                    observer.sendInterrupted()
                }
            }
        }
    }

    /// Returns a signal that drops `Error` sending `replacement` terminal event
    /// instead, defaulting to `Completed`.
    public func ignoreError(replacement: Event<Value, NoError> = .completed) -> Signal<Value, NoError> {
        precondition(replacement.isTerminating)

        return Signal<Value, NoError> { observer in
            return self.observe { event in
                switch event {
                case let .next(value):
                    observer.sendNext(value)
                case .failed:
                    observer.action(replacement)
                case .completed:
                    observer.sendCompleted()
                case .interrupted:
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
    public func timeout(after interval: TimeInterval, with event: Event<Value, Error>, on scheduler: DateSchedulerProtocol) -> Signal<Value, Error> {
        precondition(interval >= 0)
        precondition(event.isTerminating)

        return Signal { observer in
            let disposable = CompositeDisposable()

            let date = scheduler.currentDate.addingTimeInterval(interval)
            disposable += scheduler.schedule(after: date) {
                observer.action(event)
            }

            disposable += self.observe(observer)
            return disposable
        }
    }
    
    /// Forwards a value and then mutes the signal by dropping all subsequent values
    /// for `interval` seconds. Once time elapses the next new value will be forwarded
    /// and repeat the muting process. Error events are immediately forwarded even while
    /// the signal is muted.
    ///
    /// This operator could be used to coalesce multiple notifications in a short time
    /// frame by only showing the first one.
    public func muteFor(_ interval: TimeInterval, clock: DateSchedulerProtocol) -> Signal<Value, Error> {
        precondition(interval > 0)

        var expires = clock.currentDate
        return filter { _ in
            let now = clock.currentDate

            if expires.compare(now) != .orderedDescending {
                expires = now.addingTimeInterval(interval)
                return true
            }
            return false
        }
    }
}

extension SignalProtocol where Value: Sequence {
    /// Returns a signal that flattens sequences of elements. The inverse of `collect`.
    public func uncollect() -> Signal<Value.Iterator.Element, Error> {
        return Signal<Value.Iterator.Element, Error> { observer in
            return self.observe { event in
                switch event {
                case let .next(sequence):
                    sequence.forEach { observer.sendNext($0) }
                case let .failed(error):
                    observer.sendFailed(error)
                case .completed:
                    observer.sendCompleted()
                case .interrupted:
                    observer.sendInterrupted()
                }
            }
        }
    }
}
