#include <Foundation/Foundation.h>

@interface Common : NSObject

// For a given command selector, return the associated authorization right name.
+ (NSString *)authorizationRightForCommand:(SEL)command;

// Set up the default authorization rights in the authorization database.
+ (void)setupAuthorizationRights:(AuthorizationRef)authRef;

@end


#define kHelperToolMachServiceName @"com.vemedio.RadioHijack.Sniffer"

@protocol SnifferProtocol
@required
- (void)connectWithEndpointReply:(void(^)(NSXPCListenerEndpoint * endpoint))reply;
- (void)getVersionWithReply:(void(^)(NSString * version))reply;

@end
