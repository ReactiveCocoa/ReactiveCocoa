import Foundation
import enum Result.NoError

extension NSObject {
	public func valuesForKeyPath(keyPath: String) -> SignalProducer<AnyObject?, NoError> {
		return SignalProducer { observer, disposable in
			let proxy = KeyValueObserver(observing: self,
				keyPath: keyPath,
				options: [.Initial, .New],
				action: observer.sendNext)
			disposable += proxy.disposable

			self.lifetime.ended.observeCompleted(observer.sendCompleted)
		}
	}
}

internal final class KeyValueObserver: NSObject {
	let action: (AnyObject?) -> Void
	unowned(unsafe) let object: NSObject
	var disposable: ActionDisposable?

	/// Establish an observation to `object` for the specified key path.
	///
	/// - important: The observer would automatically terminate when `object`
	///              deinitializes.
	///
	/// - parameters:
	///   - object: The object to be observed.
	///   - keyPath: The key path to be observed.
	///   - options: The options of the observation.
	///   - action: The action to be invoked upon arrival of changes.
	init(observing object: NSObject, keyPath: String, options: NSKeyValueObservingOptions, action: (AnyObject?) -> Void) {
		self.action = action
		self.object = object
		super.init()

		object.addObserver(self,
		                   forKeyPath: keyPath,
		                   options: [.Initial, .New],
		                   context: keyValueObserverKey)

		disposable = ActionDisposable {
			self.object.removeObserver(self, forKeyPath: keyPath, context: keyValueObserverKey)
		}

		object.lifetime.ended.observeCompleted(disposable!.dispose)
	}

	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		if context == keyValueObserverKey {
			action(change![NSKeyValueChangeNewKey])
		}
	}
}

private var keyValueObserverKey = UnsafeMutablePointer<Void>.alloc(1)
