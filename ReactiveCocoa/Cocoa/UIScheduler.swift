//
//  UIScheduler.swift
//  ReactiveCocoa
//
//  Created by Eimantas Vaiciunas on 12/06/16.
//  Copyright © 2016 GitHub. All rights reserved.
//

import Foundation
import ReactiveSwift

/// A scheduler that performs all work on the main queue, as soon as possible.
///
/// If the caller is already running on the main queue when an action is
/// scheduled, it may be run synchronously. However, ordering between actions
/// will always be preserved.
public final class UIScheduler: SchedulerType {
	private static var dispatchOnceToken: dispatch_once_t = 0
	private static var dispatchSpecificKey: UInt8 = 0
	private static var dispatchSpecificContext: UInt8 = 0
	
	private var queueLength: Int32 = 0
	
	public init() {
		dispatch_once(&UIScheduler.dispatchOnceToken) {
			dispatch_queue_set_specific(
				dispatch_get_main_queue(),
				&UIScheduler.dispatchSpecificKey,
				&UIScheduler.dispatchSpecificContext,
				nil
			)
		}
	}
	
	public func schedule(action: () -> Void) -> Disposable? {
		let disposable = SimpleDisposable()
		let actionAndDecrement = {
			if !disposable.disposed {
				action()
			}
			
			OSAtomicDecrement32(&self.queueLength)
		}
		
		let queued = OSAtomicIncrement32(&queueLength)
		
		// If we're already running on the main queue, and there isn't work
		// already enqueued, we can skip scheduling and just execute directly.
		if queued == 1 && dispatch_get_specific(&UIScheduler.dispatchSpecificKey) == &UIScheduler.dispatchSpecificContext {
			actionAndDecrement()
		} else {
			dispatch_async(dispatch_get_main_queue(), actionAndDecrement)
		}
		
		return disposable
	}
}
