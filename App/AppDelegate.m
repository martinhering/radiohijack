#import "AppDelegate.h"

#import "Common.h"
#import "HelperTool.h"
#import "RHRadioURLFinder.h"

#include <ServiceManagement/ServiceManagement.h>

@interface AppDelegate ()
@property (atomic, copy, readwrite) NSData * authorization;
@property (atomic, strong, readwrite) NSXPCConnection * helperToolConnection;
@property (atomic) BOOL hijacking;
@property (atomic, strong) RHRadioURLFinder* urlFinder;
@end

@implementation AppDelegate {
    AuthorizationRef    _authRef;
}

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
    #pragma unused(note)
    
    OSStatus                    err;
    AuthorizationExternalForm   extForm;
    
    assert(self.window != nil);

    err = AuthorizationCreate(NULL, NULL, 0, &_authRef);
    if (err == errAuthorizationSuccess) {
        err = AuthorizationMakeExternalForm(_authRef, &extForm);
    }
    if (err == errAuthorizationSuccess) {
        self.authorization = [[NSData alloc] initWithBytes:&extForm length:sizeof(extForm)];
    }
    assert(err == errAuthorizationSuccess);
    
    if (_authRef) {
        [Common setupAuthorizationRights:self->_authRef];
    }
    
    [self.window makeKeyAndOrderFront:self];
    
    
    [self _ensureThatNewestToolIsInstalled];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(snifferDidReceiveHTTPTrafficNotification:)
                                                            name:kRHSnifferDidReceiveHTTPTrafficNotification
                                                          object:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    #pragma unused(sender)
    return YES;
}

#pragma mark -

- (void)connectToHelperTool
{
    assert([NSThread isMainThread]);
    
    if (self.helperToolConnection == nil) {
        self.helperToolConnection = [[NSXPCConnection alloc] initWithMachServiceName:kHelperToolMachServiceName options:NSXPCConnectionPrivileged];
        self.helperToolConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(SnifferProtocol)];

        DEFINE_WEAK_SELF
        self.helperToolConnection.invalidationHandler = ^{
            weakSelf.helperToolConnection.invalidationHandler = nil;
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                weakSelf.helperToolConnection = nil;
            }];
        };

        [self.helperToolConnection resume];
    }
}

- (void)connectAndExecuteCommandBlock:(void(^)(NSError *))commandBlock
{
    assert([NSThread isMainThread]);
    
    [self connectToHelperTool];
    
    commandBlock(nil);
}

#pragma mark - IB Actions

- (NSError*) _installSnifferTool
{
    Boolean             success;
    CFErrorRef          error;
    
    success = SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)kHelperToolMachServiceName, self->_authRef, &error );

    if (!success) {
        return (__bridge_transfer NSError*)error;
    }
    
    return nil;
}

- (void) _getVersionWithReply:(void(^)(NSError* error, NSString* version))reply
{
    [self connectAndExecuteCommandBlock:^(NSError * connectError) {
        
        if (connectError) {
            reply(connectError, nil);
            return;
        }
        
        id remoteProxy = [self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            
            if (proxyError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    reply(proxyError, nil);
                });
            }
        }];

        [remoteProxy getVersionWithReply:^(NSString *version) {
            dispatch_async(dispatch_get_main_queue(), ^{
                reply(nil, version);
            });
        }];

    }];
}

- (void) _ensureThatNewestToolIsInstalled
{
    NSString* sniffInfoPath = [[NSBundle mainBundle] pathForResource:@"Sniffer-Info" ofType:@"plist"];
    NSDictionary* sniffInfoDict = [NSDictionary dictionaryWithContentsOfFile:sniffInfoPath];
    NSString* localVersion = sniffInfoDict[@"CFBundleVersion"];
    
    
    [self _getVersionWithReply:^(NSError *error, NSString *version) {
        
        if (error) {
            
            if ([error code] == 4099) {
                NSError* installError = [self _installSnifferTool];
                if (installError) {
                    ErrLog(@"error installing tool: %@", error);
                }
                else {
                    [self _ensureThatNewestToolIsInstalled];
                }
            }
            else {
                ErrLog(@"error getting version: %@", error);
            }
        }
        else
        {
            if (![version isEqualToString:localVersion]) {
                NSError* installError = [self _installSnifferTool];
                if (installError) {
                    ErrLog(@"error installing tool: %@", error);
                }
                else {
                    [self _ensureThatNewestToolIsInstalled];
                }
            }
            else {
                DebugLog(@"Sniffer %@ available", version);
            }
        }
    }];
}


#pragma mark -


- (IBAction) toggleHijacking:(id)sender
{
    #pragma unused(sender)
    
    if (!self.hijacking)
    {
        self.urlFinder = [RHRadioURLFinder new];
        self.urlFinder.didFindRadioURL = ^(NSURL* url, RHURLResourceType type) {
            NSLog(@"didFindRadioURL %@ (%ld)", url, (long)type);
        };
        
        
        [self connectAndExecuteCommandBlock:^(NSError * connectError) {
            
            if (connectError) {
                ErrLog(@"error connecting: %@", connectError);
                return;
            }

            id remoteProxy = [self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                if (proxyError) {
                    ErrLog(@"error getting proxy: %@", proxyError);
                }
            }];
            
            [remoteProxy startSniffingAuthorization:self.authorization withReply:^(NSError* error) {
                if (error) {
                    ErrLog(@"error start sniffing: %@", error);
                    return;
                }
                
                self.hijacking = YES;
            }];

        }];
    }
    else
    {
        [self connectAndExecuteCommandBlock:^(NSError * connectError) {
            
            if (connectError) {
                ErrLog(@"error connecting: %@", connectError);
                return;
            }
            
            id remoteProxy = [self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                if (proxyError) {
                    ErrLog(@"error getting proxy: %@", proxyError);
                }
            }];
            
            [remoteProxy stopSniffingAuthorization:self.authorization withReply:^(NSError* error) {
                if (error) {
                    ErrLog(@"error stop sniffing: %@", error);
                    return;
                }
                
                self.hijacking = NO;
                self.urlFinder = nil;
            }];
            
        }];
    }
}

+ (NSSet*) keyPathsForValuesAffectingStopButtonTitle {
    return [NSSet setWithObject:@"hijacking"];
}

- (NSString*) stopButtonTitle {
    return (self.hijacking) ? @"Stop" : @"Start";
}

- (void) snifferDidReceiveHTTPTrafficNotification:(NSNotification*)notification
{
    #pragma unused(notification)
    
    [self connectAndExecuteCommandBlock:^(NSError * connectError) {
        
        if (connectError) {
            ErrLog(@"error connecting: %@", connectError);
            return;
        }
        
        id remoteProxy = [self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
            if (proxyError) {
                ErrLog(@"error getting proxy: %@", proxyError);
            }
        }];
        
        [remoteProxy getQueuedHTTPDataAuthorization:self.authorization withReply:^(NSError* error, NSArray* queuedHTTPData) {
            if (error) {
                ErrLog(@"error stop sniffing: %@", error);
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                for(NSDictionary* pair in queuedHTTPData)
                {
                    NSURLRequest* request = [NSKeyedUnarchiver unarchiveObjectWithData:pair[@"request"]];
                    NSHTTPURLResponse* response = [NSKeyedUnarchiver unarchiveObjectWithData:pair[@"response"]];
                    
                    //NSLog(@"request: %@, response: %@", request, response);
                    [self.urlFinder addRequest:request response:response];
                }
                
            });
        }];
        
    }];
}

@end
