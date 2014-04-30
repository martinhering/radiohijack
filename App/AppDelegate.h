
#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, assign, readwrite) IBOutlet NSWindow *    window;
@property (nonatomic, readonly) NSString* stopButtonTitle;

- (IBAction) toggleHijacking:(id)sender;
@property (nonatomic, readonly) BOOL hijacking;

@end
