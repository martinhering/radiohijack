
#import "HelperTool.h"

int main(int argc, char **argv)
{
    #pragma unused(argc)
    #pragma unused(argv)

    @autoreleasepool {
        HelperTool *  m;
        
        m = [[HelperTool alloc] init];

        [[NSRunLoop currentRunLoop] run];
    }
    
	return EXIT_FAILURE;
}
