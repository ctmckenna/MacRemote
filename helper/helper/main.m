//
//  main.m
//  helper
//
//  Created by connormckenna on 3/31/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Package/Package.h"
#import "Updater.h"

NSString *versionKey = @"version";

long get_last_version() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults integerForKey:versionKey];
}

void set_version(long v) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:v forKey:versionKey];
    [defaults synchronize];
}

long get_current_version() {
    NSURLResponse *response;
    NSError *error;
    NSData *data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://foggyciti.com/remote/version"]] returningResponse:&response error:&error];
    if (data == nil)
        return -1;
    NSString *version = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    return [version integerValue];
    
}

int main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;
    
    long last_version = get_last_version();
    long current_version = get_current_version();
    if (current_version <= last_version)
        return 0;
    if (0 > [Updater updateDaemon])
        return 0;
    set_version(current_version);
    return 0;
}
