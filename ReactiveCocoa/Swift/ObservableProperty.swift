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
		didSet {
			dispatch_sync(queue) {
				for subscriber in self.subscribers {
					subscriber.put(.Next(Box(self.value)))
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
		return ColdSignal { [weak self] subscriber in
			if let strongSelf = self {
				var token: RemovalToken?
				
				dispatch_sync(strongSelf.queue) {
					token = strongSelf.subscribers.insert(subscriber)
					subscriber.put(.Next(Box(strongSelf.value)))
				}
				
				subscriber.disposable.addDisposable {
					if let strongSelf = self {
						dispatch_async(strongSelf.queue) {
							strongSelf.subscribers.removeValueForToken(token!)
						}
					}
				}
			} else {
				subscriber.put(.Completed)
			}
		}
	}
}

extension ObservableProperty: SinkType {
	public func put(value: T) {
		self.value = value
	}
}
