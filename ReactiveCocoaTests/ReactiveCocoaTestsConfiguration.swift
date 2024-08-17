import Quick
#if canImport(UIKit)
import UIKit
#endif

class ReactiveCocoaTestsConfiguration: QuickConfiguration {
	override class func configure(_ configuration: QCKConfiguration) {
		#if canImport(UIKit)
			configuration.beforeSuite {
				UIControl._initialize()
			}
		#endif
	}
}
