//
//  NSLockingExtensions.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Acquires the lock, performs the given action, then releases the lock.
func withLock<L: NSLocking, T>(lock: L, action: () -> T) -> T {
	lock.lock()
	let result = action()
	lock.unlock()
	
	return result
}
