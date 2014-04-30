#import "AppDelegate.h"

#import "Common.h"
#import "HelperTool.h"

#include <ServiceManagement/ServiceManagement.h>

@interface AppDelegate ()
@property (atomic, copy, readwrite) NSData * authorization;
@property (atomic, strong, readwrite) NSXPCConnection * helperToolConnection;
@property (atomic) BOOL hijacking;
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



//- (IBAction)installAction:(id)sender
//{
//    #pragma unused(sender)
//    
//    NSError* error = [self _installSnifferTool];
//    if (error) {
//        ErrLog(@"error installing tool: %@", error);
//    }
//}
//
//- (IBAction)getVersionAction:(id)sender
//{
//    #pragma unused(sender)
//    
//    [self _getVersionWithReply:^(NSError *error, NSString *version) {
//        
//        if (error) {
//            ErrLog(@"error getting version: %@", error);
//        }
//        else {
//            NSLog(@"version = %@", version);
//        }
//    }];
//}
//
//
//

/*
- (IBAction)readLicenseAction:(id)sender
    // Called when the user clicks the Read License button.  This is an example of an
    // authorized command that, by default, can be done by anyone.
{
    #pragma unused(sender)
    [self connectAndExecuteCommandBlock:^(NSError * connectError) {
        if (connectError != nil) {
            [self logError:connectError];
        } else {
            [[self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                [self logError:proxyError];
            }] readLicenseKeyAuthorization:self.authorization withReply:^(NSError * commandError, NSString * licenseKey) {
                if (commandError != nil) {
                    [self logError:commandError];
                } else {
                    [self logWithFormat:@"license = %@\n", licenseKey];
                }
            }];
        }
    }];
}

- (IBAction)writeLicenseAction:(id)sender
    // Called when the user clicks the Write License button.  This is an example of an
    // authorized command that, by default, can only be done by administrators.
{
    #pragma unused(sender)
    NSString *  licenseKey;
    
    // Generate a new random license key so that we can see things change.
    
    licenseKey = [[NSUUID UUID] UUIDString];

    [self connectAndExecuteCommandBlock:^(NSError * connectError) {
        if (connectError != nil) {
            [self logError:connectError];
        } else {
            [[self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                [self logError:proxyError];
            }] writeLicenseKey:licenseKey authorization:self.authorization withReply:^(NSError *error) {
                if (error != nil) {
                    [self logError:error];
                } else {
                    [self logWithFormat:@"success\n"];
                }
            }];
        }
    }];
}

- (IBAction)bindAction:(id)sender
    // Called when the user clicks the Bind button.  This is an example of an authorized
    // command that returns file descriptors.
{
    #pragma unused(sender)
    [self connectAndExecuteCommandBlock:^(NSError * connectError) {
        if (connectError != nil) {
            [self logError:connectError];
        } else {
            [[self.helperToolConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError) {
                [self logError:proxyError];
            }] bindToLowNumberPortAuthorization:self.authorization withReply:^(NSError *error, NSFileHandle *ipv4Handle, NSFileHandle *ipv6Handle) {
                if (error != nil) {
                    [self logError:error];
                } else {
                    // Each of these NSFileHandles has the close-on-dealloc flag set.  If we wanted to hold
                    // on to the underlying descriptor for a long time, we need to call <x-man-page://dup2>
                    // on that descriptor to get our our descriptor that persists beyond the lifetime of
                    // the NSFileHandle.  In this example app, however, we just print the descriptors, which
                    // we can do without any complications.
                    [self logWithFormat:@"IPv4 = %d, IPv6 = %u\n",
                        [ipv4Handle fileDescriptor],
                        [ipv6Handle fileDescriptor]
                    ];
                }
            }];
        }
    }];
}
*/
@end
