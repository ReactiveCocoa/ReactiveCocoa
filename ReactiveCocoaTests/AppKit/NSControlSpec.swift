import Quick
import Nimble
import Result
import ReactiveSwift
import ReactiveCocoa
import AppKit

class NSControlSpec: QuickSpec {
	override func spec() {
		describe("NSControl") {
			var window: NSWindow!
			var control: NSButton!
			weak var _control: NSControl?

			beforeEach {
				window = NSWindow()

				control = NSButton(frame: .zero)
				control.setButtonType(.onOff)
				#if swift(>=4.0)
				control.state = .off
				#else
				control.state = RACNSOffState
				#endif

				_control = control

				window.contentView!.addSubview(control)
			}

			afterEach {
				autoreleasepool {
					control.removeFromSuperview()
					control = nil
				}

				expect(_control).to(beNil())
			}

			it("should emit changes in Int") {
				var values = [Int]()
				control.reactive.integerValues.observeValues { values.append($0) }

				control.performClick(nil)
				control.performClick(nil)

				expect(values) == [1, 0]
			}

			it("should emit changes in Bool") {
				var values = [Bool]()
				control.reactive.boolValues.observeValues { values.append($0) }

				control.performClick(nil)
				control.performClick(nil)

				expect(values) == [true, false]
			}

			it("should emit changes in Int32") {
				var values = [Int32]()
				control.reactive.intValues.observeValues { values.append($0) }

				control.performClick(nil)
				control.performClick(nil)

				expect(values) == [1, 0]
			}

			it("should emit changes in Double") {
				var values = [Double]()
				control.reactive.doubleValues.observeValues { values.append($0) }

				control.performClick(nil)
				control.performClick(nil)

				expect(values) == [1.0, 0.0]
			}

			it("should emit changes in Float") {
				var values = [Float]()
				control.reactive.floatValues.observeValues { values.append($0) }

				control.performClick(nil)
				control.performClick(nil)

				expect(values) == [1.0, 0.0]
			}

			it("should emit changes in String") {
				var values = [String]()
				control.reactive.stringValues.observeValues { values.append($0) }

				control.performClick(nil)
				control.performClick(nil)

				expect(values) == ["1", "0"]
			}

			it("should emit changes in AttributedString") {
				var values = [NSAttributedString]()
				control.reactive.attributedStringValues.observeValues { values.append($0) }

				control.performClick(nil)
				control.performClick(nil)

				expect(values) == [NSAttributedString(string: "1"), NSAttributedString(string: "0")]
			}

			it("should emit changes as objects") {
				let values = NSMutableArray()
				control.reactive.objectValues.observeValues { values.add($0!) }

				control.performClick(nil)
				control.performClick(nil)

				expect(values) == [NSNumber(value: 1), NSNumber(value: 0)]
			}

			it("should emit changes for multiple signals") {
				var valuesA = [String]()
				control.reactive.stringValues.observeValues { valuesA.append($0) }

				var valuesB = [Bool]()
				control.reactive.boolValues.observeValues { valuesB.append($0) }

				var valuesC = [Int]()
				control.reactive.integerValues.observeValues { valuesC.append($0) }

				control.performClick(nil)
				control.performClick(nil)

				expect(valuesA) == ["1", "0"]
				expect(valuesB) == [true, false]
				expect(valuesC) == [1, 0]
			}

			it("should not overwrite the existing target") {
				let target = TestTarget()
				control.target = target
				control.action = #selector(target.execute)

				control.performClick(nil)
				expect(target.counter) == 1

				var signalCounter = 0
				control.reactive.integerValues.observeValues { _ in signalCounter += 1 }
				expect(control.target).toNot(beIdenticalTo(target))

				control.performClick(nil)
				expect(signalCounter) == 1
				expect(target.counter) == 2

				control.performClick(nil)
				expect(signalCounter) == 2
				expect(target.counter) == 3
			}

			it("should not overwrite the proxy") {
				var signalCounter = 0
				control.reactive.integerValues.observeValues { _ in signalCounter += 1 }

				control.performClick(nil)
				expect(signalCounter) == 1

				let target = TestTarget()
				control.target = target
				control.action = #selector(target.execute)

				control.performClick(nil)
				expect(signalCounter) == 2
				expect(target.counter) == 1


				control.performClick(nil)
				expect(signalCounter) == 3
				expect(target.counter) == 2
			}
		}
	}
}

private final class TestTarget {
	var counter = 0

	@objc func execute(_ sender: Any?) {
		counter += 1
	}
}
