//
//  NSNotificationCenterExtensions.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-03.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

public extension NSNotificationCenter {
	/// Returns a Signal of the latest posted notification that matches the
	/// given criteria.
	public func rac_notifications(name: String? = nil, object: AnyObject? = nil) -> Signal<NSNotification?> {
		let disposable = ScopedDisposable(SerialDisposable())

		return Signal(initialValue: nil) { sink in
			let observer = self.addObserverForName(name, object: object, queue: nil) { notification in
				sink.put(notification)
			}

			disposable.innerDisposable.innerDisposable = ActionDisposable {
				self.removeObserver(observer)
			}

			return ()
		}
	}
}
