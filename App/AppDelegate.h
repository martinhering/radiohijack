
#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, assign, readwrite) IBOutlet NSWindow* window;
@property (nonatomic, assign, readwrite) IBOutlet NSArrayController* arrayController;
@property (nonatomic, readonly) NSString* stopButtonTitle;

- (IBAction) toggleHijacking:(id)sender;
@property (nonatomic, readonly) BOOL hijacking;

- (IBAction) sendTo:(NSButton*)sender;
@end
