//
//  SignalingProperty.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-26.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Represents a mutable property of type T along with the changes to its value.
@final class SignalingProperty<T>: Sink {
	typealias Element = T

	let _sink: SinkOf<T>

	/// A signal representing the current value of the property, along with all
	/// changes to it over time.
	let signal: Signal<T>

	/// The current value of the property.
	var value: T {
		get {
			return signal.current
		}

		set(newValue) {
			_sink.put(newValue)
		}
	}

	/// Initializes the property with the given default value.
	init(_ defaultValue: T) {
		(signal, _sink) = Signal.pipeWithInitialValue(defaultValue)
	}

	/// Treats the property as its current value in expressions.
	@conversion func __conversion() -> T {
		return value
	}

	/// Treats the property as a signal of its values in expressions.
	@conversion func __conversion() -> Signal<T> {
		return signal
	}

	func put(value: T) {
		self.value = value
	}
}
