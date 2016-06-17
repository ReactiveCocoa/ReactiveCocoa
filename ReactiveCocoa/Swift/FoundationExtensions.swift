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
	/// A function to observe posted notifications through returned signal
	/// producer.
	///
	/// - parameters:
	///   - name: notification name to observe
	///   - object: an instance that sends the notifications
	/// - returns: A producer of notifications posted that match the given 
	///            criteria.
	///
	/// - note: If the `object` is deallocated before starting the producer, it
	///         will terminate immediatelly with an Interrupted event.
	///         Otherwise, the producer will not terminate naturally, so it must
	///         be explicitly disposed to avoid leaks.
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
	/// - parameters:
	///   - request: A request that will be performed when producer is started
	///
	/// - returns: A producer that will execute the given request once for each
	///            invocation of `start()`.
	/// - note: This method will not send error event upon server-side error
	///         (i.e. when response with code other than 200...299 is received).
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
