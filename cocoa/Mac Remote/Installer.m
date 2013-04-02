//
//  Installer.m
//  Mac Remote
//
//  Created by connormckenna on 3/6/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#import "Installer.h"
#include <stdlib.h>
#import "Package/Package.h"
#import "ServerInterface.h"

@implementation Installer

static NSString *helperInstalledKey = @"helperInstalled";
static NSString *daemonInstalledKey = @"daemonInstalled";

+ (void)installHelper {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL installed = [defaults boolForKey:helperInstalledKey];
    if (installed)
        return;
    Package *helper = [Package helperPackage];
    [helper install:[ServerInterface getPasscode]];
    [helper start:[ServerInterface getPasscode]];
    
    [defaults setBool:YES forKey:helperInstalledKey];
    [defaults synchronize];
}

+ (void)uninstallHelper {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:NO forKey:helperInstalledKey];
    [defaults synchronize];
    
    Package *helper = [Package helperPackage];
    [helper stop];
    [helper uninstall];
}

+ (void)uninstallDaemon {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:NO forKey:daemonInstalledKey];
    [defaults synchronize];
    
    Package *daemon = [Package daemonPackage];
    [daemon stop];
    [daemon uninstall];
}

+ (void)installDaemon {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL installed = [defaults boolForKey:daemonInstalledKey];
    if (installed)
        return;
    Package *daemon = [Package daemonPackage];
    [daemon install:[ServerInterface getPasscode]];
    
    [defaults setBool:YES forKey:daemonInstalledKey];
    [defaults synchronize];
}

+ (BOOL)daemonInstalled {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:daemonInstalledKey];
}

+ (BOOL)helperInstalled {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:helperInstalledKey];
}

@end
