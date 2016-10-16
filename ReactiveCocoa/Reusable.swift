import ReactiveSwift
import enum Result.NoError

public protocol Reusable: class {}

extension Reactive where Base: NSObject, Base: Reusable {
	public var prepareForReuse: Signal<(), NoError> {
		return trigger(for: Selector(("prepareForReuse")))
	}
}
