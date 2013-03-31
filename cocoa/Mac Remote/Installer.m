//
//  Installer.m
//  Mac Remote
//
//  Created by connormckenna on 3/6/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#import "Installer.h"
#include <stdlib.h>
#import "Package.h"

@implementation Installer

+ (void)installHelper {
    NSString *key = @"helperInstalled";
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL installed = [defaults boolForKey:key];
    if (installed)
        return;
    Package *helper = [Package helperPackage];
    [helper install];
    [helper start];
    [defaults setBool:YES forKey:key];
    [defaults synchronize];
}

+ (void)installDaemon {
    NSString *key = @"daemonInstalled";
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL installed = [defaults boolForKey:key];
    if (installed)
        return;
    Package *daemon = [Package daemonPackage];
    [daemon install];
    [defaults setBool:YES forKey:key];
    [defaults synchronize];
}

@end
