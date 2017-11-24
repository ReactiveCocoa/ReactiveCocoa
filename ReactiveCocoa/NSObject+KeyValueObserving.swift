import Foundation
import ReactiveSwift
import enum Result.NoError

extension Reactive where Base: NSObject {
	/// Create a producer which sends the current value and all the subsequent
	/// changes of the property specified by the key path.
	///
	/// The producer completes when the object deinitializes.
	///
	/// - parameters:
	///   - keyPath: The key path of the property to be observed.
	///
	/// - returns: A producer emitting values of the property specified by the
	///            key path.
	public func producer(forKeyPath keyPath: String) -> SignalProducer<Any?, NoError> {
		return SignalProducer { observer, lifetime in
			let disposable = KeyValueObserver.observe(
				self.base,
				keyPath: keyPath,
				options: [.initial, .new],
				action: observer.send
			)

			lifetime.observeEnded(disposable.dispose)

			if let lifetimeDisposable = self.lifetime.observeEnded(observer.sendCompleted) {
				lifetime.observeEnded(lifetimeDisposable.dispose)
			}
		}
	}

	/// Create a signal all changes of the property specified by the key path.
	///
	/// The signal completes when the object deinitializes.
	///
	/// - note:
	///	  Does not send the initial value. See `producer(forKeyPath:)`.
	///
	/// - parameters:
	///   - keyPath: The key path of the property to be observed.
	///
	/// - returns: A producer emitting values of the property specified by the 
	///            key path.
	public func signal(forKeyPath keyPath: String) -> Signal<Any?, NoError> {
		return Signal { observer, signalLifetime in
			signalLifetime += KeyValueObserver.observe(
				self.base,
				keyPath: keyPath,
				options: [.new],
				action: observer.send
			)
			signalLifetime += lifetime.observeEnded(observer.sendCompleted)
		}
	}
}

extension Property where Value: OptionalProtocol {
	/// Create a property that observes the given key path of the given object. The
	/// generic type `Value` can be any Swift type that is Objective-C bridgeable.
	///
	/// - parameters:
	///   - object: An object to be observed.
	///   - keyPath: The key path to observe.
	public convenience init(object: NSObject, keyPath: String) {
		// `Property(_:)` caches the latest value of the `DynamicProperty`, so it is
		// saved to be used even after `object` deinitializes.
		self.init(UnsafeKVOProperty(object: object, optionalAttributeKeyPath: keyPath))
	}
}

extension Property {
	/// Create a property that observes the given key path of the given object. The
	/// generic type `Value` can be any Swift type that is Objective-C bridgeable.
	///
	/// - parameters:
	///   - object: An object to be observed.
	///   - keyPath: The key path to observe.
	public convenience init(object: NSObject, keyPath: String) {
		// `Property(_:)` caches the latest value of the `DynamicProperty`, so it is
		// saved to be used even after `object` deinitializes.
		self.init(UnsafeKVOProperty(object: object, nonOptionalAttributeKeyPath: keyPath))
	}
}

// `Property(unsafeProducer:)` is private to ReactiveSwift. So the fact that
// `Property(_:)` uses only the producer is explioted here to achieve the same effect.
private final class UnsafeKVOProperty<Value>: PropertyProtocol {
	var value: Value { fatalError() }
	var signal: Signal<Value, NoError> { fatalError() }
	let producer: SignalProducer<Value, NoError>
	
	init(producer: SignalProducer<Value, NoError>) {
		self.producer = producer
	}
	
	convenience init(object: NSObject, nonOptionalAttributeKeyPath keyPath: String) {
		self.init(producer: object.reactive.producer(forKeyPath: keyPath).map { $0 as! Value })
	}
}

private extension UnsafeKVOProperty where Value: OptionalProtocol {
	convenience init(object: NSObject, optionalAttributeKeyPath keyPath: String) {
		self.init(producer: object.reactive.producer(forKeyPath: keyPath).map {
			return Value(reconstructing: $0.optional as? Value.Wrapped)
		})
	}
}

extension BindingTarget {
	/// Create a binding target that sets the given key path of the given object. The
	/// generic type `Value` can be any Swift type that is Objective-C bridgeable.
	///
	/// - parameters:
	///   - object: An object to be observed.
	///   - keyPath: The key path to set.
	public init(object: NSObject, keyPath: String) {
		self.init(lifetime: object.reactive.lifetime) { [weak object] value in
			object?.setValue(value, forKey: keyPath)
		}
	}
}

internal final class KeyValueObserver: NSObject {
	typealias Action = (_ object: AnyObject?) -> Void
	private static let context = UnsafeMutableRawPointer.allocate(bytes: 1, alignedTo: 0)

	unowned(unsafe) let unsafeObject: NSObject
	let key: String
	let action: Action

	fileprivate init(observing object: NSObject, key: String, options: NSKeyValueObservingOptions, action: @escaping Action) {
		self.unsafeObject = object
		self.key = key
		self.action = action

		super.init()

		object.addObserver(
			self,
			forKeyPath: key,
			options: options,
			context: KeyValueObserver.context
		)
	}

