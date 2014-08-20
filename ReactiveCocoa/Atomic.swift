
//
//  Atomic.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// An atomic variable.
internal final class Atomic<T> {
	private var spinlock = OS_SPINLOCK_INIT
	private var _value: T
	
	/// Atomically gets or sets the value of the variable.
	var value: T {
		get {
			lock()
			let v = _value
			unlock()

			return v
		}
	
		set(newValue) {
			lock()
			_value = newValue
			unlock()
		}
	}
	
	/// Initializes the variable with the given initial value.
	init(_ value: T) {
		_value = value
	}
	
	private func lock() {
		withUnsafeMutablePointer(&spinlock, OSSpinLockLock)
	}
	
	private func unlock() {
		withUnsafeMutablePointer(&spinlock, OSSpinLockUnlock)
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
		let (oldValue, _) = modify { oldValue in (action(oldValue), 0) }
		return oldValue
	}
	
	/// Atomically modifies the variable.
	///
	/// Returns the old value, plus arbitrary user-defined data.
	func modify<U>(action: T -> (T, U)) -> (T, U) {
		lock()
		let oldValue: T = _value
		let (newValue, data) = action(_value)
		_value = newValue
		unlock()
		
		return (oldValue, data)
	}
	
	/// Atomically performs an arbitrary action using the current value of the
	/// variable.
	///
	/// Returns the result of the action.
	func withValue<U>(action: T -> U) -> U {
		lock()
		let result = action(_value)
		unlock()
		
		return result
	}
}
