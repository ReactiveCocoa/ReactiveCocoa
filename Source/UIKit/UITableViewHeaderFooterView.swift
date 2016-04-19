//
//  UITableViewHeaderFooterView.swift
//  Rex
//
//  Created by David Rodrigues on 19/04/16.
//  Copyright © 2016 Neil Pankey. All rights reserved.
//

import UIKit
import ReactiveCocoa
import Result

extension UITableViewHeaderFooterView {

    /// A signal which will send a `Next` event whenever `prepareForReuse` is invoked upon
    /// the receiver.
    ///
    /// - Note: This signal is particular useful to be used as a trigger for the `takeUntil` 
    /// operator.
    ///
    /// #### Examples
    ///
    /// ```
    /// self.button
    ///     .rex_controlEvents(.TouchUpInside)
    ///     .takeUntil(self.rex_prepareForReuseSignal)
    ///     .startWithNext { _ in
    ///         // do other things
    ///      }
    ///
    /// self.label.rex_text <~
    ///     titleProperty
    ///         .producer
    ///         .takeUntil(self.rex_prepareForReuseSignal)
    /// ```
    ///
    public var rex_prepareForReuseSignal: Signal<Void, NoError> {
        return rac_prepareForReuseSignal.rex_toTriggerSignal()
    }

}
