//
//  FoundationExtensions.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-10-19.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
import enum Result.NoError

private var lifetimeKey: UInt8 = 0

extension NSObject: LifetimeProviding {
	/// An interruptible observation to the lifetime of `self`.
	///
	/// The signal emits `completed` when the object completes, or
	/// `interrupted` after the object is completed.
	@nonobjc public var lifetimeProducer: SignalProducer<(), NoError> {
		return SignalProducer(signal: lifetime)
	}

	/// A signal representing the lifetime of `self`.
	///
	/// The signal emits `completed` when the object completes, or
	/// `interrupted` after the object is completed.
	@nonobjc public var lifetime: Signal<(), NoError> {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		if let token = objc_getAssociatedObject(self, &lifetimeKey) as! DeallocationToken? {
			return token.deallocSignal
		}

		let token = DeallocationToken()
		objc_setAssociatedObject(self, &lifetimeKey, token, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

		return token.deallocSignal
	}
}

extension NotificationCenter {
	/// Returns a producer of notifications posted that match the given criteria.
	/// If the `object` is deallocated before starting the producer, it will 
	/// terminate immediatelly with an Interrupted event. Otherwise, the producer
	/// will not terminate naturally, so it must be explicitly disposed to avoid
	/// leaks.
	public func rac_notifications(forName name: Notification.Name?, object: AnyObject? = nil) -> SignalProducer<Notification, NoError> {
		// We're weakly capturing an optional reference here, which makes destructuring awkward.
		let objectWasNil = (object == nil)
		return SignalProducer { [weak object] observer, disposable in
			guard object != nil || objectWasNil else {
				observer.sendInterrupted()
				return
			}

			let notificationObserver = self.addObserver(forName: name, object: object, queue: nil) { notification in
				observer.sendNext(notification)
			}

			disposable += {
				self.removeObserver(notificationObserver)
			}
		}
	}
}

private let defaultSessionError = NSError(domain: "org.reactivecocoa.ReactiveCocoa.rac_dataWithRequest", code: 1, userInfo: nil)

extension URLSession {
	/// Returns a producer that will execute the given request once for each
	/// invocation of start().
	public func rac_data(with request: URLRequest) -> SignalProducer<(Data, URLResponse), NSError> {
		return SignalProducer { observer, disposable in
			let task = self.dataTask(with: request) { data, response, error in
				if let data = data, response = response {
					observer.sendNext((data, response))
					observer.sendCompleted()
				} else {
					observer.sendFailed(error ?? defaultSessionError)
				}
			}

			disposable += {
				task.cancel()
			}
			task.resume()
		}
	}
}
