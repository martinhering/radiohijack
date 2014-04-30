//
//  main.c
//  SnifferTest
//
//  Created by Martin Hering on 30.04.14.
//
//

#include <stdio.h>
#import <Cocoa/Cocoa.h>
#import "RHSniffOperation.h"

int main(int argc, const char * argv[])
{
#pragma unused(argc)
#pragma unused(argv)

    @autoreleasepool {
        
        NSOperationQueue* queue = [NSOperationQueue new];
        
        NSSet* activeNetworkInterfaces = [RHSniffOperation activeNetworkInterfaces];
        for(NSString* interface in activeNetworkInterfaces)
        {
            RHSniffOperation* sniffOp = [[RHSniffOperation alloc] initWithNetworkInterface:interface];
            
            [queue addOperation:sniffOp];
        }
        
        [[NSRunLoop currentRunLoop] run];
    }
    
	return EXIT_FAILURE;
}

