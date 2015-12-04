//  Copyright (c) 2015 GitHub. All rights reserved.

#import "RACDynamicPropertySuperclass.h"

@interface RACDynamicPropertySuperclass ()

@property id value;
@property id rac_value;

@end

@implementation RACDynamicPropertySuperclass

- (id)value {
	return self.rac_value;
}

- (void)setValue:(id)value {
	self.rac_value = value;
}

@end
