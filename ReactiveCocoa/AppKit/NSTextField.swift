import ReactiveSwift
import AppKit
import enum Result.NoError

extension Reactive where Base: NSTextField {
	/// A signal of values in `String` from the text field upon any changes.
	public var continuousStringValues: Signal<String, NoError> {
		var signal: Signal<String, NoError>!

		NotificationCenter.default
			.reactive
			.notifications(forName: .NSControlTextDidChange, object: base)
			.take(during: lifetime)
			.map { ($0.object as! NSTextField).stringValue }
			.startWithSignal { innerSignal, _ in signal = innerSignal }

		return signal
	}
}
