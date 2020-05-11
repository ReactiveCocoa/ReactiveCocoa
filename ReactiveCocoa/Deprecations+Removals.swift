import Foundation
import ReactiveSwift

extension Action {
	@available(*, unavailable, message:"Use the `CocoaAction` initializers instead.")
	public var unsafeCocoaAction: CocoaAction<AnyObject> { fatalError() }
}

extension Reactive where Base: NSObject {
	@available(*, deprecated, renamed: "producer(forKeyPath:)")
	public func values(forKeyPath keyPath: String) -> SignalProducer<Any?, Never> {
		return producer(forKeyPath: keyPath)
	}
}

#if os(watchOS)
import WatchKit
extension Reactive where Base: WKInterfaceButton {
	@available(*, unavailable, renamed: "title")
	public var text: BindingTarget<String?> {
		fatalError()
	}
}
#endif
