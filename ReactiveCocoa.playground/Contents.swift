//: Playground - noun: a place where people can play

import Result
import ReactiveCocoa

SignalProducer<Int, NoError>(value: 20).filter { $0 > 10 }.map(String.init).startWithNext { val in
    print(val)
}
