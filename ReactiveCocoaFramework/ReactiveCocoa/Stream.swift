//
//  Stream.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-03.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation
 
operator infix |> { associativity left }

/// Combines a stream-of-streams into a single stream, using the given policy
/// function.
///
/// This allows code like:
///
///		let sss: Stream<Stream<Stream<T>>>
///		let s = concat(flatten(s))
///
/// to instead be written like:
///
///		let s = s |> flatten |> concat
///
///	This isn't a method within the `Stream` class because it's only valid on
///	streams-of-streams.
@infix func |><T>(stream: Stream<Stream<T>>, f: Stream<Stream<T>> -> Stream<T>) -> Stream<T> {
	return f(stream)
}

/// A monadic stream of `Event<T>`.
class Stream<T> {
	/// Creates an empty stream.
	class func empty() -> Stream<T> {
		return Stream()
	}
	
	/// Creates a stream with a single value.
	class func single(T) -> Stream<T> {
		return Stream()
	}

	/// Creates a stream that will generate the given error.
	class func error(error: NSError) -> Stream<T> {
		return Stream()
	}

	/// Creates a stream from the given sequence of values.
	@final class func fromSequence(seq: SequenceOf<T>) -> Stream<T> {
		var s = empty()

		for elem in seq {
			s = s.concat(single(elem))
		}

		return s
	}

	/// Scans over the stream, accumulating a state and mapping each value to
	/// a new stream, then flattens all the resulting streams into one.
	///
	/// This is rarely useful directly—it's just a primitive from which many
	/// convenient stream operators can be derived.
	func flattenScan<S, U>(initial: S, _ f: (S, T) -> (S?, Stream<U>)) -> Stream<U> {
		return .empty()
	}

	/// Concatenates the values in the given stream onto the end of the
	/// receiver.
	func concat(stream: Stream<T>) -> Stream<T> {
		return .empty()
	}

	/// Zips the values of the given stream up with those of the receiver.
	///
	/// The first value of each stream will be combined, then the second value,
	/// and so forth, until at least one of the streams is exhausted.
	func zipWith<U>(stream: Stream<U>) -> Stream<(T, U)> {
		return .empty()
	}

	/// Converts each of the receiver's events (including those outside of the
	/// monad) into an Event value that can be manipulated directly.
	func materialize() -> Stream<Event<T>> {
		return .empty()
	}

	/// Lifts the given function over the values in the stream.
	@final func map<U>(f: T -> U) -> Stream<U> {
		return flattenScan(0) { (_, x) in (0, .single(f(x))) }
	}

	/// Keeps only the values in the stream that match the given predicate.
	@final func filter(pred: T -> Bool) -> Stream<T> {
		return map { x in pred(x) ? .single(x) : .empty() }
			|> flatten
	}

	/// Takes only the first `count` values from the stream.
	///
	/// If `count` is longer than the length of the stream, the entire stream is
	/// returned.
	@final func take(count: Int) -> Stream<T> {
		if (count == 0) {
			return .empty()
		}

		return flattenScan(0) { (n, x) in
			if n < count {
				return (n + 1, .single(x))
			} else {
				return (nil, .empty())
			}
		}
	}

	/// Takes values while the given predicate remains true.
	///
	///
	/// Returns a stream that consists of all values up to (but not including)
	/// the value where the predicate was first false.
	@final func takeWhile(pred: T -> Bool) -> Stream<T> {
		return flattenScan(0) { (_, x) in
			if pred(x) {
				return (0, .single(x))
			} else {
				return (nil, .empty())
			}
		}
	}

	/// Takes only the last `count` values from the stream.
	///
	/// If `count` is longer than the length of the stream, the entire stream is
	/// returned.
	@final func takeLast(count: Int) -> Stream<T> {
		if (count == 0) {
			return .empty()
		}

		return materialize().flattenScan([]) { (vals: T[], event) in
			switch event {
			case let .Next(value):
				var newVals = vals
				newVals.append(value)

				while newVals.count > count {
					newVals.removeAtIndex(0)
				}

				return (newVals, .empty())

			case let .Error(error):
				return (nil, .error(error))

			case let .Completed:
				return (nil, .fromSequence(SequenceOf(vals)))
			}
		}
	}

