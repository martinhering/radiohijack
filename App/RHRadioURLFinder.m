//
//  RHRadioURLFinder.m
//  RadioHijack
//
//  Created by Martin Hering on 29.04.14.
//  Copyright (c) 2014 Vemedio. All rights reserved.
//

#import "RHRadioURLFinder.h"
#import "Stream.h"


typedef NS_ENUM(NSInteger, RHContentType) {
	RHContentTypeNone                   = 0,
    RHContentTypeXSPFPlaylist           = (1 << 8) | 1,
    RHContentTypeHTTPStreamingPlaylist  = (2 << 8) | 1,
    RHContentTypeMPEGStream             = (1 << 8) | 0,
    RHContentTypeAACStream              = (2 << 8) | 0,
    RHContentTypeFlashStream            = (3 << 8) | 0,
};

typedef NS_ENUM(NSInteger, RHResponseType) {
    RHResponseTypeNone                  = 0,
    RHResponseTypeIcecast               = 1,
    RHResponseTypeStreamTheWorld        = 2,
    RHResponseTypeNacamar               = 3,
};

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
    return [NSSet setWithObjects:@"png", @"jpg", @"php", @"js", @"html", @"htm", @"css", @"jpeg", @"gif", @"ico", @"json", @"xml", @"asp", @"aspx", @"woff", nil];
}

- (NSSet*) _mimeCodesToIgnore
{
    return [NSSet setWithObjects:@"text/", @"image/", @"application/json", @"application/x-javascript", @"application/javascript", @"application/x-shockwave-flash", nil];
}

- (Stream*) _streamForIcecastResponse:(NSHTTPURLResponse*)response
{
    NSDictionary* headers = [response allHeaderFields];
    
    Stream* stream = [Stream new];
    stream.URL = response.URL;
    stream.name = headers[@"icy-name"];
    stream.slogan = headers[@"icy-description"];
    stream.genre = headers[@"icy-genre"];
    
    NSString* websiteURLString = headers[@"icy-url"];
    if (websiteURLString) {
        stream.websiteURL = [NSURL URLWithString:websiteURLString];
    }
    
    if ([headers[@"Content-Type"] rangeOfString:@"mpeg"].location != NSNotFound) {
        stream.format = RHStreamFormatMP3;
    }
    else if ([headers[@"Content-Type"] rangeOfString:@"aacp"].location != NSNotFound) {
        stream.format = RHStreamFormatHEAAC;
    }
    else if ([headers[@"Content-Type"] rangeOfString:@"aac"].location != NSNotFound || [headers[@"Content-Type"] rangeOfString:@"mp4"].location != NSNotFound) {
        stream.format = RHStreamFormatAAC;
    }
    
    NSString* audioInfo = headers[@"ice-audio-info"];
    if (audioInfo) {
        NSArray* audioInfoComponents = [audioInfo componentsSeparatedByString:@";"];
        for(NSString* audioInfoComponent in audioInfoComponents)
        {
            NSArray* audioInfoComponentKeyValuePair = [audioInfoComponent componentsSeparatedByString:@"="];
            if ([audioInfoComponentKeyValuePair count] < 2) {
                continue;
            }
            
            NSString* key = audioInfoComponentKeyValuePair[0];
            NSString* value = audioInfoComponentKeyValuePair[1];
            
            if ([key isEqualToString:@"ice-samplerate"]) {
                stream.samplesPerSecond = [value integerValue];
            }
            else if ([key isEqualToString:@"ice-bitrate"]) {
                stream.bitsPerSecond = [value integerValue]*1000;
            }
            else if ([key isEqualToString:@"ice-channels"]) {
                stream.channels = [value integerValue];
            }
        }
    }
    
    return stream;
}

- (NSURL*) _playlistURLForStreamTheWorldResponse:(NSHTTPURLResponse*)response
{
    NSString* identifier = [[response.URL path] substringFromIndex:1];
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"http://provisioning.streamtheworld.com/pls/%@.pls", identifier]];
    return url;
}





