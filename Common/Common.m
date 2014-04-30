#import "Common.h"
#import "HelperTool.h"

@implementation Common

static NSString * kCommandKeyAuthRightName    = @"authRightName";
static NSString * kCommandKeyAuthRightDefault = @"authRightDefault";
static NSString * kCommandKeyAuthRightDesc    = @"authRightDescription";

+ (NSDictionary *)commandInfo
{
    static dispatch_once_t sOnceToken;
    static NSDictionary *  sCommandInfo;
    
    dispatch_once(&sOnceToken, ^{
        sCommandInfo = @{
                         
                         NSStringFromSelector(@selector(startSniffingAuthorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.vemedio.RadioHijack.Sniffer.start",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleClassAllow,
                                 kCommandKeyAuthRightDesc    : @"RadioHijack is trying to start sniffing network interfaces."
                                 },
                         
                         NSStringFromSelector(@selector(stopSniffingAuthorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.vemedio.RadioHijack.Sniffer.stop",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleClassAllow,
                                 kCommandKeyAuthRightDesc    : @"RadioHijack is trying to stop sniffing network interfaces."
                                 },
                         
                         NSStringFromSelector(@selector(getQueuedHTTPDataAuthorization:withReply:)) : @{
                                 kCommandKeyAuthRightName    : @"com.vemedio.RadioHijack.Sniffer.getData",
                                 kCommandKeyAuthRightDefault : @kAuthorizationRuleClassAllow,
                                 kCommandKeyAuthRightDesc    : @"RadioHijack is trying to get queued data."
                                 },
        };
    });
    return sCommandInfo;
}


+ (NSString *)authorizationRightForCommand:(SEL)command
{
    return [self commandInfo][NSStringFromSelector(command)][kCommandKeyAuthRightName];
}

+ (void)enumerateRightsUsingBlock:(void (^)(NSString * authRightName, id authRightDefault, NSString * authRightDesc))block
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
{
    assert(authRef != NULL);
    [Common enumerateRightsUsingBlock:^(NSString * authRightName, id authRightDefault, NSString * authRightDesc) {
        OSStatus    blockErr;
        
        // First get the right.  If we get back errAuthorizationDenied that means there's 
        // no current definition, so we add our default one.
        
        blockErr = AuthorizationRightGet([authRightName UTF8String], NULL);
        if (blockErr == errAuthorizationDenied) {
            blockErr = AuthorizationRightSet(
                authRef,
                [authRightName UTF8String],
                (__bridge CFTypeRef) authRightDefault,
                (__bridge CFStringRef) authRightDesc,
                NULL,
                NULL
            );
            assert(blockErr == errAuthorizationSuccess);
        }
    }];
}

@end
