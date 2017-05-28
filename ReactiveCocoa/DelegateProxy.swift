import ReactiveSwift
import enum Result.NoError

private let delegateProxySetupKey = AssociationKey<Bool>(default: false)
private let hasSwizzledKey = AssociationKey<Bool>(default: false)

public protocol DelegateProxyProtocol: class {}

// This is supposedly private, and is made `internal` to circumvent a serializer bug.
internal protocol _DelegateProxyProtocol: class {
	var _forwardee: AnyObject? { get }
	func proxyWillIntercept(_ selector: Selector)
	var lifetime: Lifetime { get }
}

public struct DelegateProxyConfiguration {
	fileprivate let objcProtocol: Protocol
	fileprivate let lifetime: Lifetime
	fileprivate let originalSetter: (AnyObject) -> Void
}

open class DelegateProxy<Delegate: NSObjectProtocol>: NSObject, DelegateProxyProtocol, _DelegateProxyProtocol {
	public final var delegateType: Delegate.Type {
		return Delegate.self
	}

	internal final weak var _forwardee: AnyObject?

	public weak var forwardee: Delegate? {
		get { return _forwardee as! Delegate? }
		set { _forwardee = newValue; originalSetter(self) }
	}

	internal final let lifetime: Lifetime

	private final let writeLock = NSLock()
	private final var interceptedSelectors: Set<Selector>
	private final let originalSetter: (AnyObject) -> Void
	private final let objcProtocol: Protocol

	public required init(config: DelegateProxyConfiguration) {
		interceptedSelectors = []
		objcProtocol = config.objcProtocol
		lifetime = config.lifetime
		originalSetter = config.originalSetter

		super.init()

		enableMessageForwarding { subclass, selectorCache, signatureCache in
			let perceivedClass: AnyClass = (self as AnyObject).objcClass
			let classAssociations = Associations(perceivedClass as AnyObject)

			try! ReactiveCocoa.synchronized(perceivedClass) {
				guard !classAssociations.value(forKey: delegateProxySetupKey) else { return }
				classAssociations.setValue(true, forKey: delegateProxySetupKey)

				// If `self` conforms to `objcProtocol`, all required methods should have
				// been implemented.
				let allRequiredMethodsImplemented = class_conformsToProtocol(perceivedClass, objcProtocol)

				// Implement all methods of the protocol. Conformances are masked by
				// `responds(to:)`.

				func implement(required: Bool) -> (Selector, UnsafePointer<Int8>) -> Void {
					return { selector, types in
						defer {
							selectorCache.cache(selector)
							signatureCache[selector] = NSMethodSignature.signature(withObjCTypes: types)
						}

						if required && allRequiredMethodsImplemented {
							return
						}

						// Implemented selectors with matching signatures are picked up by
						// the proxy even if `self` does not conform to the protocol.
						if let implementedMethod = class_getImmediateMethod(perceivedClass, selector),
							strcmp(types, method_getTypeEncoding(implementedMethod)) == 0 {
							return
						}

						precondition(!required || isNonVoidReturning(types),
						             "DelegateProxy does not support protocols with required methods that returns non-void types.")

						let previousImpl = class_replaceMethod(perceivedClass, selector, _rac_objc_msgForward, types)
						precondition(previousImpl == nil || previousImpl == _rac_objc_msgForward,
						             "Swizzling DelegateProxy with other libraries is not supported. \(perceivedClass)")
					}
				}

				objcProtocol.enumerateMethods(required: true, body: implement(required: true))
				objcProtocol.enumerateMethods(required: false, body: implement(required: false))
			}
		}
	}

	open override func conforms(to aProtocol: Protocol) -> Bool {
		return aProtocol === objcProtocol || super.conforms(to: aProtocol)
	}

	open override func responds(to selector: Selector!) -> Bool {
		return protocol_getMethodDescription(objcProtocol, selector, true, true).name != nil
			|| interceptedSelectors.contains(selector)
			|| NSObject.instancesRespond(to: selector)
			|| forwardee?.responds(to: selector) ?? false
	}

