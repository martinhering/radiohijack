

#import "HelperTool.h"
#import "Common.h"
#import "RHSniffOperation.h"


@interface HelperTool () <NSXPCListenerDelegate, SnifferProtocol>
@property (atomic, strong, readwrite) NSXPCListener* listener;
@property (atomic, strong) NSTimer* hostApplicationCheckTimer;
@property (nonatomic, strong) NSOperationQueue* sniffOperationQueue;
@end

@implementation HelperTool

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        _sniffOperationQueue = [[NSOperationQueue alloc] init];
        
        [self _hostApplicationCheck];
        _hostApplicationCheckTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(_hostApplicationCheck) userInfo:nil repeats:YES];
        
        _listener = [[NSXPCListener alloc] initWithMachServiceName:kHelperToolMachServiceName];
        _listener.delegate = self;
        
        [_listener resume];
    }
    return self;
}

- (void) _hostApplicationCheck
{
    NSArray* applications = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.vemedio.RadioHijack"];
    
    if ([applications count] == 0) {
        NSLog(@"host application is not running, quitting");
        exit(0);
    }
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
    reply([self.listener endpoint]);
}

- (void)getVersionWithReply:(void(^)(NSString * version))reply
{
    reply([[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
}

- (void)startSniffingAuthorization:(NSData *)authData withReply:(void(^)(NSError* error))reply
{
    NSError* error = [self checkAuthorization:authData command:_cmd];
    if (!error)
    {
        NSSet* activeNetworkInterfaces = [RHSniffOperation activeNetworkInterfaces];
        for(NSString* interface in activeNetworkInterfaces)
        {
            
            RHSniffOperation* sniffOp = [[RHSniffOperation alloc] initWithNetworkInterface:interface];
            sniffOp.didReceiveHTTPRequestResponse = ^(NSURLRequest* request, NSHTTPURLResponse* response) {
                
                NSLog(@"request:%@ response:%@", request, response);
            };
            
            [self.sniffOperationQueue addOperation:sniffOp];
        }
        
        
        NSLog(@"sniffing started");
    }
    reply(error);
}

- (void)stopSniffingAuthorization:(NSData *)authData withReply:(void(^)(NSError* error))reply
{
    NSError* error = [self checkAuthorization:authData command:_cmd];
    if (!error)
    {
        for(NSOperation* op in [self.sniffOperationQueue operations]) {
            [op cancel];
        }
        NSLog(@"sniffing stopped");
    }
    reply(error);
}
@end
