import Foundation
import ReactiveSwift
import enum Result.NoError

/// A target that accepts action messages.
internal final class CocoaTarget: NSObject {
	let observer: Observer<(), NoError>

	init(_ observer: Observer<(), NoError>) {
		self.observer = observer
	}

	@objc func sendNext(_ receiver: Any?) {
		observer.send(value: ())
	}
}
