
#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, assign, readwrite) IBOutlet NSWindow *    window;
@property (nonatomic, assign, readwrite) IBOutlet NSTextView *  textView;

- (IBAction)installAction:(id)sender;
- (IBAction)getVersionAction:(id)sender;


@end
