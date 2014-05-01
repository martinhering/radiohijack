//
//  Foundation+Extentions.m
//  RadioHijack
//
//  Created by Martin Hering on 01.05.14.
//
//

#import "Foundation+Extentions.h"


@implementation NSSet (RadioHijack)

- (BOOL) containsPrefixOfString:(NSString*)string
{
    for(NSString* element in self) {
        if ([string hasPrefix:element]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL) containsObjectWithPrefix:(NSString*)string
{
    for(NSString* element in self) {
        if ([element hasPrefix:string]) {
            return YES;
        }
    }
    
    return NO;
}

@end


@implementation NSMutableString (RadioHijack)

- (NSUInteger) replaceOccurrencesOfRegex:(NSString*)pattern withString:(NSString*)replacement
{
    return [self replaceOccurrencesOfRegex:pattern withString:replacement options:0];
}

- (NSUInteger) replaceOccurrencesOfRegex:(NSString*)pattern withString:(NSString*)replacement options:(NSRegularExpressionOptions)options
{
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:&error];
    NSUInteger numberOfMatches = [regex replaceMatchesInString:self options:0 range:NSMakeRange(0, [self length]) withTemplate:replacement];
    return numberOfMatches;
}

@end

