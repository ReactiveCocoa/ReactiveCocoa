import ReactiveSwift
import enum Result.NoError
#if os(iOS)
import UIKit
#endif

#if os(iOS)
extension Reactive where Base: UISwitch {
	@available(*, unavailable, message:"Use `<~>` on `isOn` instead. For example: `action <~> acceptanceSwitch.reactive.isOn`")
	public var toggled: Any { fatalError() }
}

extension Reactive where Base: UIRefreshControl {
	@available(*, unavailable, message:"Use `<~>` on `isRefreshing` instead. For example: `action <~> refreshControl.reactive.isRefreshing`")
	public var toggled: Any { fatalError() }
}
#endif

extension Action {
	@available(*, unavailable, message:"Use the `CocoaAction` initializers instead.")
	public var unsafeCocoaAction: CocoaAction<AnyObject> { fatalError() }
}

extension Reactive where Base: NSObject {
	@available(*, deprecated, renamed: "producer(forKeyPath:)")
	public func values(forKeyPath keyPath: String) -> SignalProducer<Any?, NoError> {
		return producer(forKeyPath: keyPath)
	}
}
