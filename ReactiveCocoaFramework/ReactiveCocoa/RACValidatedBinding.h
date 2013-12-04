//
//  RACValidatedBinding.h
//  ReactiveCocoa
//
//  Created by Justin Spahr-Summers on 2013-12-03.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// Represents a kind of two-way binding, where one side must always validate its
// values.
//
// For example, when binding a view to its model, the model's values should
// always be honored as-is, while the values coming from the view (and, by
// extension, the user) must be validated before taking effect.
@interface RACValidatedBinding : NSObject

// The final, validated values for this binding.
//
// In the example of a view-to-model binding, this signal will consist of the
// model's values.
@property RACSignal *values;

// Validates proposed values from one side of the binding.
//
// If a value passes validation, it may be transformed as well, before finally
// being sent on `values`.
//
// In the example of a view-to-model binding, this generator will accept the
// view's values, and create a signal that validates them (sending an error if
// validation fails), then updates the value on the model.
@property RACSignalGenerator *validator;

@end
