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
	private var sinks = Bag<SinkOf<Event<T>>>()

	/// The current value of the property.
	///
	/// Setting this to a new value will notify all sinks attached to
	/// `values()`.
	public var value: T {
		didSet {
			dispatch_sync(queue) {
				for sink in self.sinks {
					sink.put(.Next(Box(self.value)))
				}
			}
		}
	}

	public init(_ value: T) {
		self.value = value
	}

	deinit {
		dispatch_sync(queue) {
			for sink in self.sinks {
				sink.put(.Completed)
			}
		}
	}

	/// A signal that will send the property's current value, followed by all
	/// changes over time. The signal will complete when the property
	/// deinitializes.
	public func values() -> ColdSignal<T> {
		return ColdSignal { [weak self] (sink, disposable) in
			if let strongSelf = self {
				var token: RemovalToken?

				dispatch_sync(strongSelf.queue) {
					token = strongSelf.sinks.insert(sink)
					sink.put(.Next(Box(strongSelf.value)))
				}

				disposable.addDisposable {
					if let strongSelf = self {
						dispatch_async(strongSelf.queue) {
							strongSelf.sinks.removeValueForToken(token!)
						}
					}
				}
			} else {
				sink.put(.Completed)
			}
		}
	}
}

extension ObservableProperty: SinkType {
	public func put(value: T) {
		self.value = value
	}
}

infix operator <~ {
	associativity right
	precedence 90
}

/// Binds the given signal to the given property, updating the property's value
/// to whatever is sent by the signal.
///
/// The binding will automatically terminate when the property is deinitialized.
public func <~ <T> (property: ObservableProperty<T>, signal: HotSignal<T>) {
	let disposable = signal.observe { [weak property] value in
		property?.value = value
		return
	}

	// Dispose of the binding when the property deallocates.
	property.values().start(completed: {
		disposable.dispose()
	})
}