	internal final func proxyWillIntercept(_ selector: Selector) {
		writeLock.lock()
		defer { writeLock.unlock() }
		interceptedSelectors.insert(selector)
		originalSetter(self)
	}
}

extension Protocol {
	fileprivate func enumerateMethods(required: Bool, body: (Selector, UnsafePointer<Int8>) -> Void) {
		var count: UInt32 = 0
		if let list = protocol_copyMethodDescriptionList(self, required, true, &count) {
			UnsafeBufferPointer(start: list, count: Int(count))
				.lazy.filter { $0.name != nil }.forEach { body($0.name, $0.types) }
			free(list)
		}
	}
}

internal func unsafeDelegateProxy(_ proxy: Unmanaged<NSObject>, didInvoke selector: Selector, with invocation: AnyObject) {
	let proxy = proxy.takeUnretainedValue() as! _DelegateProxyProtocol
	if let forwardee = proxy._forwardee, forwardee.responds(to: selector) {
		invocation.invoke(withTarget: forwardee)
	}
}

internal func isDelegateProxy(_ type: AnyClass) -> Bool {
	return type is _DelegateProxyProtocol.Type
}

extension Reactive where Base: NSObject, Base: DelegateProxyProtocol {
	/// Create a signal which sends a `next` event at the end of every
	/// invocation of `selector` on the object.
	///
	/// It completes when the object deinitializes.
	///
	/// - note: Observers to the resulting signal should not call the method
	///         specified by the selector.
	///
	/// - parameters:
	///   - selector: The selector to observe.
	///
	/// - returns: A trigger signal.
	public func trigger(for selector: Selector) -> Signal<(), NoError> {
		let base = self.base as! _DelegateProxyProtocol
		base.proxyWillIntercept(selector)

		return (self.base as NSObject).reactive.trigger(for: selector)
			.take(during: base.lifetime)
	}

	/// Create a signal which sends a `next` event, containing an array of
	/// bridged arguments, at the end of every invocation of `selector` on the
	/// object.
	///
	/// It completes when the object deinitializes.
	///
	/// - note: Observers to the resulting signal should not call the method
	///         specified by the selector.
	///
	/// - parameters:
	///   - selector: The selector to observe.
	///
	/// - returns: A signal that sends an array of bridged arguments.
	public func signal(for selector: Selector) -> Signal<[Any?], NoError> {
		let base = self.base as! _DelegateProxyProtocol
		base.proxyWillIntercept(selector)

		return (self.base as NSObject).reactive.signal(for: selector)
			.take(during: base.lifetime)
	}
}

