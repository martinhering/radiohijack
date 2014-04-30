//
//  Stream.h
//  RadioHijack
//
//  Created by Martin Hering on 30.04.14.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, RHStreamFormat) {
    RHStreamFormatNone = 0,
    RHStreamFormatMP3,
    RHStreamFormatAAC,
    RHStreamFormatHEAAC
};



@interface Stream : NSObject
@property (nonatomic, strong) NSURL* URL;
@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) NSString* slogan;
@property (nonatomic, strong) NSString* genre;
@property (nonatomic, strong) NSURL* websiteURL;
@property (nonatomic, assign) NSInteger bitsPerSecond;
@property (nonatomic, assign) NSInteger samplesPerSecond;
@property (nonatomic, assign) NSInteger channels;
@property (nonatomic, assign) RHStreamFormat format;
@end


@interface RHStreamFormatValueTransformer : NSValueTransformer

@end

