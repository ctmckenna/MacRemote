//
//  main.m
//  Mac Remote
//
//  Created by connormckenna on 2/3/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
    /* use fresh defaults when running in xcode */
    if (strstr(argv[0], "Xcode/DerivedData/") != NULL) {
        NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    }
    return NSApplicationMain(argc, (const char **)argv);
}
