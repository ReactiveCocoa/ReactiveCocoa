import ReactiveSwift
import ReactiveCocoa
import Quick
import Nimble
import enum Result.NoError

class ObserverSpec: QuickSpec {
	override func spec() {
		typealias SignalType = Signal<Void, NoError>
		
		var signal: SignalType!
		weak var _signal: SignalType?
		
		var observer: SignalType.Observer!
		weak var _observer: SignalType.Observer?
		
		beforeEach {
			let pipe = SignalType.pipe()
			signal = pipe.output
			observer = pipe.input
			
			_signal = signal
			_observer = observer
		}
		
		afterEach {
			signal = nil
			observer = nil
			expect(_signal).to(beNil())
			expect(_observer).to(beNil())
		}
		
		it("should accept changes from bindings") {
			let (pipeSignal, pipeObserver) = SignalType.pipe()
			
			observer <~ pipeSignal

			waitUntil(action: { done in
				signal.take(first: 1).observeValues {
					done()
				}
				pipeObserver.send(value: ())
			})
		}
	}
}
