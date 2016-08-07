//
//  FoundationExtensions.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-10-19.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
import enum Result.NoError

extension NotificationCenter {
	/// Returns a SignalProducer to observe posting of the specified
	/// notification.
	///
	/// - parameters:
	///   - name: name of the notification to observe
	///   - object: an instance which sends the notifications
	///
	/// - returns: A SignalProducer of notifications posted that match the given
	///            criteria.
	///
	/// - note: If the `object` is deallocated before starting the producer, it
	///         will terminate immediately with an `interrupted` event.
	///         Otherwise, the producer will not terminate naturally, so it must
	///         be explicitly disposed to avoid leaks.
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
	/// Returns a SignalProducer which performs the work associated with an
	/// `NSURLSession`
	///
	/// - parameters:
	///   - request: A request that will be performed when the producer is
	///              started
	///
	/// - returns: A producer that will execute the given request once for each
	///            invocation of `start()`.
	///
	/// - note: This method will not send an error event in the case of a server
	///         side error (i.e. when a response with status code other than
	///         200...299 is received).
	public func rac_data(with request: URLRequest) -> SignalProducer<(Data, URLResponse), NSError> {
		return SignalProducer { observer, disposable in
			let task = self.dataTask(with: request) { data, response, error in
				if let data = data, let response = response {
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
