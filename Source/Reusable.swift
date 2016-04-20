//
//  Reusable.swift
//  Rex
//
//  Created by David Rodrigues on 20/04/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import ReactiveCocoa
import enum Result.NoError


/// A protocol for components that can be reused using `prepareForReuse`.
public protocol Reusable {
    var rac_prepareForReuseSignal: RACSignal! { get }
}

extension Reusable {

    /// A signal which will send a `Next` event whenever `prepareForReuse` is invoked upon
    /// the receiver.
    ///
    /// - Note: This signal is particular useful to be used as a trigger for the `takeUntil`
    /// operator.
    ///
    /// #### Examples
    ///
    /// ```
    /// button
    ///     .rex_controlEvents(.TouchUpInside)
    ///     .takeUntil(self.rex_prepareForReuse)
    ///     .startWithNext { _ in
    ///         // do other things
    ///      }
    ///
    /// label.rex_text <~
    ///     titleProperty
    ///         .producer
    ///         .takeUntil(self.rex_prepareForReuse)
    /// ```
    ///
    public var rex_prepareForReuse: Signal<Void, NoError> {
        return rac_prepareForReuseSignal
            .rex_toTriggerSignal()
    }
}
