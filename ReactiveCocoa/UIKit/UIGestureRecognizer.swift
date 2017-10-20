import ReactiveSwift
import UIKit
import enum Result.NoError

extension Reactive where Base: UIGestureRecognizer {
	/// Create a signal which sends a `next` event for each gesture event
	///
	/// - returns: A trigger signal.
	public var stateChanged: Signal<Base, NoError> {
		return Signal { observer, signalLifetime in
			let receiver = CocoaTarget<Base>(observer) { gestureRecognizer in
				return gestureRecognizer as! Base
			}
			base.addTarget(receiver, action: #selector(receiver.invoke))
			
			let disposable = lifetime.ended.observeCompleted(observer.sendCompleted)
			
			signalLifetime.observeEnded { [weak base] in
				disposable?.dispose()
				base?.removeTarget(receiver, action: #selector(receiver.invoke))
			}
		}
	}
}
