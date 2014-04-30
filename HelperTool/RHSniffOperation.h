//
//  RHSniffOperation.h
//  RadioHijack
//
//  Created by Martin Hering on 29.04.14.
//  Copyright (c) 2014 Vemedio. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RHSniffOperation : NSOperation

+ (NSSet*) activeNetworkInterfaces;

- (id) initWithNetworkInterface:(NSString*)networkInterface;


@property (nonatomic, copy) void (^didReceiveHTTPRequestResponse)(NSURLRequest* request, NSHTTPURLResponse* response);
@end
