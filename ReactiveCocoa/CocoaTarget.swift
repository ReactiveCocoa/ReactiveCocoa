import Foundation
import ReactiveSwift
import enum Result.NoError

/// A target that accepts action messages.
internal final class CocoaTarget<Value>: NSObject {
	private enum State {
		case idle
		case sending(queue: [Value])
	}

	private let observer: Signal<Value, NoError>.Observer
	private let transform: (Any?) -> Value

	private var state: State

	internal init(_ observer: Signal<Value, NoError>.Observer, transform: @escaping (Any?) -> Value) {
		self.observer = observer
		self.transform = transform
		self.state = .idle
	}

	/// Broadcast the action message to all observers.
	///
	/// Reentrancy is supported, and the action message would be deferred until the
	/// delivery of the current message has completed.
	///
	/// - note: It should only be invoked on the main queue.
	///
	/// - parameters:
	///   - sender: The object which sends the action message.
	@objc internal func invoke(_ sender: Any?) {
		switch state {
		case .idle:
			state = .sending(queue: [])
			observer.send(value: transform(sender))

			while case let .sending(values) = state {
				guard !values.isEmpty else {
					break
				}

				state = .sending(queue: Array(values.dropFirst()))
				observer.send(value: values[0])
			}

			state = .idle

		case let .sending(values):
			state = .sending(queue: values + [transform(sender)])
		}
	}
}

extension CocoaTarget where Value == Void {
	internal convenience init(_ observer: Signal<(), NoError>.Observer) {
		self.init(observer, transform: { _ in })
	}
}
