//
//  AsyncSequence.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-12.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

// TODO: This lives outside of the definition below because of a crash in the
// compiler. Move it back within AsyncSequence once that's fixed.
struct _FlattenScanGenerator<S, T, U>: Generator {
	let disposable: Disposable
	let scanFunc: (S, T) -> (S?, Stream<U>)
	
	// TODO: Thread safety
	var valueGenerators: GeneratorOf<Promise<Event<U>>>[]
	var state: S
	var selfGenerator: GeneratorOf<Promise<Event<T>>>

	mutating func generateStreamFromValue(x: T) {
		let (newState, stream) = scanFunc(state, x)

		if let s = newState {
			state = s
		} else {
			disposable.dispose()
		}

		let seq = stream as AsyncSequence<U>
		valueGenerators.append(seq.generate())
	}

	mutating func next() -> Promise<Event<U>>? {
		if disposable.disposed {
			return nil
		}

		var next = valueGenerators[0].next()
		while next == nil {
			valueGenerators.removeAtIndex(0)
			if valueGenerators.isEmpty {
				if let promise = selfGenerator.next() {
					return promise.then { event in
						switch event {
						case let .Next(x):
							self.generateStreamFromValue(x)
							return Promise { .Completed }

						case let .Completed:
							return Promise { .Completed }

						case let .Error(error):
							self.disposable.dispose()
							return Promise { .Error(error) }
						}
					}
				} else {
					return nil
				}
			}

			next = valueGenerators[0].next()
		}

		return next
	}
}

/// A consumer-driven (pull-based) stream of values.
class AsyncSequence<T>: Stream<T>, Sequence {
	typealias GeneratorType = GeneratorOf<Promise<Event<T>>>

	let _generate: () -> GeneratorType
	init(_ generate: () -> GeneratorType) {
		self._generate = generate
	}

	/// Instantiates a generator that will instantly return Promise<Event<T>>
	/// objects, representing future events in the stream.
	///
	/// Work will only begin when the generated promises are actually resolved.
	/// Each promise may be evaluated in any order, or even skipped entirely.
	func generate() -> GeneratorType {
		return self._generate()
	}

	/// Injects side effects into the generation of each event.
	func doEvent(action: Event<T> -> ()) -> AsyncSequence<T> {
		return AsyncSequence {
			var selfGenerator = self.generate()

			return GeneratorOf {
				let p = selfGenerator.next()

				return p?.then { event in
					action(event)
					return Promise { event }
				}
			}
		}
	}
	
	override class func empty() -> AsyncSequence<T> {
		return AsyncSequence {
			return GeneratorOf {
				Promise { Event.Completed }
			}
		}
	}

	override class func single(x: T) -> AsyncSequence<T> {
		return AsyncSequence {
			return SequenceOf([
				Promise { Event.Next(Box(x)) },
				Promise { Event.Completed }
			]).generate()
		}
	}

	override class func error(error: NSError) -> AsyncSequence<T> {
		return AsyncSequence {
			return GeneratorOf {
				Promise { Event.Error(error) }
			}
		}
	}

	override func flattenScan<S, U>(initial: S, _ f: (S, T) -> (S?, Stream<U>)) -> AsyncSequence<U> {
		return AsyncSequence<U> {
			let g = _FlattenScanGenerator(disposable: SimpleDisposable(), scanFunc: f, valueGenerators: [], state: initial, selfGenerator: self.generate())
			return GeneratorOf(g)
		}
	}

	override func concat(stream: Stream<T>) -> AsyncSequence<T> {
		return AsyncSequence {
			var selfGenerator = self.generate()
			var streamGenerator = (stream as AsyncSequence<T>).generate()

			return GeneratorOf {
				if let p = selfGenerator.next() {
					return p.then { event in
						switch event {
						case .Completed:
							if let q = streamGenerator.next () {
								return q
							} else {
								// Return the Completed event after all.
								fallthrough
							}

						default:
							return Promise { event }
						}
					}
				} else {
					return streamGenerator.next()
				}
			}
		}
	}

	override func zipWith<U>(stream: Stream<U>) -> AsyncSequence<(T, U)> {
		return AsyncSequence<(T, U)> {
			var selfGenerator = self.generate()
			var streamGenerator = (stream as AsyncSequence<U>).generate()

			return GeneratorOf {
				let a = selfGenerator.next()
				let b = streamGenerator.next()

				if a == nil || b == nil {
					return nil
				}

				return Promise {
					a!.start()
					b!.start()

					switch a!.result() {
					case let .Next(av):
						switch b!.result() {
						case let .Next(bv):
							return .Next(Box(av.value, bv.value))

						case let .Error(error):
							return .Error(error)

						case let .Completed:
							return .Completed
						}

					case let .Error(error):
						return .Error(error)

					case let .Completed:
						return .Completed
					}
				}
			}
		}
	}

	override func materialize() -> AsyncSequence<Event<T>> {
		return AsyncSequence<Event<T>> {
			var generator = self.generate()
			let disposable = SimpleDisposable()

			return GeneratorOf {
				if disposable.disposed {
					return nil
				}

				if let p = generator.next() {
					return p.then { event in
						Promise { .Next(Box(event)) }
					}
				}

				disposable.dispose()
				return Promise { .Completed }
			}
		}
	}
}
