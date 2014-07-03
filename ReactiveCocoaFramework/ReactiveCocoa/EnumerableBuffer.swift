//
//  EnumerableBuffer.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-26.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// A controllable Enumerable that functions as a combination push- and
/// pull-driven stream.
@final class EnumerableBuffer<T>: Enumerable<T>, Sink {
	typealias Element = Event<T>

	let _capacity: Int?

	let _queue = dispatch_queue_create("com.github.ReactiveCocoa.EnumerableBuffer", DISPATCH_QUEUE_SERIAL)
	var _enumerators: Enumerator<T>[] = []
	var _eventBuffer: Event<T>[] = []
	var _terminated = false

	/// Creates a buffer for events up to the given maximum capacity.
	///
	/// If more than `capacity` values are received, the earliest values will be
	/// dropped and won't be enumerated over in the future.
	init(capacity: Int? = nil) {
		assert(capacity == nil || capacity! > 0)
		_capacity = capacity

		super.init(enumerate: { enumerator in
			dispatch_barrier_sync(self._queue) {
				self._enumerators.append(enumerator)

				for event in self._eventBuffer {
					enumerator.put(event)
				}
			}

			enumerator.disposable.addDisposable {
				dispatch_barrier_async(self._queue) {
					self._enumerators = removeObjectIdenticalTo(enumerator, fromArray: self._enumerators)
				}
			}
		})
	}

	/// Stores the given event in the buffer, evicting the earliest event if the
	/// buffer would be over capacity, then forwards it to all waiting
	/// enumerators.
	///
	/// If a terminating event is put into the buffer, it will stop accepting
	/// any further events (to obey the contract of Enumerable).
	func put(event: Event<T>) {
		dispatch_barrier_sync(_queue) {
			if (self._terminated) {
				return
			}

			self._eventBuffer.append(event)
			if let capacity = self._capacity {
				while self._eventBuffer.count > capacity {
					self._eventBuffer.removeAtIndex(0)
				}
			}

			self._terminated = event.isTerminating

			for enumerator in self._enumerators {
				enumerator.put(event)
			}
		}
	}
}
