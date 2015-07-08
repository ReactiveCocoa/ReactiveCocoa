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
    public var rex_textChanged : SignalProducer <String, NoError> {
        return SignalProducer(values: [rex_textChangedOnSelector, rex_textChangedOnNotification]) |> flatten(FlattenStrategy.Merge)
    }
    
    private var rex_textChangedOnSelector : SignalProducer<String, NoError> {
        let signalProducer : SignalProducer = self.rac_signalForSelector("setStringValue:").toSignalProducer()
        return signalProducer
            |> map { next in
                if let tuple = next as? RACTuple, text = tuple.first as? String {
                    return text
                } else {
                    return ""
                }
            }
            |> ignoreError
    }
    
    private var rex_textChangedOnNotification: SignalProducer<String, NoError> {
        return self.rac_textSignal().toSignalProducer()
            |> map { next in
                precondition(next == nil || next is String)
                
                return next as? String ?? ""
            }
            |> ignoreError
    }
}