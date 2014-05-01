//
//  Foundation+Extentions.h
//  RadioHijack
//
//  Created by Martin Hering on 01.05.14.
//
//



@interface NSSet (RadioHijack)
- (BOOL) containsPrefixOfString:(NSString*)string;
- (BOOL) containsObjectWithPrefix:(NSString*)string;
@end

@interface NSMutableString (RadioHijack)
- (NSUInteger) replaceOccurrencesOfRegex:(NSString*)pattern withString:(NSString*)replacement;
- (NSUInteger) replaceOccurrencesOfRegex:(NSString*)pattern withString:(NSString*)replacement options:(NSRegularExpressionOptions)options;
@end

