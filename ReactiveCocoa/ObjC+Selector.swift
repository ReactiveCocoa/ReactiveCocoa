extension Selector {
	/// `self` as a pointer. It is uniqued across instances, similar to
	/// `StaticString`.
	internal var utf8Start: UnsafePointer<Int8> {
		return unsafeBitCast(self, to: UnsafePointer<Int8>.self)
	}

	/// An alias of `self`, used in method interception.
	internal var alias: Selector {
		return prefixing("rac0_")
	}

	/// An alias of `self`, used in method interception specifically for
	/// preserving (if found) an immediate implementation of `self` in the
	/// runtime subclass.
	internal var interopAlias: Selector {
		return prefixing("rac1_")
	}

	/// An alias of `self`, used for delegate proxies.
	internal var delegateProxyAlias: Selector {
		return prefixing("rac2_")
	}

	internal func prefixing(_ prefix: StaticString) -> Selector {
		let length = Int(strlen(utf8Start))
		let prefixedLength = length + prefix.utf8CodeUnitCount

		let asciiPrefix = UnsafeRawPointer(prefix.utf8Start).assumingMemoryBound(to: Int8.self)

		let cString = UnsafeMutablePointer<Int8>.allocate(capacity: prefixedLength + 1)
		defer {
			cString.deinitialize(count: prefixedLength + 1)
			cString.deallocate()
		}

		cString.initialize(from: asciiPrefix, count: prefix.utf8CodeUnitCount)
		(cString + prefix.utf8CodeUnitCount).initialize(from: utf8Start, count: length)
		(cString + prefixedLength).initialize(to: Int8(UInt8(ascii: "\0")))

		return sel_registerName(cString)
	}
}
