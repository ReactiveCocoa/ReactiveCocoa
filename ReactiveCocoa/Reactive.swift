/// Describes a class which has been extended for reactivity.
///
/// - note: `ExtendedForReactivity` is only intended for extensions to types
///         that are not owned by the module. Non-conforming types may carry
///         first-party reactive elements.
public protocol ExtendedForReactivity: class {}

extension ExtendedForReactivity {
	/// A proxy which exposes the reactivity of `self`.
	public var rac: Reactivity<Self> {
		return Reactivity(self)
	}
}

extension NSObject: ExtendedForReactivity {}

// A proxy which exposes the reactivity of the Reactant type.
public struct Reactivity<Reactant: ExtendedForReactivity> {
	public let reactant: Reactant

	// Construct a proxy.
	//
	// - parameters:
	//   - reactant: The object to be proxied.
	fileprivate init(_ reactant: Reactant) {
		self.reactant = reactant
	}
}
