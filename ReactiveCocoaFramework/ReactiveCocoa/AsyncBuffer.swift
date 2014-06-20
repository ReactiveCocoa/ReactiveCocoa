//
//  AsyncBuffer.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

@final class AsyncBuffer<T>: AsyncSequence<T> {
	let _condition = NSCondition()
	var _events: Event<T>[] = []
	
	init() {
		_condition.name = "com.github.RxSwift.Observable.AsyncBuffer"
		super.init(_generate)
	}

	func _generate () -> GeneratorOf<Promise<Event<T>>> {
		var index = 0
		let disposable = SimpleDisposable()
	
		return GeneratorOf {
			if (disposable.disposed) {
				return nil
			}
		
			return Promise {
				let e: Event<T> = withLock(self._condition) {
					while self._events.count < index {
						self._condition.wait()
					}
					
					return self._events[index++]
				}
				
				if e.isTerminating {
					disposable.dispose()
				}
				
				return e
			}
		}
	}
	
	func send(event: Event<T>) {
		withLock(_condition) { () -> () in
			self._events.append(event)
			self._condition.broadcast()
		}
	}
}
