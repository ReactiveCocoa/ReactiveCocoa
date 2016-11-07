import Foundation
import ReactiveSwift
import enum Result.NoError

extension Reactive where Base: NSObject {
	/// Create a signal which sends a `next` event at the end of every invocation
	/// of `selector` on the object.
	///
	/// `trigger(for:from:)` can be used to intercept optional protocol
	/// requirements by supplying the protocol as `protocol`. The instance need
	/// not have a concrete implementation of the requirement.
	///
	/// However, as Cocoa classes usually cache information about delegate
	/// conformances, trigger signals for optional, unbacked protocol requirements
	/// should be set up before the instance is assigned as the corresponding
	/// delegate.
	///
	/// - parameters:
	///   - selector: The selector to observe.
	///   - protocol: The protocol of the selector, or `nil` if the selector does
	///               not belong to any protocol.
	///
	/// - returns:
	///   A trigger signal.
	public func trigger(for selector: Selector, from protocol: Protocol? = nil) -> Signal<(), NoError> {
		return base.synchronized {
			let map = associatedValue { _ in NSMutableDictionary() }

			let selectorName = String(describing: selector) as NSString
			if let signal = map.object(forKey: selectorName) as! Signal<(), NoError>? {
				return signal
			}

			let (signal, observer) = Signal<(), NoError>.pipe()
			let isSuccessful = base._rac_setupInvocationObservation(for: selector,
			                                                        protocol: `protocol`,
			                                                        receiver: { _ in observer.send(value: ()) })
			precondition(isSuccessful)

			lifetime.ended.observeCompleted(observer.sendCompleted)
			map.setObject(signal, forKey: selectorName)

			return signal
		}
	}

	/// Create a signal which sends a `next` event, containing an array of bridged
	/// arguments, at the end of every invocation of `selector` on the object.
	///
	/// `trigger(for:from:)` can be used to intercept optional protocol
	/// requirements by supplying the protocol as `protocol`. The instance need
	/// not have a concrete implementation of the requirement.
	///
	/// However, as Cocoa classes usually cache information about delegate
	/// conformances, trigger signals for optional, unbacked protocol requirements
	/// should be set up before the instance is assigned as the corresponding
	/// delegate.
	///
	/// - parameters:
	///   - selector: The selector to observe.
	///   - protocol: The protocol of the selector, or `nil` if the selector does
	///               not belong to any protocol.
	///
	/// - returns:
	///   A signal that sends an array of bridged arguments.
	public func signal(for selector: Selector, from protocol: Protocol? = nil) -> Signal<[Any?], NoError> {
		return base.synchronized {
			let map = associatedValue { _ in NSMutableDictionary() }

			let selectorName = String(describing: selector) as NSString
			if let signal = map.object(forKey: selectorName) as! Signal<[Any?], NoError>? {
				return signal
			}

			let (signal, observer) = Signal<[Any?], NoError>.pipe()
			let isSuccessful = base._rac_setupInvocationObservation(for: selector,
			                                                        protocol: `protocol`,
			                                                        receiver: bridge(observer))
			precondition(isSuccessful)

			lifetime.ended.observeCompleted(observer.sendCompleted)
			map.setObject(signal, forKey: selectorName)

			return signal
		}
	}
}

private func bridge(_ observer: Observer<[Any?], NoError>) -> (RACSwiftInvocationArguments) -> Void {
	return { arguments in
		let count = arguments.count

		var bridged = [Any?]()
		bridged.reserveCapacity(count - 2)

		// Ignore `self` and `_cmd`.
		for position in 2 ..< count {
			let encoding = TypeEncoding(rawValue: arguments.argumentType(at: position).pointee) ?? .undefined

			func extract<U>(_ type: U.Type) -> U {
				let pointer = UnsafeMutableRawPointer.allocate(bytes: MemoryLayout<U>.size,
				                                               alignedTo: MemoryLayout<U>.alignment)
				defer {
					pointer.deallocate(bytes: MemoryLayout<U>.size,
					                   alignedTo: MemoryLayout<U>.alignment)
				}

				arguments.copyArgument(at: position, to: pointer)
				return pointer.assumingMemoryBound(to: type).pointee
			}

			switch encoding {
			case .char:
				bridged.append(extract(CChar.self))
			case .int:
				bridged.append(extract(CInt.self))
			case .short:
				bridged.append(extract(CShort.self))
			case .long:
				bridged.append(extract(CLong.self))
			case .longLong:
				bridged.append(extract(CLongLong.self))

			case .unsignedChar:
				bridged.append(extract(CUnsignedChar.self))
			case .unsignedInt:
				bridged.append(extract(CUnsignedInt.self))
			case .unsignedShort:
				bridged.append(extract(CUnsignedShort.self))
			case .unsignedLong:
				bridged.append(extract(CUnsignedLong.self))

			case .bitfield:
				fallthrough
			case .unsignedLongLong:
				bridged.append(extract(CUnsignedLongLong.self))

			case .float:
				bridged.append(extract(CFloat.self))
			case .double:
				bridged.append(extract(CDouble.self))

			case .bool:
				bridged.append(extract(CBool.self))
			case .void:
				bridged.append(())

			case .cString:
				var pointer: UnsafePointer<Int8>?
				arguments.copyArgument(at: position, to: &pointer)
				bridged.append(pointer.map(String.init(cString:)))

			case .object:
				bridged.append(extract((AnyObject?).self))
			case .type:
				bridged.append(extract((AnyClass?).self))

			case .selector:
				bridged.append(arguments.selectorString(at: position))

			case .array:
				bridged.append(extract(OpaquePointer.self))

			case .undefined:
				bridged.append(nil)
			}
		}

		observer.send(value: bridged)
	}
}


private enum TypeEncoding: Int8 {
	// Integer
	case char = 99
	case int = 105
	case short = 115
	case long = 108
	case longLong = 113

	// Unsigned Integer
	case unsignedChar = 67
	case unsignedInt = 73
	case unsignedShort = 83
	case unsignedLong = 76
	case unsignedLongLong = 81

	// FP
	case float = 102
	case double = 100

	case bool = 66
	case void = 118
	case cString = 42
	case object = 64
	case type = 35
	case selector = 58
	case array = 91
	case bitfield = 98
	// Note: Structure `{` and union `(` are not supported.

	case undefined = -1
}
