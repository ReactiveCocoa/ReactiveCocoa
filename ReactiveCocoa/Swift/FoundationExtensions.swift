//
//  FoundationExtensions.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-10-19.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
import enum Result.NoError

private extension NSObject {
	var willDeallocProducer: SignalProducer<(), NoError> {
		return rac_willDeallocSignal()
			.toSignalProducer()
			.map { _ in () }
			.mapError { error in
				fatalError("Unexpected error: \(error)")
				()
		}
	}
}

extension NSNotificationCenter {
	/// Returns a producer of notifications posted that match the given criteria.
	///
	/// If the `object` is an instance of non-`NSObject` classes and the instance
	/// is deallocated before starting the producer, the producer will terminate
	/// immediatelly with an .Interrupted event.
	///
	/// If the `object` is `NSObject`, the producer will terminate automatically
	/// when the given object is deallocated.
	///
	/// Otherwise, the producer will not terminate naturally, so it must be
	/// explicitly disposed to avoid leaks.
	public func rac_notifications(name: String? = nil, object: AnyObject? = nil) -> SignalProducer<NSNotification, NoError> {
		// We're weakly capturing an optional reference here, which makes destructuring awkward.
		let objectWasNil = (object == nil)

		let producer = SignalProducer<NSNotification, NoError> { [weak object] observer, disposable in
			guard object != nil || objectWasNil else {
				observer.sendInterrupted()
				return
			}

			let notificationObserver = self.addObserverForName(name, object: object, queue: nil) { notification in
				observer.sendNext(notification)
			}

			disposable.addDisposable {
				self.removeObserver(notificationObserver)
			}
		}

		if let object = object as? NSObject {
			return producer.takeUntil(object.willDeallocProducer)
		} else {
			return producer
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

			disposable.addDisposable {
				task.cancel()
			}
			task.resume()
		}
	}
}
