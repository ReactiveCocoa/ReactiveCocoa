//
//  NSTextField.swift
//  Rex
//
//  Created by Yury Lapitsky on 7/8/15.
//  Copyright (c) 2015 Neil Pankey. All rights reserved.
//

import Foundation
import ReactiveCocoa
import AppKit

extension NSTextField {
    /// Producer will forward all text changes related to current NSTextField
    public var rex_stringValueChanged : SignalProducer <String, NoError> {
        return SignalProducer(values: [self.rex_stringValueChangedFromCode, self.rex_stringValueChangedFromUI]) |> flatten(FlattenStrategy.Merge)
    }
    
    public var rex_stringValueChangedFromCode : SignalProducer<String, NoError> {
        let signalProducer : SignalProducer = self.rac_signalForSelector(Selector("setStringValue:")).toSignalProducer()
        return signalProducer
            |> map { value in
                let tuple = value as? RACTuple ?? RACTuple()
                if let first = tuple.first as? String {
                    return first
                }
                else {
                    return ""
                }
            }
            |> catch() { _ in SignalProducer<String, NoError>.empty }
    }
    
    public var rex_stringValueChangedFromUI: SignalProducer<String, NoError> {
        return self.rac_textSignal().toSignalProducer()
            |> flatMap(FlattenStrategy.Merge) { stringValue in
                return SignalProducer<String, NSError> { observer, disposable in
                    let stringValue = stringValue as? String ?? ""
                    sendNext(observer, stringValue)
                    sendCompleted(observer)
                }
            }
            |> catch() { _ in SignalProducer<String, NoError>.empty }
    }
}