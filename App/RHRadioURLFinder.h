//
//  RHRadioURLFinder.h
//  RadioHijack
//
//  Created by Martin Hering on 29.04.14.
//  Copyright (c) 2014 Vemedio. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, RHURLResourceType) {
	RHURLResourceTypeNone,
    RHURLResourceTypeXSPFPlaylist,
    RHURLResourceTypeMPEGStream,
    RHURLResourceTypeHTTPStreamingPlaylist,
    RHURLResourceTypeAACStream,
};


@interface RHRadioURLFinder : NSObject

@property (nonatomic, copy) void (^didFindRadioURL)(NSURL* url, RHURLResourceType type);

- (void) addRequest:(NSURLRequest*)request response:(NSHTTPURLResponse*)response;
@end