extension Reactive where Base: NSObject {
	/// Create a transparent proxy that intercepts calls from `instance` to its delegate
	/// of the given key.
	///
	/// After the proxy is initialized, the delegate setter of `instance` would be
	/// automatically redirected to the proxy.
	///
	/// - important: If you subclass `DelegateProxy`, your implementations are responsible
	///              of forwarding the calls to the forwardee.
	///
	/// - warnings: `DelegateProxy` does not support protocols containing methods that are
	///             non-void returning. It would trap immediately when the proxy
	///             initializes with a protocol containing such a required method, or when
	///             the proxy is asked to intercept such an optional method.
	///
	/// - parameters:
	///   - key: The key of the property that stores the delegate reference.
	///
	/// - returns: The proxy.
	public func proxy<Delegate, Proxy: DelegateProxy<Delegate>>(_: Delegate.Type = Delegate.self, forKey key: String) -> Proxy {
		func remangleIfNeeded(_ name: String) -> String {
			let expression = try! NSRegularExpression(pattern: "^([a-zA-Z0-9\\_\\.]+)\\.\\(([a-zA-Z0-9\\_]+)\\sin\\s([a-zA-Z0-9\\_]+)\\)$")
			if let match = expression.firstMatch(in: name, range: NSMakeRange(0, name.characters.count)) {
				// `name` refers to a private protocol.
				let objcName = name as NSString

				let (moduleNameRange, protocolNameRange, scopeNameRange) = (match.rangeAt(1), match.rangeAt(2), match.rangeAt(3))
				let moduleName = objcName.substring(with: moduleNameRange)
				let protocolName = objcName.substring(with: protocolNameRange)
				let scopeName = objcName.substring(with: scopeNameRange)

				// Example: _TtP18ReactiveCocoaTestsP33_B2B708E0A88135A5DA71A5A2AAFA457014ObjectDelegate_
				return "_TtP\(moduleNameRange.length)\(moduleName)P\(scopeNameRange.length)\(scopeName)\(protocolNameRange.length)\(protocolName)_"
			} else if let range = name.range(of: "__ObjC.") {
				// `name` refers to an Objective-C protocol.
				return name.substring(from: range.upperBound)
			} else {
				// `name` refers to a Swift protocol.
				return name
			}
		}

		let mangledName = remangleIfNeeded(String(reflecting: Delegate.self))
		let objcProtocol = NSProtocolFromString(mangledName)!

		return base.synchronized {
			let getter = Selector(((key)))
			let setter = Selector((("set\(String(key.characters.first!).uppercased())\(String(key.characters.dropFirst())):")))

			let proxyKey = AssociationKey<AnyObject?>(setter.delegateProxyAlias)

			if let proxy = base.associations.value(forKey: proxyKey) {
				return proxy as! Proxy
			}

			let superclass: AnyClass = class_getSuperclass(swizzleClass(base))

			let invokeSuperSetter: @convention(c) (Unmanaged<AnyObject>, AnyClass, Selector, Unmanaged<AnyObject>?) -> Void = { object, superclass, selector, delegate in
				typealias Setter = @convention(c) (Unmanaged<AnyObject>, Selector, Unmanaged<AnyObject>?) -> Void
				let impl = class_getMethodImplementation(superclass, selector)
				unsafeBitCast(impl, to: Setter.self)(object, selector, delegate)
			}

			let newSetterImpl: @convention(block) (Unmanaged<AnyObject>, Unmanaged<AnyObject>?) -> Void = { object, delegate in
				if let proxy = Associations(object.takeUnretainedValue()).value(forKey: proxyKey) as! DelegateProxy<Delegate>? {
					proxy.forwardee = delegate?.takeUnretainedValue() as! Delegate?
				} else {
					invokeSuperSetter(object, superclass, setter, delegate)
				}
			}

			// Hide the original setter, and redirect subsequent delegate assignment
			// to the proxy.
			base.swizzle((setter, newSetterImpl), key: hasSwizzledKey)

			// As Objective-C classes may cache the information of their delegate at
			// the time the delegates are set, the information has to be "flushed"
			// whenever the proxy forwardee is replaced or a selector is intercepted.
			let proxy = Proxy(config: DelegateProxyConfiguration(objcProtocol: objcProtocol, lifetime: base.reactive.lifetime) { [weak base] proxy in
				guard let base = base else { return }
				invokeSuperSetter(.passUnretained(base), superclass, setter, .passUnretained(proxy))
			})

			typealias Getter = @convention(c) (NSObject, Selector) -> AnyObject?
			let getterImpl: IMP = class_getMethodImplementation(object_getClass(base), getter)
			let original = unsafeBitCast(getterImpl, to: Getter.self)(base, getter) as! Delegate?

			// `proxy.forwardee` would invoke the original setter regardless of
			// `original` being `nil` or not.
			proxy.forwardee = original

			// The proxy must be associated after it is set as the target, since
			// `base` may be an isa-swizzled instance that is using the injected
			// setters above.
			base.associations.setValue(proxy, forKey: proxyKey)

			return proxy
		}
	}
}
