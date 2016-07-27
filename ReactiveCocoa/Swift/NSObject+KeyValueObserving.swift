import Foundation
import enum Result.NoError

extension NSObject {
	public func valuesForKeyPath(keyPath: String) -> SignalProducer<AnyObject?, NoError> {
		return SignalProducer { observer, disposable in
			let processNewValue: ([String: AnyObject?]) -> Void = {
				observer.sendNext($0[NSKeyValueChangeNewKey]!)
			}

			disposable += KeyValueObserver.observe(self,
			                                       keyPath: keyPath,
			                                       options: [.Initial, .New],
			                                       action: processNewValue)

			self.lifetime.ended.observeCompleted(observer.sendCompleted)
		}
	}
}

internal final class KeyValueObserver: NSObject {
	/// Establish an observation to `object` for the specified key path.
	///
	/// - warning: The observation would not be automatically removed when
	///            `object` deinitializes. You must manually dispose of the
	///            returned disposable before `object` completes its
	///            deinitialization.
	///
	/// - parameters:
	///   - object: The object to be observed.
	///   - keyPath: The key path to be observed.
	///   - options: The options of the observation.
	///   - action: The action to be invoked upon arrival of changes.
	///
	/// - return:
	///   A disposable that would tear down the observation upon disposal.
	static func observe(object: NSObject, keyPath: String, options: NSKeyValueObservingOptions, action: ([String: AnyObject?]) -> Void) -> Disposable {
		let observer = KeyValueObserver(action: action)

		object.addObserver(observer,
		                   forKeyPath: keyPath,
		                   options: [.Initial, .New],
		                   context: keyValueObserverKey)

		unowned(unsafe) let unsafeObject = object
		return ActionDisposable {
			unsafeObject.removeObserver(observer, forKeyPath: keyPath, context: keyValueObserverKey)
		}
	}

	// MARK: Instance properties and methods

	let action: ([String: AnyObject?]) -> Void

	private init(action: ([String: AnyObject?]) -> Void) {
		self.action = action
	}

	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		if context == keyValueObserverKey {
			action(change!)
		}
	}
}

private var keyValueObserverKey = UnsafeMutablePointer<Void>.alloc(1)
