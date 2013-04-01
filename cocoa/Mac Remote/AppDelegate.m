//
//  AppDelegate.m
//  Mac Remote
//
//  Created by connormckenna on 2/3/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#import "AppDelegate.h"
#import "ServerInterface.h"
#import "Installer.h"
#import <stdlib.h>

@implementation AppDelegate
static NSString *startServerText = @"Start Server";
static NSString *stopServerText = @"Stop Server";
static NSString *pendingText = @"Checking Server";

static AppDelegate *instance = NULL;

+ (id)getInstance {
    return instance;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    instance = self;
    NSString *mobileCode = [ServerInterface getPasscode];
    [self.passcode setStringValue:mobileCode];
    
    [Installer installHelper];
    [Installer installDaemon:mobileCode];
    
    [ServerInterface getServerStatus];
    [self.serverStateButton setTransparent:YES];
    
    [self.progressIndicator startAnimation:self];
    [self.progressIndicator setDisplayedWhenStopped:YES];
}

- (void)setRunning {
    [self.progressIndicator setDisplayedWhenStopped:NO];
    [self.progressIndicator stopAnimation:self];
    [self.serverStateButton setTransparent:NO];
    self.serverStateButton.title = stopServerText;
}

- (void)setStopped {
    [self.progressIndicator setDisplayedWhenStopped:NO];
    [self.progressIndicator stopAnimation:self];
    [self.serverStateButton setTransparent:NO];
    self.serverStateButton.title = startServerText;
}

- (IBAction)serverStateChange:(NSButton *)sender {
    if ([sender.title isEqualToString:startServerText]) {
        [ServerInterface startServer];
        [self setRunning];
    } else if ([sender.title isEqualToString:stopServerText]) {
        [ServerInterface stopServer];
        [self setStopped];
    }
}
@end
