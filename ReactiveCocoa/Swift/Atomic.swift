//
//  Atomic.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// An atomic variable.
internal final class Atomic<Value> {
	private var spinLock = OS_SPINLOCK_INIT
	private var _value: Value
	
	/// Atomically gets or sets the value of the variable.
	var value: Value {
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
	init(_ value: Value) {
		_value = value
	}
	
	private func lock() {
		OSSpinLockLock(&spinLock)
	}
	
	private func unlock() {
		OSSpinLockUnlock(&spinLock)
	}
	
	/// Atomically replaces the contents of the variable.
	///
	/// Returns the old value.
	func swap(newValue: Value) -> Value {
		return modify { _ in newValue }
	}

	/// Atomically modifies the variable.
	///
	/// Returns the old value.
	func modify(@noescape action: Value -> Value) -> Value {
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
	func withValue<U>(@noescape action: Value -> U) -> U {
		lock()
		let result = action(_value)
		unlock()
		
		return result
	}
}


protocol AtomicInteger {
	
	typealias IntegerStorageType // should be Int32 or Int64
	
	func ifEqualTo(value : IntegerStorageType, thenReplaceWith : IntegerStorageType) -> Bool
	func ifEqualToBarrier(value : IntegerStorageType, thenReplaceWith : IntegerStorageType) -> Bool
	
	var value : IntegerStorageType { get }
	
	init(_ value: IntegerStorageType)
	
}

internal final class AtomicInt32 : AtomicInteger {
	
	typealias IntegerStorageType = Int32
	
	var __value : IntegerStorageType
	
	func increment() -> IntegerStorageType {
		return OSAtomicIncrement32(&__value)
	}
	func decrement() -> IntegerStorageType {
		return OSAtomicDecrement32(&__value)
	}
	func incrementBarrier() -> IntegerStorageType {
		return OSAtomicIncrement32Barrier(&__value)
	}
	func decrementBarrier() -> IntegerStorageType {
		return OSAtomicDecrement32Barrier(&__value)
	}
	func add(theAmount: IntegerStorageType) -> IntegerStorageType {
		return OSAtomicAdd32(theAmount,&__value)
	}
	func addBarrier(theAmount: IntegerStorageType) -> IntegerStorageType {
		return OSAtomicAdd32Barrier(theAmount,&__value)
	}
	func ifEqualTo(value : IntegerStorageType, thenReplaceWith : IntegerStorageType) -> Bool {
		return OSAtomicCompareAndSwap32(value,thenReplaceWith,&__value)
	}
	func ifEqualToBarrier(value : IntegerStorageType, thenReplaceWith : IntegerStorageType) -> Bool {
		return OSAtomicCompareAndSwap32Barrier(value,thenReplaceWith,&__value)
	}
	/// Atomically gets or sets the value of the variable.
	var value: IntegerStorageType {
		get {
			OSMemoryBarrier()
			return __value
		}
		set(newValue) {
			self.modify { _ in newValue }
		}
	}
	
   // Initializes the variable with the given initial value.
	init(_ value: Int32) {
		__value = value
	}
}

internal final class AtomicInt64 : AtomicInteger {
	
	typealias IntegerStorageType = Int64
	
	var __value : IntegerStorageType
	
	func increment() -> IntegerStorageType {
		return OSAtomicIncrement64(&__value)
	}
	func decrement() -> IntegerStorageType {
		return OSAtomicDecrement64(&__value)
	}
	func incrementBarrier() -> IntegerStorageType {
		return OSAtomicIncrement64Barrier(&__value)
	}
	func decrementBarrier() -> IntegerStorageType {
		return OSAtomicDecrement64Barrier(&__value)
	}
	func add(theAmount: IntegerStorageType) -> IntegerStorageType {
		return OSAtomicAdd64(theAmount,&__value)
	}
	func addBarrier(theAmount: IntegerStorageType) -> IntegerStorageType {
		return OSAtomicAdd64Barrier(theAmount,&__value)
	}
	func ifEqualTo(value : IntegerStorageType, thenReplaceWith : IntegerStorageType) -> Bool {
		return OSAtomicCompareAndSwap64(value,thenReplaceWith,&__value)
	}
	func ifEqualToBarrier(value : IntegerStorageType, thenReplaceWith : IntegerStorageType) -> Bool {
		return OSAtomicCompareAndSwap64Barrier(value,thenReplaceWith,&__value)
	}
	/// Atomically gets or sets the value of the variable.
	var value: IntegerStorageType {
		get {
			OSMemoryBarrier()
			return __value
		}
		set(newValue) {
			self.modify { _ in newValue }
		}
	}
	
	// Initializes the variable with the given initial value.
	init(_ value: Int64) {
		__value = value
	}
}

extension Int32 {
	init(bool : Bool) {
		self = bool ? 1 : 0
	}
}

extension Bool : IntegerLiteralConvertible  {
	public typealias IntegerLiteralType = Int32
	public init(integerLiteral value: Int32) {
		self = value != 0
	}
}


internal final class AtomicBool : AtomicInteger {
	
	typealias IntegerStorageType = Bool
	
	var __value : Int32
	
	func ifEqualTo(value : IntegerStorageType, thenReplaceWith : IntegerStorageType) -> Bool {
		assert(  {
				let currentValue = self.rawValue
				return ((currentValue == 0) || (currentValue == 1))
			}(), "rawValue isn't 1 or 0, so isEqualTo may fail!")
		return OSAtomicCompareAndSwap32(Int32(bool: value),Int32(bool:thenReplaceWith),&__value)
	}
	func ifEqualToBarrier(value : IntegerStorageType, thenReplaceWith : IntegerStorageType) -> Bool {
		assert(  {
			let currentValue = self.rawValue
			return ((currentValue == 0) || (currentValue == 1))
			}(), "rawValue isn't 1 or 0, so isEqualTo may fail!")
		return OSAtomicCompareAndSwap32Barrier(Int32(bool: value),Int32(bool:thenReplaceWith),&__value)
	}
	
	/// Atomically gets or sets the value of the variable.
	var rawValue: Int32 {
		get {
			OSMemoryBarrier()
			return __value
		}
	}

	
	/// Atomically gets or sets the value of the variable.
	var value: IntegerStorageType {
		get {
			return rawValue != 0
		}
		set(newValue) {
			self.modify { _ in newValue }
		}
	}
	
	// Initializes the variable with the given initial value.
	init(_ value: Bool) {
		__value = Int32(bool: value)
	}
}



extension AtomicInteger where IntegerStorageType : IntegerLiteralConvertible {

	/// Atomically replaces the contents of the variable.
	///
	/// Returns the old value.
	func swap(newValue: IntegerStorageType) -> IntegerStorageType {
		return modify { _ in newValue }
	}
	
	func modifyTry(@noescape action: IntegerStorageType -> IntegerStorageType) -> (Bool,IntegerStorageType) {
		let currentValue = self.value
		let newValue = action(currentValue)
		let success = ifEqualTo(currentValue, thenReplaceWith: newValue)
		return (success,currentValue)
	}

	/// Atomically modifies the variable.
	///
	/// Returns the old value.
	func modify(@noescape action: IntegerStorageType -> IntegerStorageType) -> IntegerStorageType {
		
		var done = false
		var currentValue : IntegerStorageType = 0
		while !done {
			(done,currentValue) = modifyTry(action)
		}
		return currentValue
	}
	
	

}
