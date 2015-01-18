//
//  FoundationExtensions.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-10-19.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
import LlamaKit

extension NSNotificationCenter {
	/// Returns a signal of notifications posted that match the given criteria.
	/// This signal will not terminate naturally, so it must be explicitly
	/// disposed to avoid leaks.
	public func rac_notifications(name: String? = nil, object: AnyObject? = nil) -> Signal<NSNotification> {
		return Signal { observer in
			let notificationObserver = self.addObserverForName(name, object: object, queue: nil) { notification in
				sendNext(observer, notification)
			}

			return ActionDisposable {
				self.removeObserver(notificationObserver)
			}
		}
	}
}

extension NSURLSession {
	/// Returns a producer that will execute the given request once for each
	/// invocation of start().
	public func rac_dataWithRequest(request: NSURLRequest) -> SignalProducer<(NSData, NSURLResponse)> {
		return SignalProducer { observer, disposable in
			let task = self.dataTaskWithRequest(request) { (data, response, error) in
				if data == nil || response == nil {
					sendError(observer, error)
				} else {
					let value = (data!, response!)
					sendNext(observer, value)
					sendCompleted(observer)
				}
			}

			disposable.addDisposable {
				task.cancel()
			}

			task.resume()
		}
	}
}