	func detach() {
		unsafeObject.removeObserver(self, forKeyPath: key, context: KeyValueObserver.context)
	}

	override func observeValue(
		forKeyPath keyPath: String?,
		of object: Any?,
		change: [NSKeyValueChangeKey : Any]?,
		context: UnsafeMutableRawPointer?
	) {
		if context == KeyValueObserver.context {
			action(object as! NSObject)
		}
	}
}

extension KeyValueObserver {
	/// Establish an observation to the property specified by the key path
	/// of `object`.
	///
	/// - warning: The observation would not be automatically removed when
	///            `object` deinitializes. You must manually dispose of the
	///            returned disposable before `object` completes its
	///            deinitialization.
	///
	/// - parameters:
	///   - object: The object to be observed.
	///   - keyPath: The key path of the property to be observed.
	///   - options: The desired configuration of the observation.
	///   - action: The action to be invoked upon arrival of changes.
	///
	/// - returns: A disposable that would tear down the observation upon 
	///            disposal.
	static func observe(
		_ object: NSObject,
		keyPath: String,
		options: NSKeyValueObservingOptions,
		action: @escaping (_ value: AnyObject?) -> Void
	) -> AnyDisposable {
		// Compute the key path head and tail.
		let components = keyPath.components(separatedBy: ".")
		precondition(!components.isEmpty, "Received an empty key path.")

		let isNested = components.count > 1
		let keyPathHead = components[0]
		let keyPathTail = components[1 ..< components.endIndex].joined(separator: ".")

		// The serial disposable for the head key.
		//
		// The inner disposable would be disposed of, and replaced with a new one
		// when the value of the head key changes.
		let headSerialDisposable = SerialDisposable()

		// If the property of the head key isn't actually an object (or is a Class
		// object), there is no point in observing the deallocation.
		//
		// If this property is not a weak reference to an object, we don't need to
		// watch for it spontaneously being set to nil.
		//
		// Attempting to observe non-weak properties using dynamic getters will
		// result in broken behavior, so don't even try.
		let (shouldObserveDeinit, isWeak) = keyPathHead.withCString { cString -> (Bool, Bool) in
			if let propertyPointer = class_getProperty(type(of: object), cString) {
				let attributes = PropertyAttributes(property: propertyPointer)
				return (attributes.isObject && attributes.objectClass != NSClassFromString("Protocol") && !attributes.isBlock, attributes.isWeak)
			}

			return (false, false)
		}

		// Establish the observation.
		//
		// The initial value is also handled by the closure below, if `Initial` has
		// been specified in the observation options.
		let observer: KeyValueObserver

		if isNested {
			observer = KeyValueObserver(observing: object, key: keyPathHead, options: options.union(.initial)) { object in
				guard let value = object?.value(forKey: keyPathHead) as! NSObject? else {
					action(nil)
					return
				}

				let headDisposable = CompositeDisposable()
				headSerialDisposable.inner = headDisposable

				if shouldObserveDeinit {
					let disposable = value.reactive.lifetime.observeEnded {
						if isWeak {
							action(nil)
						}

						// Detach the key path tail observers eagarly.
						headSerialDisposable.inner = nil
					}
					headDisposable += disposable
				}

				// Recursively add observers along the key path tail.
				let disposable = KeyValueObserver.observe(
					value,
					keyPath: keyPathTail,
					options: options.subtracting(.initial),
					action: action
				)
				headDisposable += disposable

				// Send the latest value of the key path tail.
				action(value.value(forKeyPath: keyPathTail) as AnyObject?)
			}
		} else {
			observer = KeyValueObserver(observing: object, key: keyPathHead, options: options) { object in
				guard let value = object?.value(forKey: keyPathHead) as AnyObject? else {
					action(nil)
					return
				}

				// For a direct key path, the deinitialization needs to be
				// observed only if the key path is a weak property.
				if shouldObserveDeinit && isWeak {
					let disposable = lifetime(of: value).observeEnded {
						action(nil)
					}

					headSerialDisposable.inner = disposable
				}

				// Send the latest value of the key.
				action(value)
			}
		}

		return AnyDisposable {
			observer.detach()
			headSerialDisposable.dispose()
		}
	}
}

/// A descriptor of the attributes and type information of a property in
/// Objective-C.
internal struct PropertyAttributes {
	struct Code {
		static let start = Int8(UInt8(ascii: "T"))
		static let quote = Int8(UInt8(ascii: "\""))
		static let nul = Int8(UInt8(ascii: "\0"))
		static let comma = Int8(UInt8(ascii: ","))

		struct ContainingType {
			static let object = Int8(UInt8(ascii: "@"))
			static let block = Int8(UInt8(ascii: "?"))
		}

