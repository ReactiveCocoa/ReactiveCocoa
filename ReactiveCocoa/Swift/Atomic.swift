//
//  Atomic.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

public protocol MutexType {
	func lock()
	func unlock()
}

public final class RecursiveLock: MutexType {
	private var _lock: NSRecursiveLock

	public init(_ name: String) {
		_lock = NSRecursiveLock()
		_lock.name = name
	}

	public func lock() {
		_lock.lock()
	}

	public func unlock() {
		_lock.unlock()
	}
}

public final class PosixThreadMutex: MutexType {
	private var mutex = pthread_mutex_t()
	
	public init() {
		let result = pthread_mutex_init(&mutex, nil)
		assert(result == 0, "Failed to initialize mutex with error \(result).")
	}
	
	deinit {
		let result = pthread_mutex_destroy(&mutex)
		assert(result == 0, "Failed to destroy mutex with error \(result).")
	}
	
	public func lock() {
		let result = pthread_mutex_lock(&mutex)
		assert(result == 0, "Failed to lock \(self) with error \(result).")
	}
	
	public func unlock() {
		let result = pthread_mutex_unlock(&mutex)
		assert(result == 0, "Failed to unlock \(self) with error \(result).")
	}
}

/// An atomic variable.
public final class Atomic<Value> {

	private var _mutex: MutexType
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
	public init(_ value: Value, mutex: MutexType = PosixThreadMutex()) {
		_value = value
		_mutex = mutex
	}

	private func lock() {
		_mutex.lock()
	}
	
	private func unlock() {
		_mutex.unlock()
	}
	
	/// Atomically replaces the contents of the variable.
	///
	/// Returns the old value.
	public func swap(newValue: Value) -> Value {
		return modify { _ in newValue }
	}

	/// Atomically modifies the variable.
	///
	/// Returns the old value.
	public func modify(@noescape action: (Value) throws -> Value) rethrows -> Value {
		return try modify(action, completion: { _ in })
	}

	/// Atomically modifies the variable.
	///
	/// Returns the old value.
	public func modify(@noescape action: (Value) throws -> Value, @noescape completion: (Value) -> ()) rethrows -> Value {
		return try withValue { value in
			_value = try action(value)
			completion(_value)
			return value
		}
	}
	
	/// Atomically performs an arbitrary action using the current value of the
	/// variable.
	///
	/// Returns the result of the action.
	public func withValue<Result>(@noescape action: (Value) throws -> Result) rethrows -> Result {
		lock()
		defer { unlock() }

		return try action(_value)
	}
}

public struct AnyAtomic<Value> {
	private let _state: AnyAtomicState<Value>

	init(value: Value) {
		_state = AnyAtomicState(value: value)
	}

	init(atomic: Atomic<Value>) {
		_state = AnyAtomicState(atomic: atomic)
	}

	/// Atomically performs an arbitrary action using the current value of the
	/// variable.
	///
	/// Returns the result of the action.
	public func withValue<Result>(@noescape action: (Value) throws -> Result) rethrows -> Result {
		return try _state.withValue(action)
	}
}

private enum AnyAtomicState<Value> {
	case Constant(Value)
	case Atomic(ReactiveCocoa.Atomic<Value>)

	init(value: Value) {
		self = .Constant(value)
	}

	init(atomic: ReactiveCocoa.Atomic<Value>) {
		self = .Atomic(atomic)
	}

	/// Atomically performs an arbitrary action using the current value of the
	/// variable.
	///
	/// Returns the result of the action.
	func withValue<Result>(@noescape action: (Value) throws -> Result) rethrows -> Result {
		switch self {
		case let .Constant(value): return try action(value)
		case let .Atomic(atomic): return try atomic.withValue(action)
		}
	}
}
