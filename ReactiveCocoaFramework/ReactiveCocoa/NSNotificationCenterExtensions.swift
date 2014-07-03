//
//  NSNotificationCenterExtensions.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-03.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import Foundation

extension NSNotificationCenter {
	/// Returns a Signal of the latest posted notification that matches the
	/// given criteria.
	func rac_notifications(name: String? = nil, object: AnyObject? = nil) -> Signal<NSNotification?> {
		return Signal(initialValue: nil) { sink in
			// TODO: Figure out how to deregister from this.
			self.addObserverForName(name, object: object, queue: nil) { notification in
				sink.put(notification)
			}

			return ()
		}
	}
}
