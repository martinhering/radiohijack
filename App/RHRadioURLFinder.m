//
//  RHRadioURLFinder.m
//  RadioHijack
//
//  Created by Martin Hering on 29.04.14.
//  Copyright (c) 2014 Vemedio. All rights reserved.
//

#import "RHRadioURLFinder.h"

@interface RHRadioURLFinder ()
@property (nonatomic, strong) NSOperationQueue* operationQueue;
@property (nonatomic, strong) NSMutableSet* urlsAlreadyChecked;
@end


@implementation RHRadioURLFinder

- (id) init
{
    if ((self = [super init])) {
        _operationQueue = [[NSOperationQueue alloc] init];
        _urlsAlreadyChecked = [[NSMutableSet alloc] init];
    }
    return self;
}

- (NSSet*) _pathExtensionsToIgnore
{
    return [NSSet setWithObjects:@"png", @"jpg", @"php", @"js", @"html", @"htm", @"css", @"jpeg", @"gif", @"ico", @"json", @"xml", @"asp", @"aspx", nil];
}

- (void) addRequest:(NSURLRequest*)request response:(NSHTTPURLResponse*)response
{
    NSURL* url = request.URL;
    NSString* pathExtension = [[url pathExtension] lowercaseString];
    if ([[self _pathExtensionsToIgnore] containsObject:pathExtension]) {
        //NSLog(@"filted url: %@ (%@)", request.URL, pathExtension);
        return;
    }

    //NSLog(@"%@ %@", request, response);
    
    NSDictionary* responseHeaders = [response allHeaderFields];
    NSString* contentType = responseHeaders[@"Content-Type"];
    
    RHURLResourceType type = RHURLResourceTypeNone;
    
    NSDictionary* mimeCodeType = @{@"application/xspf+xml" : @(RHURLResourceTypeXSPFPlaylist),
                                   @"audio/mpeg" : @(RHURLResourceTypeMPEGStream),
                                   @"audio/x-mpeg" : @(RHURLResourceTypeMPEGStream),
                                   @"application/vnd.apple.mpegurl" : @(RHURLResourceTypeHTTPStreamingPlaylist),
                                   @"audio/aac" : @(RHURLResourceTypeAACStream),
                                   @"audio/aacp" : @(RHURLResourceTypeAACStream),
                                   @"audio/x-aac" : @(RHURLResourceTypeAACStream),
                                   };
    
    type = [mimeCodeType[contentType] integerValue];

    if (type > RHURLResourceTypeNone && self.didFindRadioURL) {
        
        NSLog(@"%@", responseHeaders);
        
        self.didFindRadioURL(request.URL, type);
    }
    
}

@end
