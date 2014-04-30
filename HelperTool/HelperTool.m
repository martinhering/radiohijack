

#import "HelperTool.h"

#import "Common.h"

#include <sys/socket.h>
#include <netinet/in.h>
#include <errno.h>

@interface HelperTool () <NSXPCListenerDelegate, SnifferProtocol>
@property (atomic, strong, readwrite) NSXPCListener* listener;
@end

@implementation HelperTool

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        _listener = [[NSXPCListener alloc] initWithMachServiceName:kHelperToolMachServiceName];
        _listener.delegate = self;
        
        [_listener resume];
        
        [self updateInactivityTimer];
    }
    return self;
}

#pragma mark -

- (void) _exitAfterInactivity
{
    exit(0);
}

- (void) updateInactivityTimer
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_exitAfterInactivity) object:nil];
    [self performSelector:@selector(_exitAfterInactivity) withObject:nil afterDelay:60];
}

#pragma mark -

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    assert(listener == self.listener);
    assert(newConnection != nil);

    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(SnifferProtocol)];
    newConnection.exportedObject = self;
    [newConnection resume];
    
    return YES;
}

- (NSError *)checkAuthorization:(NSData *)authData command:(SEL)command
{
    NSError *                   error;
    OSStatus                    err;
    OSStatus                    junk;
    AuthorizationRef            authRef;

    assert(command != nil);
    
    authRef = NULL;

    // First check that authData looks reasonable.
    error = nil;
    if ( (authData == nil) || ([authData length] != sizeof(AuthorizationExternalForm)) ) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
    }
    
    
    // Create an authorization ref from that the external form data contained within.
    
    if (error == nil) {
        err = AuthorizationCreateFromExternalForm([authData bytes], &authRef);
        
        // Authorize the right associated with the command.
        if (err == errAuthorizationSuccess) {
            AuthorizationItem   oneRight = { NULL, 0, NULL, 0 };
            AuthorizationRights rights   = { 1, &oneRight };

            oneRight.name = [[Common authorizationRightForCommand:command] UTF8String];
            assert(oneRight.name != NULL);
            
            err = AuthorizationCopyRights(
                authRef,
                &rights,
                NULL,
                kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed,
                NULL
            );
        }
        if (err != errAuthorizationSuccess) {
            error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
        }
    }

    if (authRef != NULL) {
        junk = AuthorizationFree(authRef, 0);
        assert(junk == errAuthorizationSuccess);
    }

    return error;
}



#pragma mark * HelperToolProtocol implementation

- (void)connectWithEndpointReply:(void (^)(NSXPCListenerEndpoint *))reply
{
    [self updateInactivityTimer];
    
    reply([self.listener endpoint]);
}

- (void)getVersionWithReply:(void(^)(NSString * version))reply
{
    [self updateInactivityTimer];
    
    reply([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
}


@end
