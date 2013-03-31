//
//  Package.m
//  cocoa
//
//  Created by connormckenna on 3/30/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#import "Package.h"
#import "StringUtil.h"

@implementation Package

NSString *startupDirectory = @"Library/LaunchAgents/";
NSString *appDirectory = @"Library/Application Support/RemoteServer/";

+ (NSString *)getPathInHome:(NSString *)path {
    NSString *home = [[[NSProcessInfo processInfo] environment] objectForKey:@"HOME"];
    if (home == NULL) //Careful: should create warning message instead
        home = [@"~" stringByExpandingTildeInPath];
    if (path != NULL) {
        return [home stringByAppendingPathComponent:path];
    } else
        return home;
}


+ (int)copy:(NSString *)src :(NSString *)dst {
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSError *error;
    if (![defaultManager createDirectoryAtPath:[dst stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:&error])
        return NSLog(@"%@", [error localizedDescription]), -1;
    [defaultManager removeItemAtPath:dst error:nil];
    if (![[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:&error])
        return NSLog(@"%@", [error localizedDescription]), -1;
    return 0;
}

+ (NSString *)startupFilename:(NSString *)packageName {
    static NSString *prefix = @"com.foggy-city.";
    static NSString *suffix = @".plist";
    return [NSString stringWithFormat:@"%@%@%@", prefix, packageName, suffix];
}

+ (NSString *)startupFileLocation:(NSString *)packageName {
    return [[Package getPathInHome:startupDirectory] stringByAppendingPathComponent:[Package startupFilename:packageName]];
}

+ (int)runCommand:(NSString *)cmd {
    NSArray *arr = [cmd componentsSeparatedByString:@" "];
    NSString *path = [arr objectAtIndex:0];
    NSArray *args = [arr subarrayWithRange:NSMakeRange(1, [arr count]-1)];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:path];
    [task setArguments:args];
    [task launch];
    [task waitUntilExit];
    return [task terminationStatus];
}

+ (Package *)helperPackage {
    return [[Package alloc] initWithName:@"helper"];
}

+ (Package *)daemonPackage {
    return [[Package alloc] initWithName:@"daemon"];
}

- (Package *)initWithName:(NSString *)package {
    self = [self init];
    self->packageName = package;
    return self;
}

- (int)installExecutable {
    NSString *app = [packageName stringByAppendingString:@".app"];
    NSString *src = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:app];
    NSString *dst = [[Package getPathInHome:appDirectory] stringByAppendingPathComponent:app];
    return [Package copy:src :dst];
}

- (void)uninstallExecutable {
    NSString *app = [packageName stringByAppendingString:@".app"];
    NSString *appLocation = [[Package getPathInHome:appDirectory] stringByAppendingPathComponent:app];
    [[NSFileManager defaultManager] removeItemAtPath:appLocation error:nil];
}

- (int)stopStartup {
    NSString *startupFileLocation = [Package startupFileLocation:packageName];
    return [Package runCommand:[NSString stringWithFormat:@"/bin/launchctl unload %@", startupFileLocation]];
}

- (int)startStartup {
    NSString *startupFileLocation = [Package startupFileLocation:packageName];
    return [Package runCommand:[NSString stringWithFormat:@"/bin/launchctl load %@", startupFileLocation]];
}

- (int)installStartup:(NSMutableDictionary *)substituteDict {
    NSString *startupFile = [Package startupFilename:packageName];
    NSString *src = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:startupFile];
    if (substituteDict != nil) {
        NSError *error;
        NSString *fileContents = [NSString stringWithContentsOfFile:src encoding:NSASCIIStringEncoding error:&error];
        if (fileContents == nil)
            return NSLog(@"%@", [error localizedDescription]), -1;
        fileContents = [StringUtil substitute:fileContents :substituteDict];
        if (![fileContents writeToFile:src atomically:YES encoding:NSASCIIStringEncoding error:&error]) {
            return NSLog(@"%@", [error localizedDescription]), -1;
        }
    }
    NSString *dst = [[Package getPathInHome:startupDirectory] stringByAppendingPathComponent:startupFile];
    return [Package copy:src :dst];
}

- (void)uninstallStartup {
    NSString *startupFileLocation = [Package startupFileLocation:packageName];
    [[NSFileManager defaultManager] removeItemAtPath:startupFileLocation error:nil];
}

- (void)install:(NSMutableDictionary *)substituteDict {
    [self installExecutable];
    [self installStartup:substituteDict];
}

- (void)start {
    [self stopStartup];
    [self installStartup:nil];
    [self startStartup];
}

- (void)stop {
    [self stopStartup];
    [self uninstallStartup];
}

@end
