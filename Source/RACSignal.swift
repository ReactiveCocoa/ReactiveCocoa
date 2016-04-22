//
//  RACSignal.swift
//  Rex
//
//  Created by Rui Peres on 14/04/2016.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import enum Result.NoError

extension RACSignal {
    
    /// Converts `self` into a `Signal`.
    ///
    /// Because the operator can't know whether `self` is hot or cold,
    /// for certain things, like event streams (see `UIControl.signalForControlEvents`)
    /// use this method to be able to expose these inherently hot streams
    /// as `Signal`s.
    @warn_unused_result(message="Did you forget to call `observe` on the signal?")
    public func rex_toSignal() -> Signal<AnyObject?, NSError> {
        return Signal { observer in
            return self.toSignalProducer().start(observer)
        }
    }
    
    /// Converts `self` into a `Signal`, that can be used
    /// with the `takeUntil` operator, or as an "activation" signal.
    /// (e.g. a button)
    @warn_unused_result(message="Did you forget to call `observe` on the signal?")
    public final func rex_toTriggerSignal() -> Signal<(), NoError> {
        return self
            .rex_toSignal()
            .map { _ in () }
            .ignoreError()
    }
}
