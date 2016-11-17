extension NSObject {
	@nonobjc internal var objcClass: AnyClass {
		return (self as AnyObject).objcClass
	}

	@nonobjc internal func setClass(_ class: ObjCClass) {
		object_setClass(self, `class`.reference)
	}
}
