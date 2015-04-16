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
	func modify(@noescape action: T -> T) -> T {
		lock()
		let oldValue = _value
		_value = action(_value)
		unlock()
		
		return oldValue
	}
	
	/// Atomically performs an arbitrary action using the current value of the
	/// variable.
	///
	/// Returns the result of the action.
	func withValue<U>(@noescape action: T -> U) -> U {
		lock()
		let result = action(_value)
		unlock()
		
		return result
	}
}
