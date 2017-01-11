import ReactiveSwift
import enum Result.NoError
import AppKit

extension Reactive where Base: NSButton {

	public var pressed: Signal<Base, NoError> {
		return trigger.map { [unowned base = self.base] in base }
	}

}
