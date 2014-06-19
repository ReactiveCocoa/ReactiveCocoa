//
//  SpinLock.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// An abstraction over spin locks.
@final class SpinLock {
	var _spinlock = OS_SPINLOCK_INIT
	
	/// Locks the spin lock.
	func lock() {
		withUnsafePointer(&_spinlock, OSSpinLockLock)
	}
	
	/// Unlocks the spin lock.
	func unlock() {
		withUnsafePointer(&_spinlock, OSSpinLockUnlock)
	}
	
	/// Acquires the spin lock, performs the given action, then releases the
	/// lock.
	func withLock<T>(action: () -> T) -> T {
		withUnsafePointer(&_spinlock, OSSpinLockLock)
		let result = action()
		withUnsafePointer(&_spinlock, OSSpinLockUnlock)
		
		return result
	}
	
	/// Tries to acquire the spin lock, performing the given action if it's
	/// available, or else aborting immediately without running the action.
	func tryLock<T>(action: () -> T) -> T? {
		if !withUnsafePointer(&_spinlock, OSSpinLockTry) {
			return nil
		}
		
		let result = action()
		withUnsafePointer(&_spinlock, OSSpinLockUnlock)
		
		return result
	}
}
