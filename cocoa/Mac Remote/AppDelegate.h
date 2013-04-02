//
//  AppDelegate.h
//  Mac Remote
//
//  Created by connormckenna on 2/3/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;


@property (weak) IBOutlet NSButton *serverStateButton;

- (IBAction)serverStateChange:(NSButton *)sender;
@property (weak) IBOutlet NSMenuItem *installItem;
- (IBAction)installItemPressed:(NSMenuItem *)sender;

@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTextField *passcode;
- (void)setRunning;
- (void)setStopped;
+ (id)getInstance;
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag;
@end
