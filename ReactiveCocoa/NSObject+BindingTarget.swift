import Foundation
import ReactiveSwift

extension Reactive where Base: NSObject {
	/// Creates a binding target which uses the lifetime of the object, and weakly
	/// references the object so that the supplied `action` is triggered only if
	/// the object has not deinitialized.
	///
	/// - important: The binding target is bound to the main queue.
	///
	/// - parameters:
	///   - action: The action to consume values from the bindings.
	///
	/// - returns:
	///   A binding target that holds no strong references to the object.
	internal func makeBindingTarget<U>(_ key: StaticString = #function, action: @escaping (Base, U) -> Void) -> BindingTarget<U> {
		return BindingTarget(on: UIScheduler(), lifetime: lifetime) { [weak base = self.base] value in
			if let base = base {
				action(base, value)
			}
		}
	}
}
