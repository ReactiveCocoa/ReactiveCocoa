//
//  ObservableProperty.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-10-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
import LlamaKit

/// A mutable property of type T that allows observation of its changes.
public final class ObservableProperty<T> {
	private let queue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.ObservableProperty", DISPATCH_QUEUE_SERIAL)
	private var subscribers = Bag<Subscriber<T>>()

	/// The current value of the property.
	///
	/// Setting this to a new value will notify all subscribers to `values()`.
	public var value: T {
		didSet(value) {
			dispatch_sync(queue) {
				for subscriber in self.subscribers {
					subscriber.put(.Next(Box(value)))
				}
			}
		}
	}

	public init(_ value: T) {
		self.value = value
	}

	deinit {
		dispatch_sync(queue) {
			for subscriber in self.subscribers {
				subscriber.put(.Completed)
			}
		}
	}

	/// A signal that will send the property's current value, followed by all
	/// changes over time. The signal will complete when the property
	/// deinitializes.
	public func values() -> ColdSignal<T> {
		return ColdSignal { subscriber in
			var token: RemovalToken?

			dispatch_sync(self.queue) {
				token = self.subscribers.insert(subscriber)
				subscriber.put(.Next(Box(self.value)))
			}

			subscriber.disposable.addDisposable {
				dispatch_sync(self.queue) {
					self.subscribers.removeValueForToken(token!)
				}
			}
		}
	}
}

extension ObservableProperty: SinkType {
	public func put(value: T) {
		self.value = value
	}
}
