import AppKit

extension NSTableCellView: Reusable {}
extension NSCollectionViewItem: Reusable {
	@nonobjc public func prepareForReuse() {
		// Workaround: The compiler complains about `prepareForReuse` not being
		//             available for "OSXApplicationExtension 10.9", regardless of
		//             any `@available` annotation to the extension and to the
		//             protocol.
		(self as AnyObject).prepareForReuse()
	}
}
