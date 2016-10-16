import ReactiveSwift
import enum Result.NoError

public protocol Reusable: class {
	func prepareForReuse()
}

extension Reactive where Base: NSObject, Base: Reusable {
	public var prepareForReuse: Signal<(), NoError> {
		return trigger(for: Selector(("prepareForReuse")))
	}
}
