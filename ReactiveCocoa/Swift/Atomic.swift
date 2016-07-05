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
			modify { _ in newValue }
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
	@discardableResult
	public func swap(_ newValue: Value) -> Value {
		return modify { _ in newValue }
	}

	/// Atomically modifies the variable.
	///
	/// Returns the old value.
	@discardableResult
	public func modify(_ action: @noescape (Value) throws -> Value) rethrows -> Value {
		return try withValue { value in
			_value = try action(value)
			return value
		}
	}
	
	/// Atomically performs an arbitrary action using the current value of the
	/// variable.
	///
	/// Returns the result of the action.
	@discardableResult
	public func withValue<Result>(_ action: @noescape (Value) throws -> Result) rethrows -> Result {
		lock()
		defer { unlock() }

		return try action(_value)
	}
}
