//
//  ObjectiveCBridgingSpec.swift
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2015-01-23.
//  Copyright (c) 2015 GitHub. All rights reserved.
//

import Result
import Nimble
import Quick
import ReactiveCocoa
import XCTest

class ObjectiveCBridgingSpec: QuickSpec {
	override func spec() {
		describe("RACScheduler") {
			var originalScheduler: RACTestScheduler!
			var scheduler: DateSchedulerProtocol!

			beforeEach {
				originalScheduler = RACTestScheduler()
				scheduler = originalScheduler as DateSchedulerProtocol
			}

			it("gives current date") {
				expect(scheduler.currentDate).to(beCloseTo(Date(), within: 0.0002))
			}

			it("schedules actions") {
				var actionRan: Bool = false

				scheduler.schedule {
					actionRan = true
				}

				expect(actionRan) == false
				originalScheduler.step()
				expect(actionRan) == true
			}

			it("does not invoke action if disposed") {
				var actionRan: Bool = false

				let disposable: Disposable? = scheduler.schedule {
					actionRan = true
				}

				expect(actionRan) == false
				disposable!.dispose()
				originalScheduler.step()
				expect(actionRan) == false
			}
		}

		describe("RACSignal.toSignalProducer") {
			it("should subscribe once per start()") {
				var subscriptions = 0

				let racSignal = RACSignal.createSignal { subscriber in
					subscriber.sendNext(subscriptions)
					subscriber.sendCompleted()

					subscriptions += 1

					return nil
				}

				let producer = racSignal.toSignalProducer().map { $0 as! Int }

				expect((producer.single())?.value) == 0
				expect((producer.single())?.value) == 1
				expect((producer.single())?.value) == 2
			}

			it("should forward errors")	{
				let error = TestError.default as NSError

				let racSignal = RACSignal.error(error)
				let producer = racSignal.toSignalProducer()
				let result = producer.last()

				expect(result?.error) == error
			}
		}

		describe("toRACSignal") {
			let key = NSLocalizedDescriptionKey
			let userInfo: [String: String] = [key: "TestValue"]
			let testNSError = NSError(domain: "TestDomain", code: 1, userInfo: userInfo)
			describe("on a Signal") {
				it("should forward events") {
					let (signal, observer) = Signal<NSNumber, NoError>.pipe()
					let racSignal = signal.toRACSignal()

					var lastValue: NSNumber?
					var didComplete = false

					racSignal.subscribeNext({ number in
						lastValue = number as? NSNumber
					}, completed: {
						didComplete = true
					})

					expect(lastValue).to(beNil())

					for number in [1, 2, 3] {
						observer.sendNext(number)
						expect(lastValue) == number
					}

					expect(didComplete) == false
					observer.sendCompleted()
					expect(didComplete) == true
				}

				it("should convert errors to NSError") {
					let (signal, observer) = Signal<AnyObject, TestError>.pipe()
					let racSignal = signal.toRACSignal()

					let expectedError = TestError.error2
					var error: Error?

					racSignal.subscribeError {
						error = $0
						return
					}

					observer.sendFailed(expectedError)
					expect(error) == expectedError as NSError
				}
				
				it("should maintain userInfo on NSError") {
					let (signal, observer) = Signal<AnyObject, NSError>.pipe()
					let racSignal = signal.toRACSignal()
					
					var error: String?
					
					racSignal.subscribeError {
						error = $0?.localizedDescription
						return
					}
					
					observer.sendFailed(testNSError)

					expect(error) == userInfo[key]
				}
			}

			describe("on a SignalProducer") {
				it("should start once per subscription") {
					var subscriptions = 0

					let producer = SignalProducer<NSNumber, NoError>.attempt {
						defer {
							subscriptions += 1
						}

						return .success(subscriptions)
					}
					let racSignal = producer.toRACSignal()

					expect(racSignal.first() as? NSNumber) == 0
					expect(racSignal.first() as? NSNumber) == 1
					expect(racSignal.first() as? NSNumber) == 2
				}

				it("should convert errors to NSError") {
					let producer = SignalProducer<AnyObject, TestError>(error: .error1)
					let racSignal = producer.toRACSignal().materialize()

					let event = racSignal.first() as? RACEvent
					expect(event?.error) == TestError.error1 as NSError
				}
				
				it("should maintain userInfo on NSError") {
					let producer = SignalProducer<AnyObject, NSError>(error: testNSError)
					let racSignal = producer.toRACSignal().materialize()
					
					let event = racSignal.first() as? RACEvent
					let userInfoValue = event?.error?.localizedDescription
					expect(userInfoValue) == userInfo[key]
				}
			}
		}

		describe("toAction") {
			var command: RACCommand<AnyObject>!
			var results: [Int] = []

			var enabledSubject: RACSubject!
			var enabled = false

			var action: Action<AnyObject?, AnyObject?, NSError>!

			beforeEach {
				enabledSubject = RACSubject()
				results = []

				command = RACCommand(enabled: enabledSubject) { (input: AnyObject?) -> RACSignal in
					let inputNumber = input as! Int
					return RACSignal.`return`(inputNumber + 1)
				}

				expect(command).notTo(beNil())

				command.enabled.subscribeNext { enabled = $0 as! Bool }
				expect(enabled) == true

				command.executionSignals.flatten().subscribeNext { results.append($0 as! Int) }
				expect(results) == []

				action = bridgedAction(from: command)
			}

			it("should reflect the enabledness of the command") {
				expect(action.isEnabled.value) == true

				enabledSubject.sendNext(false)
				expect(enabled).toEventually(beFalsy())
				expect(action.isEnabled.value) == false
			}

			it("should execute the command once per start()") {
				let producer = action.apply(0)
				expect(results) == []

				producer.start()
				expect(results).toEventually(equal([ 1 ]))

				producer.start()
				expect(results).toEventually(equal([ 1, 1 ]))

				let otherProducer = action.apply(2)
				expect(results) == [ 1, 1 ]

				otherProducer.start()
				expect(results).toEventually(equal([ 1, 1, 3 ]))

				producer.start()
				expect(results).toEventually(equal([ 1, 1, 3, 1 ]))
			}
		}

		describe("toRACCommand") {
			var action: Action<AnyObject?, NSString, TestError>!
			var results: [NSString] = []

			var enabledProperty: MutableProperty<Bool>!

			var command: RACCommand<AnyObject>!
			var enabled = false
			
			beforeEach {
				results = []
				enabledProperty = MutableProperty(true)

				action = Action(enabledIf: enabledProperty) { input in
					let inputNumber = input as! Int
					return SignalProducer(value: "\(inputNumber + 1)")
				}

				expect(action.isEnabled.value) == true

				action.values.observeNext { results.append($0) }

				command = action.toRACCommand()
				expect(command).notTo(beNil())

				command.enabled.subscribeNext { enabled = $0 as! Bool }
				expect(enabled) == true
			}

			it("should reflect the enabledness of the action") {
				enabledProperty.value = false
				expect(enabled).toEventually(beFalsy())

				enabledProperty.value = true
				expect(enabled).toEventually(beTruthy())
			}

			it("should apply and start a signal once per execution") {
				let signal = command.execute(0)

				do {
					try signal.asynchronouslyWaitUntilCompleted()
					expect(results) == [ "1" ]

					try signal.asynchronouslyWaitUntilCompleted()
					expect(results) == [ "1" ]

					try command.execute(2).asynchronouslyWaitUntilCompleted()
					expect(results) == [ "1", "3" ]
				} catch {
					XCTFail("Failed to wait for completion")
				}
			}
		}
	}
}
