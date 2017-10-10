import AppKit
import ReactiveSwift
import enum Result.NoError

internal final class ActionProxy<Owner: AnyObject>: NSObject {
	internal weak var target: AnyObject?
	internal var action: Selector?
	internal let invoked: Signal<Owner, NoError>

	private let observer: Signal<Owner, NoError>.Observer
	private unowned let owner: Owner

	internal init(owner: Owner, lifetime: Lifetime) {
		self.owner = owner
		(invoked, observer) = Signal<Owner, NoError>.pipe()
		lifetime.ended.observeCompleted(observer.sendCompleted)
	}

	// In AppKit, action messages always have only one parameter.
	@objc func invoke(_ sender: Any?) {
		if let action = action {
			if let app = NSApp {
				app.sendAction(action, to: target, from: sender)
			} else {
				_ = target?.perform(action, with: sender)
			}
		}

		observer.send(value: owner)
	}
}

private let hasSwizzledKey = AssociationKey<Bool>(default: false)

@objc internal protocol ActionMessageSending: class {
	weak var target: AnyObject? { get set }
	var action: Selector? { get set }
}

extension Reactive where Base: NSObject, Base: ActionMessageSending {
	internal var proxy: ActionProxy<Base> {
		let key = AssociationKey<ActionProxy<Base>?>((#function as StaticString))

		return base.synchronized {
			if let proxy = base.associations.value(forKey: key) {
				return proxy
			}

			let superclass: AnyClass = class_getSuperclass(swizzleClass(base))!

			let proxy = ActionProxy<Base>(owner: base, lifetime: lifetime)
			proxy.target = base.target
			proxy.action = base.action

			// Set the proxy as the new delegate with all dynamic interception bypassed
			// by directly invoking setters in the original class.
			typealias TargetSetter = @convention(c) (NSObject, Selector, AnyObject?) -> Void
			typealias ActionSetter = @convention(c) (NSObject, Selector, Selector?) -> Void

			let setTargetImpl = class_getMethodImplementation(superclass, #selector(setter: base.target))
			unsafeBitCast(setTargetImpl, to: TargetSetter.self)(base, #selector(setter: base.target), proxy)

			let setActionImpl = class_getMethodImplementation(superclass, #selector(setter: base.action))
			unsafeBitCast(setActionImpl, to: ActionSetter.self)(base, #selector(setter: base.action), #selector(proxy.invoke(_:)))

			base.associations.setValue(proxy, forKey: key)

			let newTargetSetterImpl: @convention(block) (NSObject, AnyObject?) -> Void = { object, target in
				if let proxy = object.associations.value(forKey: key) {
					proxy.target = target
				} else {
					let impl = class_getMethodImplementation(superclass, #selector(setter: self.base.target))
					unsafeBitCast(impl, to: TargetSetter.self)(object, #selector(setter: self.base.target), target)
				}
			}

			let newActionSetterImpl: @convention(block) (NSObject, Selector?) -> Void = { object, action in
				if let proxy = object.associations.value(forKey: key) {
					proxy.action = action
				} else {
					let impl = class_getMethodImplementation(superclass, #selector(setter: self.base.action))
					unsafeBitCast(impl, to: ActionSetter.self)(object, #selector(setter: self.base.action), action)
				}
			}

			// Swizzle the instance only after setting up the proxy.
			base.swizzle((#selector(setter: base.target), newTargetSetterImpl),
			             (#selector(setter: base.action), newActionSetterImpl),
			             key: hasSwizzledKey)

			return proxy
		}
	}
}
