import Foundation
import ReactiveSwift

extension Reactivity where Reactant: NSObject {
	/// Creates a binding target which uses the lifetime of `reactant`, and weakly
	/// references `reactant` so that the supplied `action` is triggered only if
	/// `reactant` has not deinitialized.
	///
	/// - important: The binding target is bound to the main queue.
	///
	/// - parameters:
	///   - action: The action to consume values from the bindings.
	///
	/// - returns:
	///   A binding target that holds no strong references to `reactant`.
	internal func bindingTarget<U>(action: @escaping (Reactant, U) -> Void) -> BindingTarget<U> {
		return BindingTarget(on: .main, lifetime: reactant.rac.lifetime) { [weak reactant] value in
			if let reactant = reactant {
				action(reactant, value)
			}
		}
	}
}
