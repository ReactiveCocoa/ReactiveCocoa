//
//  Observable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

// TODO: These live outside of the definition below because of an infinite loop
// in the compiler. Move them back within Observable once that's fixed.
struct _ZipState<T> {
	var values: T[] = []
	var completed = false

	init() {
	}

	init(_ values: T[], _ completed: Bool) {
		self.values = values
		self.completed = completed
	}
}

struct _CombineState<T> {
	var latestValue: T? = nil
	var completed = false

	init() {
	}

	init(_ value: T?, _ completed: Bool) {
		self.latestValue = value
		self.completed = completed
	}
}

/// A producer-driven (push-based) stream of values.
class Observable<T>: Stream<T> {
	/// The type of a consumer for the stream's events.
	typealias Observer = Event<T> -> ()
	
	let _observe: Observer -> Disposable?
	init(_ observe: Observer -> Disposable?) {
		self._observe = observe
	}
	
	let _observerQueue = dispatch_queue_create("com.github.RxSwift.Observable", DISPATCH_QUEUE_SERIAL)
	var _observers: Box<Observer>[] = []
 
	/// Observes the stream for new events.
	///
	/// Returns a disposable which can be used to cease observation.
	func observe(observer: Observer) -> Disposable {
		let box = Box(observer)
	
		dispatch_sync(_observerQueue, {
			self._observers.append(box)
		})
		
		self._observe(box.value)
		
		return ActionDisposable {
			dispatch_sync(self._observerQueue, {
				self._observers = removeObjectIdenticalTo(box, fromArray: self._observers)
			})
		}
	}

	/// Buffers all new events into a sequence which can be enumerated
	/// on-demand.
	///
	/// Returns the buffered sequence, and a disposable which can be used to
	/// stop buffering further events.
	func replay() -> (AsyncSequence<T>, Disposable) {
		let buf = AsyncBuffer<T>()
		return (buf, self.observe(buf.send))
	}

	/// Takes events from the receiver until `trigger` sends a Next or Completed
	/// event.
	func takeUntil<U>(trigger: Observable<U>) -> Observable<T> {
		return Observable { send in
			let triggerDisposable = trigger.observe { event in
				switch event {
				case let .Error:
					// Do nothing.
					break

				default:
					send(.Completed)
				}
			}

			return CompositeDisposable([triggerDisposable, self.observe(send)])
		}
	}

	/// Sends the latest value from the receiver only when `sampler` sends
	/// a value.
	///
	/// The returned observable could repeat values if `sampler` fires more
	/// often than the receiver. Values from `sampler` are ignored before the
	/// receiver sends its first value.
	func sample<U>(sampler: Observable<U>) -> Observable<T> {
		return Observable { send in
			let latest: Atomic<T?> = Atomic(nil)

			let selfDisposable = self.observe { event in
				switch event {
				case let .Next(value):
					latest.value = value

				default:
					send(event)
				}
			}

			let samplerDisposable = sampler.observe { event in
				switch event {
				case let .Next:
					if let v = latest.value {
						send(.Next(Box(v)))
					}

				default:
					break
				}
			}

			return CompositeDisposable([selfDisposable, samplerDisposable])
		}
	}

	/// Delays the delivery of Next and Completed events by the given interval,
	/// on the given scheduler.
	///
	/// Error events are always forwarded immediately.
	func delay(interval: NSTimeInterval, onScheduler scheduler: Scheduler) -> Observable<T> {
		return Observable { send in
			return self.observe { event in
				switch event {
				case let .Error:
					send(event)

				default:
					scheduler.scheduleAfter(NSDate(timeIntervalSinceNow: interval)) {
						send(event)
					}
				}
			}
		}
	}

	/// Delivers all events onto the given scheduler.
	func deliverOn(scheduler: Scheduler) -> Observable<T> {
		return Observable { send in
			return self.observe { event in
				scheduler.schedule { send(event) }
				return ()
			}
		}
	}

	/// Creates an Observable which will send the latest value from both input
	/// Observables, whenever either of them fire.
	func combineLatestWith<U>(other: Observable<U>) -> Observable<(T, U)> {
		return Observable<(T, U)> { send in
			let states = Atomic((_CombineState<T>(), _CombineState<U>()))

			func completeIfNecessary() {
				states.withValue { (a, b) -> () in
					if a.completed && b.completed {
						send(.Completed)
					}
				}
			}

			let selfDisposable = self.observe { event in
				switch event {
				case let .Next(value):
					states.modify { (_, b) in
						let av = value
						if let bv = b.latestValue {
							let v: (T, U) = (av, bv)
							send(.Next(Box(v)))
						}

						return (_CombineState(av, false), b)
					}

				case let .Error(error):
					send(.Error(error))

				case let .Completed:
					states.modify { (a, b) in (_CombineState(a.latestValue, true), b) }
					completeIfNecessary()
				}
			}

			let otherDisposable = other.observe { event in
				switch event {
				case let .Next(value):
					states.modify { (a, _) in
						let bv = value
						if let av = a.latestValue {
							let v: (T, U) = (av, bv)
							send(.Next(Box(v)))
						}

						return (a, _CombineState(bv, false))
					}

				case let .Error(error):
					send(.Error(error))

				case let .Completed:
					states.modify { (a, b) in (a, _CombineState(b.latestValue, true)) }
					completeIfNecessary()
				}
			}

			return CompositeDisposable([selfDisposable, otherDisposable])
		}
	}
	
