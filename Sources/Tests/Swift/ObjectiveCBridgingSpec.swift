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
			var scheduler: DateSchedulerType!

			beforeEach {
				originalScheduler = RACTestScheduler()
				scheduler = originalScheduler as DateSchedulerType
			}

			it("gives current date") {
				expect(scheduler.currentDate).to(beCloseTo(NSDate()))
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
					subscriber.sendNext(subscriptions++)
					subscriber.sendCompleted()

					return nil
				}

				let producer = racSignal.toSignalProducer().map { $0 as! Int }

				expect((producer.single())?.value).to(equal(0))
				expect((producer.single())?.value).to(equal(1))
				expect((producer.single())?.value).to(equal(2))
			}

			it("should forward errors")	{
				let error = TestError.Default as NSError

				let racSignal = RACSignal.error(error)
				let producer = racSignal.toSignalProducer()
				let result = producer.last()

				expect(result?.error).to(equal(error))
			}
		}

		describe("toRACSignal") {
			let key = "TestKey"
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
						expect(lastValue).to(equal(number))
					}

					expect(didComplete).to(beFalse())
					observer.sendCompleted()
					expect(didComplete).to(beTrue())
				}

				it("should convert errors to NSError") {
					let (signal, observer) = Signal<AnyObject, TestError>.pipe()
					let racSignal = signal.toRACSignal()

					let expectedError = TestError.Error2
					var error: NSError?

					racSignal.subscribeError {
						error = $0
						return
					}

					observer.sendFailed(expectedError)
					expect(error).to(equal(expectedError as NSError))
				}
				
				it("should maintain userInfo on NSError") {
					let (signal, observer) = Signal<AnyObject, NSError>.pipe()
					let racSignal = signal.toRACSignal()
					
					var error: NSError?
					
					racSignal.subscribeError {
						error = $0
						return
					}
					
					observer.sendFailed(testNSError)
					
					let userInfoValue = error?.userInfo[key] as? String
					expect(userInfoValue).to(equal(userInfo[key]))
				}
			}

			describe("on a SignalProducer") {
				it("should start once per subscription") {
					var subscriptions = 0

					let producer = SignalProducer<NSNumber, NoError>.attempt {
						return .Success(subscriptions++)
					}
					let racSignal = producer.toRACSignal()

					expect(racSignal.first() as? NSNumber).to(equal(0))
					expect(racSignal.first() as? NSNumber).to(equal(1))
					expect(racSignal.first() as? NSNumber).to(equal(2))
				}

				it("should convert errors to NSError") {
					let producer = SignalProducer<AnyObject, TestError>(error: .Error1)
					let racSignal = producer.toRACSignal().materialize()

					let event = racSignal.first() as? RACEvent
					expect(event?.error).to(equal(TestError.Error1 as NSError))
				}
				
				it("should maintain userInfo on NSError") {
					let producer = SignalProducer<AnyObject, NSError>(error: testNSError)
					let racSignal = producer.toRACSignal().materialize()
					
					let event = racSignal.first() as? RACEvent
					let userInfoValue = event?.error.userInfo[key] as? String
					expect(userInfoValue).to(equal(userInfo[key]))
				}
			}
		}

		describe("RACCommand.toAction") {
			var command: RACCommand!
			var results: [Int] = []

			var enabledSubject: RACSubject!
			var enabled = false

			var action: Action<AnyObject?, AnyObject?, NSError>!

			beforeEach {
				enabledSubject = RACSubject()
				results = []

				command = RACCommand(enabled: enabledSubject) { (input: AnyObject?) -> RACSignal! in
					let inputNumber = input as! Int
					return RACSignal.`return`(inputNumber + 1)
				}

				expect(command).notTo(beNil())

				command.enabled.subscribeNext { enabled = $0 as! Bool }
				expect(enabled).to(beTruthy())

				command.executionSignals.flatten().subscribeNext { results.append($0 as! Int) }
				expect(results).to(equal([]))

				action = command.toAction()
			}

			it("should reflect the enabledness of the command") {
				expect(action.enabled.value).to(beTruthy())

				enabledSubject.sendNext(false)
				expect(enabled).toEventually(beFalsy())
				expect(action.enabled.value).to(beFalsy())
			}

			it("should execute the command once per start()") {
				let producer = action.apply(0)
				expect(results).to(equal([]))

				producer.start()
				expect(results).toEventually(equal([ 1 ]))

				producer.start()
				expect(results).toEventually(equal([ 1, 1 ]))

				let otherProducer = action.apply(2)
				expect(results).to(equal([ 1, 1 ]))

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

			var command: RACCommand!
			var enabled = false
			
			beforeEach {
				results = []
				enabledProperty = MutableProperty(true)

				action = Action(enabledIf: enabledProperty) { input in
					let inputNumber = input as! Int
					return SignalProducer(value: "\(inputNumber + 1)")
				}

				expect(action.enabled.value).to(beTruthy())

				action.values.observeNext { results.append($0) }

				command = toRACCommand(action)
				expect(command).notTo(beNil())

				command.enabled.subscribeNext { enabled = $0 as! Bool }
				expect(enabled).to(beTruthy())
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
					expect(results).to(equal([ "1" ]))

					try signal.asynchronouslyWaitUntilCompleted()
					expect(results).to(equal([ "1" ]))

					try command.execute(2).asynchronouslyWaitUntilCompleted()
					expect(results).to(equal([ "1", "3" ]))
				} catch {
					XCTFail("Failed to wait for completion")
				}
			}
		}
	}
}
