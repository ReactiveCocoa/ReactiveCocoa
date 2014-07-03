//
//  ObservableProperty.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-26.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Represents a mutable property of type T along with the changes to its value.
@final class ObservableProperty<T>: Observable<T>, Sink {
	typealias Element = T

	var _sink = SinkOf<T> { _ in () }

	/// The current value of the property.
	///
	/// Setting this will notify all observers of the change.
	override var current: T {
		get {
			return super.current
		}

		set(newValue) {
			_sink.put(newValue)
		}
	}

	/// Initializes the property with the given default value.
	init(_ value: T) {
		super.init(generator: { sink in
			sink.put(value)
			self._sink = sink
		})
	}

	/// Treats the property as its current value in expressions.
	@conversion func __conversion() -> T {
		return current
	}

	func put(value: T) {
		current = value
	}
}
