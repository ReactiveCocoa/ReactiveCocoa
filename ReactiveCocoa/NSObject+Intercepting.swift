import Foundation
import ReactiveSwift
import enum Result.NoError
import ReactiveCocoaPrivate

extension NSObject {
	public func signal(for selector: Selector) -> Signal<(), NoError> {
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
		if let signal = map.object(forKey: selectorName) as? Signal<(), NoError> {
			return signal
		}

		let (signal, observer) = Signal<(), NoError>.pipe()

		let isSuccessful = RACRegisterBlockForSelector(self, selector, nil, {
			observer.send(value: ())
		})
		assert(isSuccessful)

		rac_lifetime.ended.observeCompleted(observer.sendCompleted)
		map.setObject(signal, forKey: selectorName)

		return signal
	}
}

private var mapKey = 0
