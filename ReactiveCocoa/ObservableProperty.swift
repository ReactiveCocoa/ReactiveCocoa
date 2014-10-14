//
//  ObservableProperty.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-10-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
import LlamaKit

/// A property of type T that allows the observation of its changes.
public final class ObservableProperty<T> {
	private let queue = dispatch_queue_create("com.github.ReactiveCocoa.ObservableProperty", DISPATCH_QUEUE_SERIAL)
	private var sinks = Bag<SinkOf<Event<T>>>()

	/// The current value of the property.
	///
	/// Setting this to a new value will notify all observers of `changes` and
	/// all subscribers to `values()`.
	public var value: T {
		didSet(value) {
			dispatch_sync(queue) {
				for sink in self.sinks {
					sink.put(.Next(Box(value)))
				}
			}
		}
	}

	/// A signal of all future changes to this property's value.
	public lazy var changes: HotSignal<T> = {
		let (signal, sink) = HotSignal<T>.pipe()
		let eventSink = SinkOf<Event<T>> { event in
			switch (event) {
			case let .Next(value):
				sink.put(value.unbox)

			default:
				break
			}
		}

		dispatch_sync(self.queue) {
			let token = self.sinks.insert(eventSink)
			return ()
		}

		return signal
	}()

	init(_ value: T) {
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
		return ColdSignal { subscriber in
			var token: RemovalToken?

			dispatch_sync(self.queue) {
				token = self.sinks.insert(SinkOf(subscriber))
				subscriber.put(.Next(Box(self.value)))
			}

			subscriber.disposable.addDisposable {
				dispatch_sync(self.queue) {
					self.sinks.removeValueForToken(token!)
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
