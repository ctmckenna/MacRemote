//
//  Installer.m
//  Mac Remote
//
//  Created by connormckenna on 3/6/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#import "Installer.h"
#include <stdlib.h>

@implementation Installer

NSString *daemonConfigDir = @"Library/LaunchAgents/";
NSString *daemonConfigFilename = @"com.foggy-city.remote.plist";
NSString *daemonAppDestDir = @"Library/Application Support/RemoteServer";

NSString *helper = @"daemon.app";


+ (bool)installFinished {
    NSString *installPath = [Installer getPathInHome:daemonConfigDir :daemonConfigFilename];
    return [[NSFileManager defaultManager] fileExistsAtPath:installPath];
}

+ (NSString *)pathToLaunchConfigFile {
    return [Installer getPathInHome:daemonConfigDir :daemonConfigFilename];
}

+ (NSString *)getPathInHome:(NSString *)target :(NSString *)file {
    static NSString *fail = @"";
    NSString *home = [[[NSProcessInfo processInfo] environment] objectForKey:@"HOME"];
    if (home == NULL) //Careful: should create warning message instead
        return fail;
    if (file != NULL)
        return [[home stringByAppendingPathComponent:target] stringByAppendingPathComponent:file];
    else
        return [home stringByAppendingPathComponent:target];
}

+ (void)installDaemonApp {
    NSString *daemonAppSrcPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:helper];
    NSString *daemonAppDestPath = [Installer getPathInHome:daemonAppDestDir :NULL];
    NSError *error;
    bool success = [[NSFileManager defaultManager] copyItemAtPath:daemonAppSrcPath toPath:daemonAppDestPath error:&error];
    if (!success)
        NSLog(@"%@", [error localizedDescription]);
}

+ (void)installDaemonConfig {
    NSString *daemonConfigSrcPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:daemonConfigFilename];
    NSString *daemonConfigDestPath = [Installer getPathInHome:daemonConfigDir :daemonConfigFilename];
    NSError *error;
    bool success = [[NSFileManager defaultManager] copyItemAtPath:daemonConfigSrcPath toPath:daemonConfigDestPath error:&error];
    if (!success)
        NSLog(@"%@", [error localizedDescription]);
    
}

+ (void)installDaemon {
    if ([Installer installFinished])
        return;
    [Installer installDaemonApp];
    [Installer installDaemonConfig];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/launchctl"];
    NSArray *launchArgs = [[NSArray alloc] initWithObjects:@"load", [Installer getPathInHome:daemonConfigDir :daemonConfigFilename], nil];
    [task setArguments:launchArgs];
    [task launch];
    [task waitUntilExit];
    int status = [task terminationStatus];
    NSLog(@"status: %d", status);
}
@end
