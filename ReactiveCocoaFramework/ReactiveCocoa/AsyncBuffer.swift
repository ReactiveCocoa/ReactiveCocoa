//
//  AsyncBuffer.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-13.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

class AsyncBuffer<T>: AsyncSequence<T> {
	let condition = NSCondition()
	var events: Event<T>[] = []
	
	init() {
		self.condition.name = "com.github.RxSwift.Observable.AsyncBuffer"
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
				let e: Event<T> = withLock(self.condition) {
					while self.events.count < index {
						self.condition.wait()
					}
					
					return self.events[index++]
				}
				
				if e.isTerminating {
					disposable.dispose()
				}
				
				return e
			}
		}
	}
	
	func send(event: Event<T>) {
		withLock(self.condition) { () -> () in
			self.events.append(event)
			self.condition.broadcast()
		}
	}
}
