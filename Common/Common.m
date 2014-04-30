#import "Common.h"

#import "HelperTool.h"

@implementation Common

// +commandInfo returns a dictionary that represents everything we need to know about the 
// authorized commands supported by the app.  Each dictionary key is the string form of 
// the command selector.  The corresponding object is a dictionary that contains three items:
//
// o kCommandKeyAuthRightName is the name of the authorization right itself.  This is used by 
//   both the app (when creating rights and when pre-authorizing rights) and by the tool 
//   (when doing the final authorization check).
//
// o kCommandKeyAuthRightDefault is the default right specification, used by the app to when 
//   it needs to create the default right specification.  This is commonly a string contacting 
//   a rule a name, but it can potentially be more complex.  See the discussion of the 
//   rightDefinition parameter of AuthorizationRightSet.
//
// o kCommandKeyAuthRightDesc is a user-visible description of the right.  This is used by the 
//   app when it needs to create the default right specification.  Actually, string is used 
//   to look up a localized version of the string in "Common.strings".
//
//   The kCommandKeyAuthRightDesc strings here contain EBAS as as shortcut for 
//   EvenBetterAuthorizationSample.  However, the values in "Common.strings" contain the fully 
//   expanded name, which allows you to see whether localization is working properly.
//
//   These strings are also surrounded by NSLocalizedString, which makes it easy to use 
//   <x-man-page://1/genstrings> to create an initial "Common.strings".

static NSString * kCommandKeyAuthRightName    = @"authRightName";
static NSString * kCommandKeyAuthRightDefault = @"authRightDefault";
static NSString * kCommandKeyAuthRightDesc    = @"authRightDescription";

+ (NSDictionary *)commandInfo
{
    static dispatch_once_t sOnceToken;
    static NSDictionary *  sCommandInfo;
    
    dispatch_once(&sOnceToken, ^{
        sCommandInfo = @{
                         
                         
            /*
            NSStringFromSelector(@selector(readLicenseKeyAuthorization:withReply:)) : @{
                kCommandKeyAuthRightName    : @"com.example.apple-samplecode.EBAS.readLicenseKey", 
                kCommandKeyAuthRightDefault : @kAuthorizationRuleClassAllow, 
                kCommandKeyAuthRightDesc    : @"EBAS is trying to read its license key."
            },
            NSStringFromSelector(@selector(writeLicenseKey:authorization:withReply:)) : @{
                kCommandKeyAuthRightName    : @"com.example.apple-samplecode.EBAS.writeLicenseKey", 
                kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin, 
                kCommandKeyAuthRightDesc    : @"EBAS is trying to write its license key."
            },
            NSStringFromSelector(@selector(bindToLowNumberPortAuthorization:withReply:)) : @{
                kCommandKeyAuthRightName    : @"com.example.apple-samplecode.EBAS.startWebService", 
                kCommandKeyAuthRightDefault : @kAuthorizationRuleClassAllow, 
                kCommandKeyAuthRightDesc    : @"EBAS is trying to start its web service."
            }
             
             */
        };
    });
    return sCommandInfo;
}

+ (NSString *)authorizationRightForCommand:(SEL)command
    // See comment in header.
{
    return [self commandInfo][NSStringFromSelector(command)][kCommandKeyAuthRightName];
}

+ (void)enumerateRightsUsingBlock:(void (^)(NSString * authRightName, id authRightDefault, NSString * authRightDesc))block
    // Calls the supplied block with information about each known authorization right..
{
    [self.commandInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        #pragma unused(key)
        #pragma unused(stop)
        NSDictionary *  commandDict;
        NSString *      authRightName;
        id              authRightDefault;
        NSString *      authRightDesc;
        
        // If any of the following asserts fire it's likely that you've got a bug 
        // in sCommandInfo.
        
        commandDict = (NSDictionary *) obj;
        assert([commandDict isKindOfClass:[NSDictionary class]]);

        authRightName = [commandDict objectForKey:kCommandKeyAuthRightName];
        assert([authRightName isKindOfClass:[NSString class]]);

        authRightDefault = [commandDict objectForKey:kCommandKeyAuthRightDefault];
        assert(authRightDefault != nil);

        authRightDesc = [commandDict objectForKey:kCommandKeyAuthRightDesc];
        assert([authRightDesc isKindOfClass:[NSString class]]);

        block(authRightName, authRightDefault, authRightDesc);
    }];
}

+ (void)setupAuthorizationRights:(AuthorizationRef)authRef
    // See comment in header.
{
    assert(authRef != NULL);
    [Common enumerateRightsUsingBlock:^(NSString * authRightName, id authRightDefault, NSString * authRightDesc) {
        OSStatus    blockErr;
        
        // First get the right.  If we get back errAuthorizationDenied that means there's 
        // no current definition, so we add our default one.
        
        blockErr = AuthorizationRightGet([authRightName UTF8String], NULL);
        if (blockErr == errAuthorizationDenied) {
            blockErr = AuthorizationRightSet(
                authRef,                                    // authRef
                [authRightName UTF8String],                 // rightName
                (__bridge CFTypeRef) authRightDefault,      // rightDefinition
                (__bridge CFStringRef) authRightDesc,       // descriptionKey
                NULL,                                       // bundle (NULL implies main bundle)
                CFSTR("Common")                             // localeTableName
            );
            assert(blockErr == errAuthorizationSuccess);
        } else { 
            // A right already exists (err == noErr) or any other error occurs, we 
            // assume that it has been set up in advance by the system administrator or
            // this is the second time we've run.  Either way, there's nothing more for 
            // us to do.
        }
    }];
}

@end