		struct Attribute {
			static let readonly = Int8(UInt8(ascii: "R"))
			static let copy = Int8(UInt8(ascii: "C"))
			static let retain = Int8(UInt8(ascii: "&"))
			static let nonatomic = Int8(UInt8(ascii: "N"))
			static let getter = Int8(UInt8(ascii: "G"))
			static let setter = Int8(UInt8(ascii: "S"))
			static let dynamic = Int8(UInt8(ascii: "D"))
			static let ivar = Int8(UInt8(ascii: "V"))
			static let weak = Int8(UInt8(ascii: "W"))
			static let collectable = Int8(UInt8(ascii: "P"))
			static let oldTypeEncoding = Int8(UInt8(ascii: "t"))
		}
	}

	/// The class of the property.
	let objectClass: AnyClass?

	/// Indicate whether the property is a weak reference.
	let isWeak: Bool

	/// Indicate whether the property is an object.
	let isObject: Bool

	/// Indicate whether the property is a block.
	let isBlock: Bool

	init(property: objc_property_t) {
		guard let attrString = property_getAttributes(property) else {
			preconditionFailure("Could not get attribute string from property.")
		}

		precondition(attrString[0] == Code.start, "Expected attribute string to start with 'T'.")

		let typeString = attrString + 1

		let _next = NSGetSizeAndAlignment(typeString, nil, nil)
		guard _next != typeString else {
			let string = String(validatingUTF8: attrString)
			preconditionFailure("Could not read past type in attribute string: \(String(describing: string)).")
		}
		var next = UnsafeMutablePointer<Int8>(mutating: _next)

		let typeLength = typeString.distance(to: next)
		precondition(typeLength > 0, "Invalid type in attribute string.")

		var objectClass: AnyClass? = nil

		// if this is an object type, and immediately followed by a quoted string...
		if typeString[0] == Code.ContainingType.object && typeString[1] == Code.quote {
			// we should be able to extract a class name
			let className = typeString + 2;

			// fast forward the `next` pointer.
			guard let endQuote = strchr(className, Int32(Code.quote)) else {
				preconditionFailure("Could not read class name in attribute string.")
			}
			next = endQuote

			if className != UnsafePointer(next) {
				let length = className.distance(to: next)
				let name = UnsafeMutablePointer<Int8>.allocate(capacity: length + 1)
				name.initialize(from: UnsafeMutablePointer<Int8>(mutating: className), count: length)
				(name + length).initialize(to: Code.nul)

				// attempt to look up the class in the runtime
				objectClass = objc_getClass(name) as! AnyClass?

				name.deinitialize(count: length + 1)
				name.deallocate(capacity: length + 1)
			}
		}

		if next.pointee != Code.nul {
			// skip past any junk before the first flag
			next = strchr(next, Int32(Code.comma))
		}

		let emptyString = UnsafeMutablePointer<Int8>.allocate(capacity: 1)
		emptyString.initialize(to: Code.nul)
		defer {
			emptyString.deinitialize()
			emptyString.deallocate(capacity: 1)
		}

		var isWeak = false

		while next.pointee == Code.comma {
			let flag = next[1]
			next += 2

			switch flag {
			case Code.nul:
				break;

			case Code.Attribute.readonly:
				break;

			case Code.Attribute.copy:
				break;

			case Code.Attribute.retain:
				break;

			case Code.Attribute.nonatomic:
				break;

			case Code.Attribute.getter:
				fallthrough

			case Code.Attribute.setter:
					next = strchr(next, Int32(Code.comma)) ?? emptyString

			case Code.Attribute.dynamic:
				break

			case Code.Attribute.ivar:
				// assume that the rest of the string (if present) is the ivar name
				if next.pointee != Code.nul {
					next = emptyString
				}

			case Code.Attribute.weak:
				isWeak = true

			case Code.Attribute.collectable:
				break

			case Code.Attribute.oldTypeEncoding:
				let string = String(validatingUTF8: attrString)
				assertionFailure("Old-style type encoding is unsupported in attribute string \"\(String(describing: string))\"")

				// skip over this type encoding
				while next.pointee != Code.comma && next.pointee != Code.nul {
					next += 1
				}

			default:
				let pointer = UnsafeMutablePointer<Int8>.allocate(capacity: 2)
				pointer.initialize(to: flag)
				(pointer + 1).initialize(to: Code.nul)

				let flag = String(validatingUTF8: pointer)
				let string = String(validatingUTF8: attrString)
				preconditionFailure("ERROR: Unrecognized attribute string flag '\(String(describing: flag))' in attribute string \"\(String(describing: string))\".")
			}
		}

		if next.pointee != Code.nul {
			let unparsedData = String(validatingUTF8: next)
			let string = String(validatingUTF8: attrString)
			assertionFailure("Warning: Unparsed data \"\(String(describing: unparsedData))\" in attribute string \"\(String(describing: string))\".")
		}

		self.objectClass = objectClass
		self.isWeak = isWeak
		self.isObject = typeString[0] == Code.ContainingType.object
		self.isBlock = isObject && typeString[1] == Code.ContainingType.block
	}
}
