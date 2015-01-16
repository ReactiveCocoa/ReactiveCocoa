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
///
/// Instances of this class are thread-safe.
public final class ObservableProperty<T> {
	private let queue = dispatch_queue_create("org.reactivecocoa.ReactiveCocoa.ObservableProperty", DISPATCH_QUEUE_CONCURRENT)
	private var sinks = Bag<SinkOf<Event<T>>>()
	private var _value: T

	/// The file in which this property was defined, if known.
	internal let file: String?

	/// The function in which this property was defined, if known.
	internal let function: String?

	/// The line number upon which this property was defined, if known.
	internal let line: Int?

	/// The current value of the property.
	///
	/// Setting this to a new value will notify all sinks attached to
	/// `values`.
	public var value: T {
		get {
			var readValue: T?

			dispatch_sync(queue) {
				readValue = self._value
			}

			return readValue!
		}

		set(value) {
			dispatch_barrier_sync(queue) {
				self._value = value

				for sink in self.sinks {
					sendNext(sink, value)
				}
			}
		}
	}

	/// A signal that will send the property's current value, followed by all
	/// changes over time. The signal will complete when the property
	/// deinitializes.
	public var values: ColdSignal<T> {
		return ColdSignal { [weak self] (sink, disposable) in
			if let strongSelf = self {
				var token: RemovalToken?

				dispatch_barrier_sync(strongSelf.queue) {
					token = strongSelf.sinks.insert(sink)
					sendNext(sink, strongSelf._value)
				}

				disposable.addDisposable {
					if let strongSelf = self {
						dispatch_barrier_async(strongSelf.queue) {
							strongSelf.sinks.removeValueForToken(token!)
						}
					}
				}
			} else {
				sendCompleted(sink)
			}
		}
	}

	public init(_ value: T, file: String = __FILE__, line: Int = __LINE__, function: String = __FUNCTION__) {
		_value = value

		self.file = file
		self.line = line
		self.function = function
	}

	deinit {
		dispatch_barrier_sync(queue) {
			for sink in self.sinks {
				sendCompleted(sink)
			}
		}
	}
}

extension ObservableProperty: SinkType {
	public func put(value: T) {
		self.value = value
	}
}

extension ObservableProperty: DebugPrintable {
	public var debugDescription: String {
		let function = self.function ?? ""
		let file = self.file ?? ""
		let line = self.line?.description ?? ""

		return "\(function).ObservableProperty (\(file):\(line))"
	}
}

infix operator <~ {
	associativity right
	precedence 90
}

/// Binds the given signal to a property, updating the property's value to
/// the latest value sent by the signal.
///
/// The binding will automatically terminate when the property is deinitialized.
public func <~ <T> (property: ObservableProperty<T>, signal: HotSignal<T>) {
	let disposable = signal.observe { [weak property] value in
		property?.value = value
		return
	}

	// Dispose of the binding when the property deallocates.
	property.values.start(completed: {
		disposable.dispose()
	})
}

infix operator <~! {
	associativity right
	precedence 90
}

/// Binds the given signal to a property, updating the property's value to the
/// latest value sent by the signal.
///
/// Note that the signal MUST NOT send an error, or the program will terminate.
///
/// The binding will automatically terminate when the property is deinitialized
/// or the signal completes.
public func <~! <T> (property: ObservableProperty<T>, signal: ColdSignal<T>) {
	let disposable = CompositeDisposable()

	// Dispose of the binding when the property deallocates.
	let propertyDisposable = property.values.start(completed: {
		disposable.dispose()
	})

	disposable.addDisposable(propertyDisposable)

	signal.startWithSink { [weak property] signalDisposable in
		disposable.addDisposable(signalDisposable)

		return Event.sink(next: { value in
			property?.value = value
			return
		}, error: { error in
			fatalError("Unhandled error in ColdSignal binding: \(error)")
		}, completed: {
			disposable.dispose()
		})
	}
}
