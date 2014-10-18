//
//  NSNotificationCenterExtensions.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-07-03.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

extension NSNotificationCenter {
	/// Returns a signal of notifications posted that match the given criteria.
	public func rac_notifications(name: String? = nil, object: AnyObject? = nil) -> HotSignal<NSNotification> {
		return HotSignal { sink in
			let observer = self.addObserverForName(name, object: object, queue: nil) { notification in
				sink.put(notification)
			}

			return ActionDisposable {
				self.removeObserver(observer)
			}
		}
	}
}
