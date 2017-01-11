import ReactiveSwift

extension Action {
	@available(*, unavailable, message:"Use the `CocoaAction` initializers instead.")
	public var unsafeCocoaAction: CocoaAction<AnyObject> { fatalError() }
}
