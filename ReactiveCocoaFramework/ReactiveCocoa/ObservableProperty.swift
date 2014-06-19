//
//  ObservableProperty.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-14.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Represents a mutable property of type T along with the changes to its value.
///
/// New observers of this stream will receive the current `value`, all future
/// values thereafter, and then a Completed event when the property is
/// deinitialized.
@final class ObservableProperty<T>: Observable<T> {
	var _mutableClosure: () -> T

	/// The value of the property.
	///
	/// Setting this will notify all observers of the new value.
	var value: T {
		get {
			return _mutableClosure()
		}

		set(newValue) {
			_mutableClosure = { newValue }
			_sendAll(.Next(Box(newValue)))
		}
	}

	init(_ value: T) {
		_mutableClosure = { value }

		super.init({ send in
			send(.Next(Box(value)))
			return nil
		})
	}

	deinit {
		_sendAll(.Completed)
	}

	func _sendAll(event: Event<T>) {
		for send in _observers {
			send.value(event)
		}
	}

	@conversion
	func __conversion() -> T {
		return value
	}
}
