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

extension NSURLSession {
	/// Returns a signal that will fetch data using the given request.
	public func rac_dataWithRequest(request: NSURLRequest) -> ColdSignal<(NSData, NSURLResponse)> {
		return ColdSignal { subscriber in
			let task = self.dataTaskWithRequest(request) { (data, response, error) in
				if data == nil || response == nil {
					subscriber.put(.Error(error))
				} else {
					let value = (data!, response!)
					subscriber.put(.Next(Box(value)))
					subscriber.put(.Completed)
				}
			}

			subscriber.disposable.addDisposable {
				task.cancel()
			}

			task.resume()
		}
	}
}