//
//  Atomic.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// An atomic variable.
@final class Atomic<T> {
	let _lock = SpinLock()
	var _box: Box<T>
	
	/// Atomically gets or sets the value of the variable.
	var value: T {
		get {
			return _lock.withLock {
				return self._box
			}
		}
	
		set(newValue) {
			_lock.lock()
			_box = Box(newValue)
			_lock.unlock()
		}
	}
	
	/// Initializes the variable with the given initial value.
	init(_ value: T) {
		_box = Box(value)
	}
	
	/// Atomically replaces the contents of the variable.
	///
	/// Returns the old value.
	func swap(newValue: T) -> T {
		return modify { _ in newValue }
	}

	/// Atomically modifies the variable.
	///
	/// Returns the old value.
	func modify(action: T -> T) -> T {
		let (oldValue, _) = modify { oldValue in (action(oldValue), nil) }
		return oldValue
	}
	
	/// Atomically modifies the variable.
	///
	/// Returns the old value, plus arbitrary user-defined data.
	func modify<U>(action: T -> (T, U)) -> (T, U) {
		_lock.lock()
		let oldValue: T = _box
		let (newValue, data) = action(_box)
		_box = Box(newValue)
		_lock.unlock()
		
		return (oldValue, data)
	}
	
	/// Atomically performs an arbitrary action using the current value of the
	/// variable.
	///
	/// Returns the result of the action.
	func withValue<U>(action: T -> U) -> U {
		_lock.lock()
		let result = action(_box)
		_lock.unlock()
		
		return result
	}

	/// Treats the Atomic variable as its underlying value in expressions.
	@conversion func __conversion() -> T {
		return value
	}
}
