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

static NSString *installText = @"Install Server";
static NSString *uninstallText = @"Uninstall Server";

static AppDelegate *instance = NULL;

+ (id)getInstance {
    return instance;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    if (flag == NO)
        [_window makeKeyAndOrderFront:self];
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    instance = self;
    NSString *mobileCode = [ServerInterface getPasscode];
    [self.passcode setStringValue:mobileCode];
    
    if ([Installer daemonInstalled] && [Installer helperInstalled]) {
        [self.installItem setTitle:uninstallText];
    } else {
        [self.installItem setTitle:installText];
    }
    
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
        [self install];
        [ServerInterface startServer];
        [self setRunning];
    } else if ([sender.title isEqualToString:stopServerText]) {
        [ServerInterface stopServer];
        [self setStopped];
    }
}

- (void)install {
    [Installer installDaemon];
    [Installer installHelper];
    [self.installItem setTitle:uninstallText];
}

- (void)uninstall {
    [Installer uninstallDaemon];
    [Installer uninstallHelper];
    [self.installItem setTitle:installText];
    [self setStopped];
}

- (IBAction)installItemPressed:(NSMenuItem *)sender {
    NSString *senderTitle = [sender title];
    if ([senderTitle isEqualToString:installText]) {
        [self install];
    } else if ([senderTitle isEqualToString:uninstallText]) {
        [self uninstall];
    }
}
@end
