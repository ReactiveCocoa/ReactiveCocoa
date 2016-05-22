//
//  FoundationExtensions.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-10-19.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
import enum Result.NoError

extension NSNotificationCenter {
	/// Returns a producer of notifications posted that match the given criteria.
	/// If the `object` is deallocated before starting the producer, it will 
	/// terminate immediatelly with an Interrupted event. Otherwise, the producer
	/// will not terminate naturally, so it must be explicitly disposed to avoid
	/// leaks.
	public func rac_notifications(name: String? = nil, object: AnyObject? = nil) -> SignalProducer<NSNotification, NoError> {
		// We're weakly capturing an optional reference here, which makes destructuring awkward.
		let objectWasNil = (object == nil)
		return SignalProducer { [weak object] observer, disposable in
			guard object != nil || objectWasNil else {
				observer.sendInterrupted()
				return
			}

			let notificationObserver = self.addObserverForName(name, object: object, queue: nil) { notification in
				observer.sendNext(notification)
			}

			disposable += {
				self.removeObserver(notificationObserver)
			}
		}
	}
}

private let defaultSessionError = NSError(domain: "org.reactivecocoa.ReactiveCocoa.rac_dataWithRequest", code: 1, userInfo: nil)

extension NSURLSession {
	/// Returns a producer that will execute the given request once for each
	/// invocation of start().
	public func rac_dataWithRequest(request: NSURLRequest) -> SignalProducer<(NSData, NSURLResponse), NSError> {
		return SignalProducer { observer, disposable in
			let task = self.dataTaskWithRequest(request) { data, response, error in
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
