//
//  ObservableProperty.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2014-10-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

public final class ObservableProperty<T>: SinkType {
	typealias Element = T

	private let queue = dispatch_queue_create("com.github.ReactiveCocoa.ObservableProperty", DISPATCH_QUEUE_SERIAL)
	private var sinks = Bag<SinkOf<Event<T>>>()

	public var value: T {
		didSet(value) {
			dispatch_sync(queue) {
				for sink in self.sinks {
					sink.put(.Next(Box(value)))
				}
			}
		}
	}

	public lazy var changes: HotSignal<T> = {
		let (signal, sink) = HotSignal.pipe()
		let eventSink = SinkOf<Event<T>> { event in
			switch (event) {
			case .Next(value):
				sink.put(value.unbox)
			}
		}

		dispatch_sync(queue) {
			self.sinks.append(eventSink)
		}
	}()

	init(_ value: T) {
		self.value = value
	}

	deinit {
		dispatch_sync(queue) {
			for sink in self.sinks {
				sink.put(.Completed)
			}
		}
	}

	public func values() -> ColdSignal<T> {
		return ColdSignal { subscriber in
			var token: Bag.RemovalToken?

			dispatch_sync(queue) {
				token = self.sinks.insert(SinkOf(subscriber))
			}

			return ActionDisposable {
				self.sinks.removeValueForToken(token)
			}
		}
	}
}
