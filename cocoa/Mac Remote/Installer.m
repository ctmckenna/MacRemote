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

@implementation Installer

+ (void)installHelper {
    NSString *key = @"helperInstalled";
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL installed = [defaults boolForKey:key];
    if (installed)
        return;
    
    Package *helper = [Package helperPackage];
    NSMutableDictionary *smacroDict = [[NSMutableDictionary alloc] initWithCapacity:5];
    [smacroDict setObject:[Package getPathInHome:nil] forKey:@"home"];
    [helper install:smacroDict];
    [helper start];
    
    [defaults setBool:YES forKey:key];
    [defaults synchronize];
}

+ (void)installDaemon:(NSString *)passcode {
    NSString *key = @"daemonInstalled";
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL installed = [defaults boolForKey:key];
    if (installed)
        return;
    
    Package *daemon = [Package daemonPackage];
    NSMutableDictionary *smacroDict = [[NSMutableDictionary alloc] initWithCapacity:5];
    [smacroDict setObject:passcode forKey:@"passcode"];
    [smacroDict setObject:[Package getPathInHome:nil] forKey:@"home"];
    [daemon install:smacroDict];
    
    [defaults setBool:YES forKey:key];
    [defaults synchronize];
}

@end