	/// Creates an Observable which will repeatedly send the current date at the
	/// given interval, on the given scheduler, starting from the time of observation.
	class func interval(interval: NSTimeInterval, onScheduler scheduler: RepeatableScheduler, withLeeway leeway: NSTimeInterval = 0) -> Observable<NSDate> {
		return Observable<NSDate> { send in
			return scheduler.scheduleAfter(NSDate(timeIntervalSinceNow: interval), repeatingEvery: interval, withLeeway: leeway) {
				let now = Box(NSDate())
				send(.Next(now))
			}
		}
	}
	
	override class func empty() -> Observable<T> {
		return Observable { send in
			send(.Completed)
			return nil
		}
	}
	
	override class func single(x: T) -> Observable<T> {
		return Observable { send in
			send(.Next(Box(x)))
			send(.Completed)
			return nil
		}
	}

	override class func error(error: NSError) -> Observable<T> {
		return Observable { send in
			send(.Error(error))
			return nil
		}
	}

	override func flattenScan<S, U>(initial: S, _ f: (S, T) -> (S?, Stream<U>)) -> Observable<U> {
		return Observable<U> { send in
			let disposable = CompositeDisposable()
			let inFlight = Atomic(1)

			// TODO: Thread safety
			var state = initial

			func decrementInFlight() {
				let orig = inFlight.modify { $0 - 1 }
				if orig == 1 {
					send(.Completed)
				}
			}

			let selfDisposable = SerialDisposable()
			disposable.addDisposable(selfDisposable)

			selfDisposable.innerDisposable = self.observe { event in
				switch event {
				case let .Next(value):
					let (newState, stream) = f(state, value)

					if let s = newState {
						state = s
					} else {
						selfDisposable.dispose()
					}

					let streamDisposable = SerialDisposable()
					disposable.addDisposable(streamDisposable)

					streamDisposable.innerDisposable = (stream as Observable<U>).observe { event in
						if event.isTerminating {
							disposable.removeDisposable(streamDisposable)
						}

						switch event {
						case let .Completed:
							decrementInFlight()

						default:
							send(event)
						}
					}

					break

				case let .Error(error):
					send(.Error(error))

				case let .Completed:
					decrementInFlight()
				}
			}

			return disposable
		}
	}

	override func concat(stream: Stream<T>) -> Observable<T> {
		return Observable { send in
			let disposable = SerialDisposable()

			disposable.innerDisposable = self.observe { event in
				switch event {
				case let .Completed:
					disposable.innerDisposable = (stream as Observable<T>).observe(send)

				default:
					send(event)
				}
			}

			return disposable
		}
	}

	override func zipWith<U>(stream: Stream<U>) -> Observable<(T, U)> {
		return Observable<(T, U)> { send in
			let states = Atomic((_ZipState<T>(), _ZipState<U>()))

			func drain() {
				states.modify { (a, b) in
					var av = a.values
					var bv = b.values

					while !av.isEmpty && !bv.isEmpty {
						let v = (av[0], bv[0])
						av.removeAtIndex(0)
						bv.removeAtIndex(0)

						send(.Next(Box(v)))
					}

					if a.completed || b.completed {
						send(.Completed)
					}

					return (_ZipState(av, a.completed), _ZipState(bv, b.completed))
				}
			}

			func modifyA(f: _ZipState<T> -> _ZipState<T>) {
				states.modify { (a, b) in (f(a), b) }
				drain()
			}

			func modifyB(f: _ZipState<U> -> _ZipState<U>) {
				states.modify { (a, b) in (a, f(b)) }
				drain()
			}

			let selfDisposable = self.observe { event in
				switch event {
				case let .Next(value):
					modifyA { s in
						var values = s.values
						values.append(value)

						return _ZipState(values, false)
					}

				case let .Error(error):
					send(.Error(error))

				case let .Completed:
					modifyA { s in _ZipState(s.values, true) }
				}
			}

			let otherDisposable = (stream as Observable<U>).observe { event in
				switch event {
				case let .Next(value):
					modifyB { s in
						var values = s.values
						values.append(value)

						return _ZipState(values, false)
					}

				case let .Error(error):
					send(.Error(error))

				case let .Completed:
					modifyB { s in _ZipState(s.values, true) }
				}
			}

			return CompositeDisposable([selfDisposable, otherDisposable])
		}
	}

	override func materialize() -> Observable<Event<T>> {
		return Observable<Event<T>> { send in
			return self.observe { event in
				send(.Next(Box(event)))

				if event.isTerminating {
					send(.Completed)
				}
			}
		}
	}
}
