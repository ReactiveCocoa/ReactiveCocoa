//
//  Atomic.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// An atomic variable.
public final class Atomic<Value> {
	private var mutex = pthread_mutex_t()
	private var _value: Value
	
	/// Atomically gets or sets the value of the variable.
	public var value: Value {
		get {
			return withValue { $0 }
		}
	
		set(newValue) {
			withMutableValue { $0 = newValue }
		}
	}
	
	/// Initializes the variable with the given initial value.
	public init(_ value: Value) {
		_value = value
		let result = pthread_mutex_init(&mutex, nil)
		assert(result == 0, "Failed to initialize mutex with error \(result).")
	}

	deinit {
		let result = pthread_mutex_destroy(&mutex)
		assert(result == 0, "Failed to destroy mutex with error \(result).")
	}

	private func lock() {
		let result = pthread_mutex_lock(&mutex)
		assert(result == 0, "Failed to lock \(self) with error \(result).")
	}
	
	private func unlock() {
		let result = pthread_mutex_unlock(&mutex)
		assert(result == 0, "Failed to unlock \(self) with error \(result).")
	}
	
	/// Atomically replaces the contents of the variable.
	///
	/// Returns the old value.
	public func swap(newValue: Value) -> Value {
		return modify { $0 = newValue }
	}

	/// Atomically modifies the variable.
	///
	/// Returns the old value.
	public func modify(@noescape action: (inout Value) throws -> Void) rethrows -> Value {
		return try withMutableValue { value in
			let oldValue = value
			try action(&value)
			return oldValue
		}
	}

	/// Atomically performs an arbitrary action using an in-out reference to the current value
	/// of the variable.
	///
	/// Returns the result of the action.
	public func withMutableValue<Result>(@noescape action: (inout Value) throws -> Result) rethrows -> Result {
		lock()
		defer { unlock() }

		return try action(&_value)
	}

	/// Atomically performs an arbitrary action using the current value of the
	/// variable.
	///
	/// Returns the result of the action.
	public func withValue<Result>(@noescape action: (Value) throws -> Result) rethrows -> Result {
		return try withMutableValue {
			return try action($0)
		}
	}
}
