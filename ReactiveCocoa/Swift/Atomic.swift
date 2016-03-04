import Foundation

/// An atomic variable.
public final class Atomic<Value> {
    
	/// Spin lock allowing the value stored to only be accessed/modified atomically.
	///
	/// Spin locks are suitable in situations where contention is expected to be low.
	/// The spinlock operations use memory barriers to synchronize access to access to
	/// shared memory protected by the lock.
	private var spinLock = OS_SPINLOCK_INIT
    
	/// The value being stored.
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
	/// - parameter value: Value to be saved by the initialized atomical storage.
	public init(_ value: Value) {
		_value = value
	}
	
	/// Try to held the lock of this atomic variable. If the lock is already held the
	/// thread will wait in a loop ("spin") while repeatedly checking if the lock is
	/// available.
	private func lock() {
		OSSpinLockLock(&spinLock)
	}
	
	/// The running thread will realase the hold on this atomic variable lock.
	private func unlock() {
		OSSpinLockUnlock(&spinLock)
	}
	
	/// Atomically replaces the contents of the stored variable.
	/// - parameter newValue: Value to be stored.
	/// - returns: The value previously stored.
	public func swap(newValue: Value) -> Value {
		return modify { _ in newValue }
	}

	/// Atomically modifies the variable through a clousure having as parameter the value.
	/// previously stored and returning the value to be stored.
	/// - parameter action: Clousure returning the value to be stored.
	/// - returns: The previously stored value.
	public func modify(@noescape action: (Value) throws -> Value) rethrows -> Value {
		lock()
		defer { unlock() }

		let oldValue = _value
		_value = try action(_value)
		return oldValue
	}
	
	/// Atomically performs an arbitrary action using the current value of the variable.
	/// - parameter action: Clouse performing atomically a determinate action with the
	/// current value of the atomic storage.
	/// - returns: The result of the action.
	public func withValue<Result>(@noescape action: (Value) throws -> Result) rethrows -> Result {
		lock()
		defer { unlock() }

		return try action(_value)
	}
}
