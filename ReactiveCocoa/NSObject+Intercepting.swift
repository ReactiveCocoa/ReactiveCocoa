import Foundation
import ReactiveSwift
import enum Result.NoError
import ReactiveCocoaPrivate

extension NSObject {
	public func trigger(for selector: Selector) -> Signal<(), NoError> {
		return signal(for: selector) { observer in
			return { _ in observer.send(value: ()) }
		}
	}

	private func signal<U>(for selector: Selector, action: (Observer<U, NoError>) -> rac_receiver_t) -> Signal<U, NoError> {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }

		let map: NSMutableDictionary = {
			if let map = objc_getAssociatedObject(self, &mapKey) as? NSMutableDictionary {
				return map
			} else {
				let map = NSMutableDictionary()
				objc_setAssociatedObject(self, &mapKey, map, .OBJC_ASSOCIATION_RETAIN)
				return map
			}
		}()

		let selectorName = String(describing: selector) as NSString
		if let signal = map.object(forKey: selectorName) as? Signal<U, NoError> {
			return signal
		}

		let (signal, observer) = Signal<U, NoError>.pipe()
		let action = action(observer)
		let isSuccessful = RACRegisterBlockForSelector(self, selector, nil, action)
		assert(isSuccessful)

		rac.lifetime.ended.observeCompleted(observer.sendCompleted)
		map.setObject(signal, forKey: selectorName)

		return signal
	}
}

private var mapKey = 0
