//
//  NSUserDefaults.swift
//  Rex
//
//  Created by Neil Pankey on 5/28/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import ReactiveSwift
import ReactiveCocoa
import enum Result.NoError

extension UserDefaults {
    /// Sends value of `key` whenever it changes. Attempts to filter out repeats
    /// by casting to NSObject and checking for equality. If the values aren't
    /// convertible this will generate events whenever _any_ value in NSUserDefaults
    /// changes.
    public func rex_value(forKey key: String) -> SignalProducer<Any?, NoError> {
        let center = NotificationCenter.default
        let initial = object(forKey: key)

        let changes = center.rac_notifications(forName: UserDefaults.didChangeNotification)
            .map { _ in
                // The notification doesn't provide what changed so we have to look
                // it up every time
                self.object(forKey: key)
            }

        return SignalProducer<Any?, NoError>(value: initial)
            .concat(changes)
            .skipRepeats { previous, next in
                if let previous = previous as? NSObject, let next = next as? NSObject {
                    return previous == next
                }
                return false
            }
    }
}
