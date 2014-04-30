//
//  RHRadioURLFinder.h
//  RadioHijack
//
//  Created by Martin Hering on 29.04.14.
//  Copyright (c) 2014 Vemedio. All rights reserved.
//

#import <Foundation/Foundation.h>



@class Stream;


@interface RHRadioURLFinder : NSObject

@property (nonatomic, copy) void (^didFindStream)(Stream* stream);

- (void) addRequest:(NSURLRequest*)request response:(NSHTTPURLResponse*)response;
@end
