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
NSString *downloadServer = @"http://foggyciti.com/remote/download";

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
    if (![defaultManager createDirectoryAtPath:[Package directory:dst] withIntermediateDirectories:YES attributes:nil error:&error])
        return NSLog(@"%@", [error localizedDescription]), -1;
    [defaultManager removeItemAtPath:dst error:nil];
    if (![[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:&error])
        return NSLog(@"%@", [error localizedDescription]), -1;
    return 0;
}

+ (int)write:(NSData *)src :(NSString *)dst {
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    NSError *error;
    if (![defaultManager createDirectoryAtPath:[Package directory:dst] withIntermediateDirectories:YES attributes:nil error:&error])
        return NSLog(@"%@", [error localizedDescription]), -1;
    if (![src writeToFile:dst atomically:YES])
        return NSLog(@"writing to file failed"), -1;
    return 0;
}

+ (NSString *)directory:(NSString *)path {
    return [path stringByDeletingLastPathComponent];
}

- (NSString *)startupFilename {
    static NSString *prefix = @"com.foggy-city.";
    static NSString *suffix = @".plist";
    return [NSString stringWithFormat:@"%@%@%@", prefix, packageName, suffix];
}

- (NSString *)appFilename {
    return [packageName stringByAppendingString:@".app"];
}

- (NSString *)appZippedFilename {
    return [[self appFilename] stringByAppendingString:@".zip"];
}

- (NSURL *)exeUrl {
    return [NSURL URLWithString:[downloadServer stringByAppendingPathComponent:packageName]];
}

- (NSURL *)appUrl {
    return [NSURL URLWithString:[downloadServer stringByAppendingPathComponent:[self appZippedFilename]]];
}

- (NSString *)startupFileLocation {
    return [[Package getPathInHome:startupDirectory] stringByAppendingPathComponent:[self startupFilename]];
}

- (NSString *)appFileLocation {
    return [[Package getPathInHome:appDirectory] stringByAppendingPathComponent:[self appFilename]];
}

- (NSString *)exeFileLocation {
    return [[[self appFileLocation] stringByAppendingPathExtension:@"Contents/MacOS"] stringByAppendingPathExtension:packageName];
}

- (NSString *)appZippedFileLocation {
    return [[Package getPathInHome:appDirectory] stringByAppendingPathComponent:[self appZippedFilename]];
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

- (int)installApp {
    NSString *src = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:[self appFilename]];
    NSString *dst = [self appFileLocation];
    return [Package copy:src :dst];
}

- (void)uninstallExecutable {
    [[NSFileManager defaultManager] removeItemAtPath:[self appFileLocation] error:nil];
}

- (int)stopStartup {
    NSString *startupFileLocation = [self startupFileLocation];
    return [Package runCommand:[NSString stringWithFormat:@"/bin/launchctl unload %@", startupFileLocation]];
}

- (int)startStartup {
    NSString *startupFileLocation = [self startupFileLocation];
    return [Package runCommand:[NSString stringWithFormat:@"/bin/launchctl load %@", startupFileLocation]];
}

- (int)installStartup:(NSMutableDictionary *)substituteDict {
    NSString *startupFile = [self startupFilename];
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
    NSString *startupFileLocation = [self startupFileLocation];
    [[NSFileManager defaultManager] removeItemAtPath:startupFileLocation error:nil];
}

- (int)installAppFromServer {
    NSURLResponse *response;
    NSError *error;
    NSData *data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:[self exeUrl]] returningResponse:&response error:&error];
    if (data == nil)
        return -1;
    [Package write:data :[self appZippedFileLocation]];
    if (0 > [Package runCommand:[NSString stringWithFormat:@"/usr/bin/unzip -q -o -d %@ %@", [Package directory:[self appFileLocation]], [self appZippedFileLocation]]])
        return NSLog(@"failed to unzip"), -1;
    if (![[NSFileManager defaultManager] removeItemAtPath:[self appZippedFileLocation] error:&error])
        return NSLog(@"%@", [error localizedDescription]), -1;
    return 0;
}

- (void)install:(NSMutableDictionary *)substituteDict {
    [self installApp];
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