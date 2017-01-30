import Quick
import Nimble
import ReactiveSwift
import ReactiveCocoa
import UIKit
import enum Result.NoError

class UIGestureRecognizerSpec: QuickSpec {
	override func spec() {
		var gestureRecognizer: TestTapGestureRecognizer!
		weak var _gestureRecognizer: TestTapGestureRecognizer?
		
		beforeEach {
			gestureRecognizer = TestTapGestureRecognizer()
			_gestureRecognizer = gestureRecognizer
		}
		
		afterEach {
			gestureRecognizer = nil
			expect(_gestureRecognizer).to(beNil())
		}
		
		it("should send a value when the gesture state changes") {
			let signal = gestureRecognizer.reactive.stateChanged
			
			var counter = 0
			signal.observeValues { _ in counter += 1 }
			
			expect(counter) == 0
			gestureRecognizer.fireGestureEvent(.possible)

			expect(counter) == 1
			
			gestureRecognizer.fireGestureEvent( .began)
			expect(counter) == 2
			
			gestureRecognizer.fireGestureEvent(.changed)
			expect(counter) == 3
			
			gestureRecognizer.fireGestureEvent(.ended)
			expect(counter) == 4
		}
		
		it("should send it's gesture recognizer in signal") {
			let signal = gestureRecognizer.reactive.stateChanged
			var counter = 0
			signal.observeValues { signalGestureRecognizer in
				if signalGestureRecognizer === gestureRecognizer{
					counter += 1
				}
			}
			gestureRecognizer.fireGestureEvent( .began)
			expect(counter) == 1
		}
		
		it("should send it's gesture recognizer with the fired state") {
			let signal = gestureRecognizer.reactive.stateChanged
			weak var signalGestureRecognizer: TestTapGestureRecognizer?
			signal.observeValues { recognizer in
				signalGestureRecognizer = recognizer
			}
			
			gestureRecognizer.fireGestureEvent(.possible)
			expect(signalGestureRecognizer?.state) == .possible
			
			gestureRecognizer.fireGestureEvent( .began)
			expect(signalGestureRecognizer?.state) == .began
			
			gestureRecognizer.fireGestureEvent(.changed)
			expect(signalGestureRecognizer?.state) == .changed
			
			gestureRecognizer.fireGestureEvent(.ended)
			expect(signalGestureRecognizer?.state) == .ended
		}
	}
}

private final class TestTapGestureRecognizer: UITapGestureRecognizer {
	private struct TargetActionPair {
		let target: AnyObject
		let action: Selector
	}

	private var targetActionPair: TargetActionPair?
	private var forceState: UIGestureRecognizerState = .ended

	fileprivate override var state: UIGestureRecognizerState {
		get { return forceState }
		set { self.state = newValue }
	}
	
	fileprivate override func addTarget(_ target: Any, action: Selector) {
		targetActionPair = TargetActionPair(target: target as AnyObject, action: action)
	}
	
	fileprivate func fireGestureEvent(_ state: UIGestureRecognizerState) {
		guard let targetAction = self.targetActionPair else { return }
		forceState = state
		_ = targetAction.target.perform(targetAction.action, with: self)
	}
}