	/// Skips the first `count` values in the stream.
	///
	/// If `count` is longer than the length of the stream, an empty stream is
	/// returned.
	@final func skip(count: Int) -> Stream<T> {
		return flattenScan(0) { (n, x) in
			if n < count {
				return (n + 1, .empty())
			} else {
				return (count, .single(x))
			}
		}
	}

	/// Skips values while the given predicate remains true.
	///
	/// Returns a stream that consists of all values after (and including) the
	/// value where the predicate was first true.
	@final func skipWhile(pred: T -> Bool) -> Stream<T> {
		return flattenScan(true) { (skipping, x) in
			if skipping && pred(x) {
				return (true, .empty())
			} else {
				return (false, .single(x))
			}
		}
	}

	/// Switch to the produced stream when an error occurs.
	@final func catch(f: NSError -> Stream<T>) -> Stream<T> {
		return materialize().flattenScan(0) { (_, event) in
			switch event {
			case let .Next(value):
				return (0, .single(value))

			case let .Error(error):
				return (nil, f(error))

			case let .Completed:
				return (nil, .empty())
			}
		}
	}

	/// Scans over the stream, accumulating a state and mapping each value to
	/// a new value.
	@final func scan<U>(initial: U, _ f: (U, T) -> U) -> Stream<U> {
		return flattenScan(initial) { (state, value) in
			let newValue = f(state, value)
			return (newValue, .single(newValue))
		}
	}

	/// Like scan(), but returns a stream of one value, which will be the final
	/// accumulated state.
	@final func aggregate<U>(initial: U, _ f: (U, T) -> U) -> Stream<U> {
		let starting: Stream<U> = .single(initial)

		return starting
			.concat(scan(initial, f))
			.takeLast(1)
	}

	/// Combines each previous and current value into a new value.
	@final func combinePrevious<U>(initial: T, f: (T, T) -> U) -> Stream<U> {
		let initialState: (T, U?) = (initial, nil)
		let scanned = scan(initialState) { (state, current) in
			let (previous, _) = state
			let mapped = f(previous, current)
			return (current, mapped)
		}

		return scanned.map { (_, value) in value! }
	}

	/// Ignores all Next events from the receiver.
	@final func ignoreValues() -> Stream<T> {
		return filter { _ in false }
	}
}

/// Flattens a stream-of-streams into a single stream of values.
///
/// The exact manner in which flattening occurs is determined by the
/// stream's implementation of `flattenScan()`.
func flatten<T>(stream: Stream<Stream<T>>) -> Stream<T> {
	return stream.flattenScan(0) { (_, s) in (0, s) }
}

/// Converts a stream of Event values back into a stream of real events.
func dematerialize<T>(stream: Stream<Event<T>>) -> Stream<T> {
	return stream.map { event in
		switch event {
		case let .Next(value):
			return .single(value)

		case let .Error(error):
			return .error(error)

		case let .Completed:
			return .empty()
		}
	} |> flatten
}

/// Ignores all occurrences of a value in the given stream.
func ignore<T: Equatable>(value: T, inStream stream: Stream<T>) -> Stream<T> {
	return stream.filter { $0 != value }
}

/// Deduplicates consecutive appearances of the same value into only the first
/// occurrence.
func nub<T: Equatable>(stream: Stream<T>) -> Stream<T> {
	return stream.flattenScan(nil) { (previous: T?, current) in
		if let p = previous {
			if p == current {
				return (current, .empty())
			}
		}
		
		return (current, .single(current))
	}
}

/// Inverts all boolean values in the stream.
@prefix func !(stream: Stream<Bool>) -> Stream<Bool> {
	return stream.map(!)
}
