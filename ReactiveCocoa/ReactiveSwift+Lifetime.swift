import ReactiveSwift

extension Signal {
	/// Forward events from `self` until `object` deinitializes, at which point the
	/// returned signal will complete.
	///
	/// - parameters:
	///   - object: An object of which the deinitialization would complete the returned
	///             `Signal`. Both Objective-C and native Swift objects are supported.
	///
	/// - returns: A signal that will deliver events until `object` deinitializes.
	public func take(duringLifetimeOf object: AnyObject) -> Signal<Value, Error> {
		return take(during: lifetime(of: object))
	}
}

extension SignalProducer {
	/// Forward events from `self` until `object` deinitializes, at which point the
	/// returned producer will complete.
	///
	/// - parameters:
	///   - object: An object of which the deinitialization would complete the returned
	///             `Signal`. Both Objective-C and native Swift objects are supported.
	///
	/// - returns: A producer that will deliver events until `object` deinitializes.
	public func take(duringLifetimeOf object: AnyObject) -> SignalProducer<Value, Error> {
		return lift { $0.take(duringLifetimeOf: object) }
	}
}