- (void) addRequest:(NSURLRequest*)request response:(NSHTTPURLResponse*)response
{
    assert(self.didFindStream != nil);
    
    NSURL* url = request.URL;
    NSString* pathExtension = [[url pathExtension] lowercaseString];
    if ([[self _pathExtensionsToIgnore] containsObject:pathExtension]) {
        NSLog(@"filted url: %@ (%@)", request.URL, pathExtension);
        return;
    }

    //NSLog(@"%@ %@", request, response);
    
    NSDictionary* responseHeaders = [response allHeaderFields];
    NSSet* headerKeys = [NSSet setWithArray:[responseHeaders allKeys]];
    
    NSString* responseContentType = responseHeaders[@"Content-Type"];
    
    if ([[self _mimeCodesToIgnore] containsPrefixOfString:responseContentType]) {
        NSLog(@"filted url: %@ (%@, %@, %@)", request.URL, responseContentType, [request HTTPMethod], [request allHTTPHeaderFields]);
        return;
    }
    
    // get content type
    NSDictionary* mimeCodeType = @{@"application/xspf+xml" :            @(RHContentTypeXSPFPlaylist),
                                   @"application/vnd.apple.mpegurl" :   @(RHContentTypeHTTPStreamingPlaylist),
                                   
                                   @"audio/mpeg" :                      @(RHContentTypeMPEGStream),
                                   @"audio/x-mpeg" :                    @(RHContentTypeMPEGStream),
                                   @"audio/aac" :                       @(RHContentTypeAACStream),
                                   @"audio/aacp" :                      @(RHContentTypeAACStream),
                                   @"audio/x-aac" :                     @(RHContentTypeAACStream),
                                   @"audio/mp4" :                       @(RHContentTypeAACStream),
                                   
                                   @"application/flv" :                 @(RHContentTypeFlashStream)
                                   };
    
    
    RHContentType contentType = [mimeCodeType[responseContentType] integerValue];
    
    // get response type
    RHResponseType responseType = RHResponseTypeNone;
    if ([[response.URL host] rangeOfString:@"live.streamtheworld.com"].location != NSNotFound) {
        responseType = RHResponseTypeStreamTheWorld;
    }
    else if ([[response.URL host] rangeOfString:@"mdn.newmedia.nacamar.net"].location != NSNotFound) {
        responseType = RHResponseTypeNacamar;
    }
    else if ([headerKeys containsObjectWithPrefix:@"icy-"]) {
        responseType = RHResponseTypeIcecast;
    }
    
    
    
    Stream* stream;
    
    if (contentType > RHContentTypeNone && responseType > RHResponseTypeNone)
    {
        if (responseType == RHResponseTypeStreamTheWorld && contentType == RHContentTypeFlashStream)
        {
            NSURL* playlistURL = [self _playlistURLForStreamTheWorldResponse:response];
            stream = [Stream new];
            stream.name = @"PLS file";
            stream.URL = playlistURL;
        }
        
        else if (responseType == RHResponseTypeNacamar)
        {
            stream = [self _streamForIcecastResponse:response];
            // rewrite nacamar URL
            if ([[response.URL absoluteString] rangeOfString:@"token="].location != NSNotFound) {
                NSMutableString* urlString = [[response.URL absoluteString] mutableCopy];
                [urlString replaceOccurrencesOfRegex:@"mdn.newmedia.nacamar.net/(.*?)/" withString:@"mdn.newmedia.nacamar.net/ps-$1/" options:NSRegularExpressionCaseInsensitive];
                [urlString replaceOccurrencesOfRegex:@"\\?token=.*" withString:@"" options:NSRegularExpressionCaseInsensitive];
                stream.URL = [NSURL URLWithString:urlString];
            }
        }
        
        else if (responseType == RHResponseTypeIcecast)
        {
            stream = [self _streamForIcecastResponse:response];
        }
    }
    
    if (stream) {
        self.didFindStream(stream);
    }
    
    else
    {
        NSLog(@"unknown request: %@, response: %@", request, response);
    }
}

@end


