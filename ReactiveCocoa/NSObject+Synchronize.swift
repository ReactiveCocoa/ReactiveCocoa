extension NSObject {
	internal func synchronize<Result>(execute: () throws -> Result) rethrows -> Result {
		objc_sync_enter(self)
		defer { objc_sync_exit(self) }
		return try execute()
	}
}
