//
//  EventBuffer.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-06-26.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

/// A buffer for Events that can be treated as a Sink or a Producer.
public final class EventBuffer<T>: Sink {
	typealias Element = Event<T>

	private let _capacity: Int?

	private let _queue = dispatch_queue_create("com.github.ReactiveCocoa.EventBuffer", DISPATCH_QUEUE_SERIAL)
	private var _consumers = Bag<Consumer<T>>()
	private var _eventBuffer: [Event<T>] = []
	private var _terminated = false

	public var producer: Producer<T> {
		return Producer { consumer in
			var token: Bag.RemovalToken? = nil

			dispatch_barrier_sync(self._queue) {
				token = self._consumers.insert(consumer)

				for event in self._eventBuffer {
					consumer.put(event)
				}
			}

			consumer.disposable.addDisposable {
				dispatch_barrier_async(self._queue) {
					self._consumers.removeValueForToken(token!)
				}
			}
		}
	}

	/// Creates a buffer for events up to the given maximum capacity.
	///
	/// If more than `capacity` values are received, the earliest values will be
	/// dropped and will no longer be given to consumers in the future.
	public init(capacity: Int? = nil) {
		assert(capacity == nil || capacity! > 0)
		_capacity = capacity
	}

	/// Stores the given event in the buffer, evicting the earliest event if the
	/// buffer would be over capacity, then forwards it to all waiting
	/// consumers.
	///
	/// If a terminating event is put into the buffer, it will stop accepting
	/// any further events (to obey the contract of Producer).
	public func put(event: Event<T>) {
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

			for consumer in self._consumers {
				consumer.put(event)
			}
		}
	}

	public func __conversion() -> Producer<T> {
		return producer
	}
}
