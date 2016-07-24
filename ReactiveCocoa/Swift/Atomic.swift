//
//  Atomic.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

final class PosixThreadMutex: Locking {
	private var _mutex = pthread_mutex_t()

	init() {
		let result = pthread_mutex_init(&_mutex, nil)
		precondition(result == 0, "Failed to initialize mutex with error \(result).")
	}

	deinit {
		let result = pthread_mutex_destroy(&_mutex)
		precondition(result == 0, "Failed to destroy mutex with error \(result).")
	}

	func lock() {
		let result = pthread_mutex_lock(&_mutex)
		precondition(result == 0, "Failed to lock \(self) with error \(result).")
	}

	func unlock() {
		let result = pthread_mutex_unlock(&_mutex)
		precondition(result == 0, "Failed to unlock \(self) with error \(result).")
	}
}

/// An atomic variable.
public final class Atomic<Value>: AtomicProtocol {
	private var lock: PosixThreadMutex
	private var _value: Value

	/// Initialize the variable with the given initial value.
	/// 
	/// - parameters:
	///   - value: Initial value for `self`.
	public init(_ value: Value) {
		_value = value
		lock = PosixThreadMutex()
	}

	/// Atomically modifies the variable.
	///
	/// - parameters:
	///   - action: A closure that takes the current value.
	///
	/// Returns the old value.
	public func modify(_ action: @noescape (inout Value) throws -> Void) rethrows -> Value {
		return try withValue { value in
			try action(&_value)
			return value
		}
	}
	
	/// Atomically perform an arbitrary action using the current value of the
	/// variable.
	///
	/// - parameters:
	///   - action: A closure that takes the current value.
	///
	/// - returns: The result of the action.
	@discardableResult
	public func withValue<Result>(_ action: @noescape (Value) throws -> Result) rethrows -> Result {
		lock.lock()
		defer { lock.unlock() }

		return try action(_value)
	}
}


/// An atomic variable which uses a recursive lock.
internal final class RecursiveAtomic<Value>: AtomicProtocol {
	private var lock: RecursiveLock
	private var _value: Value
	private let didSetObserver: ((Value) -> Void)?

	/// Initialize the variable with the given initial value.
	/// 
	/// - parameters:
	///   - value: Initial value for `self`.
	///   - name: An optional name used to create the recursive lock.
	internal init(_ value: Value, name: StaticString? = nil, didSet action: ((Value) -> Void)? = nil) {
		_value = value

		lock = RecursiveLock()
		lock.name = name.map { String($0) }
		didSetObserver = action
	}

	/// Atomically modifies the variable.
	///
	/// - parameters:
	///   - action: A closure that takes the current value.
	///
	/// Returns the old value.
	@discardableResult
	func modify(_ action: @noescape (inout Value) throws -> Void) rethrows -> Value {
		return try withValue { value in
			try action(&_value)
			didSetObserver?(_value)
			return value
		}
	}
	
	/// Atomically perform an arbitrary action using the current value of the
	/// variable.
	///
	/// - parameters:
	///   - action: A closure that takes the current value.
	///
	/// - returns: The result of the action.
	@discardableResult
	func withValue<Result>(_ action: @noescape (Value) throws -> Result) rethrows -> Result {
		lock.lock()
		defer { lock.unlock() }

		return try action(_value)
	}
}

public protocol AtomicProtocol: class {
	associatedtype Value

	@discardableResult
	func withValue<Result>(_ action: @noescape (Value) throws -> Result) rethrows -> Result

	@discardableResult
	func modify(_ action: @noescape (inout Value) throws -> Void) rethrows -> Value
}

extension AtomicProtocol {	
	/// Atomically get or set the value of the variable.
	public var value: Value {
		get {
			return withValue { $0 }
		}
	
		set(newValue) {
			swap(newValue)
		}
	}

	/// Atomically replace the contents of the variable.
	///
	/// - parameters:
	///   - newValue: A new value for the variable.
	///
	/// - returns: The old value.
	@discardableResult
	public func swap(_ newValue: Value) -> Value {
		return modify { $0 = newValue }
	}
}
