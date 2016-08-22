//
//  AppDelegate.m
//  FBSimulatorCLI
//
//  Created by Tapan Thaker on 07/11/15.
//  Copyright (c) 2015 TT. All rights reserved.
//

#import "AppDelegate.h"
#import "E34Simctl-Swift.h"
#import "E34Simctl-Bridging-Header.h"

@interface AppDelegate () {
    WebServer *webserver;
}

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    NSInteger flag = [arguments indexOfObject: @"--port"];
    NSInteger port = [arguments[flag+1] integerValue];
    if (flag < 0 ||  port == 0 ) {
        [NSException raise:@"Invalid port number" format:@"Please pass a valid port number following --port argument"];
    }
    webserver = [[WebServer alloc]initWithPort:port];
    [webserver startServer];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
