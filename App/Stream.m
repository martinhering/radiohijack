//
//  Stream.m
//  RadioHijack
//
//  Created by Martin Hering on 30.04.14.
//
//

#import "Stream.h"

@implementation Stream

- (NSString*) description
{
    return [NSString stringWithFormat:@"<%@:0x%llu URL='%@', name='%@'>", NSStringFromClass([self class]), (unsigned long long)self, self.URL, self.name];
}
@end




@implementation RHStreamFormatValueTransformer

+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(NSNumber*)value
{
    if (!value) {
        return nil;
    }
    
    RHStreamFormat n = [value integerValue];
    
    switch (n) {
        case RHStreamFormatMP3:
            return @"MP3";
        case RHStreamFormatAAC:
            return @"AAC";
        case RHStreamFormatHEAAC:
            return @"HE-AAC";
        default:
            break;
    }
    
    return @"unknown";
}


@end

