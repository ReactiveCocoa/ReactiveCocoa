import ReactiveSwift
import enum Result.NoError

internal class DelegateProxy<Delegate: NSObjectProtocol>: NSObject {
	internal weak var forwardee: Delegate? {
		didSet {
			originalSetter(self)
		}
	}

	internal var interceptedSelectors: Set<Selector> = []

	private let lifetime: Lifetime
	private let originalSetter: (AnyObject) -> Void

	required init(lifetime: Lifetime, _ originalSetter: @escaping (AnyObject) -> Void) {
		self.lifetime = lifetime
		self.originalSetter = originalSetter
	}

	override func forwardingTarget(for selector: Selector!) -> Any? {
		return interceptedSelectors.contains(selector) ? nil : forwardee
	}

	func intercept(_ selector: Selector) -> Signal<(), NoError> {
		interceptedSelectors.insert(selector)
		originalSetter(self)
		return self.reactive.trigger(for: selector).take(during: lifetime)
	}

	func intercept(_ selector: Selector) -> Signal<[Any?], NoError> {
		interceptedSelectors.insert(selector)
		originalSetter(self)
		return self.reactive.signal(for: selector).take(during: lifetime)
	}

	override func responds(to selector: Selector!) -> Bool {
		if interceptedSelectors.contains(selector) {
			return true
		}

		return (forwardee?.responds(to: selector) ?? false) || super.responds(to: selector)
	}
}

private let hasSwizzledKey = AssociationKey<Bool>(default: false)
private let proxyMapKey = AssociationKey<[(Selector, AnyObject)]>(default: [])

extension DelegateProxy {
	// FIXME: This is a workaround to a compiler issue, where any use of `Self`
	//        through a protocol would result in the following error messages:
	//        1. PHI node operands are not the same type as the result!
	//        2. LLVM ERROR: Broken function found, compilation aborted!
	internal static func proxy<P: DelegateProxy<Delegate>>(
		for instance: NSObject,
		setter: Selector,
		getter: Selector
	) -> P {
		return _proxy(for: instance, setter: setter, getter: getter) as! P
	}

	private static func _proxy(
		for instance: NSObject,
		setter: Selector,
		getter: Selector
	) -> AnyObject {
		return instance.synchronized {
			let proxyMap = instance.associations.value(forKey: proxyMapKey)

			if let proxy = proxyMap.first(where: { $0.0 == setter })?.1 {
				return proxy
			}

			let invokeOriginalSetter: @convention(c) (NSObject, Selector, AnyObject?) -> Void = { object, selector, delegate in
				typealias Setter = @convention(c) (NSObject, Selector, AnyObject?) -> Void
				let impl = class_getMethodImplementation(object.objcClass, selector)
				unsafeBitCast(impl, to: Setter.self)(object, selector, delegate)
			}

			let newSetterImpl: @convention(block) (NSObject, AnyObject?) -> Void = { object, delegate in
				let proxyMap = object.associations.value(forKey: proxyMapKey)

				if let proxy = proxyMap.first(where: { $0.0 == setter })?.1 as! DelegateProxy<Delegate>? {
					proxy.forwardee = (delegate as! Delegate?)
				} else {
					invokeOriginalSetter(object, setter, delegate)
				}
			}

			// Hide the original setter, and redirect subsequent delegate assignment
			// to the proxy.
			instance.swizzle((setter, newSetterImpl), key: hasSwizzledKey)

			// As Objective-C classes may cache the information of their delegate at
			// the time the delegates are set, the information has to be "flushed"
			// whenever the proxy forwardee is replaced or a selector is intercepted.
			let proxy = self.init(lifetime: instance.reactive.lifetime) { [weak instance] proxy in
				guard let instance = instance else { return }
				invokeOriginalSetter(instance, setter, proxy)
			}

			typealias Getter = @convention(c) (NSObject, Selector) -> AnyObject?
			let getterImpl: IMP = class_getMethodImplementation(object_getClass(instance), getter)
			let original = unsafeBitCast(getterImpl, to: Getter.self)(instance, getter) as! Delegate?

			// `proxy.forwardee` would invoke the original setter regardless of
			// `original` being `nil` or not.
			proxy.forwardee = original

			// The proxy must be associated after it is set as the target, since
			// `base` may be an isa-swizzled instance that is using the injected
			// setters above.
			instance.associations.setValue(proxyMap + [(setter, proxy)], forKey: proxyMapKey)

			return proxy
		}
	}
}
