//
//  Updater.m
//  helper
//
//  Created by connormckenna on 3/31/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#import "Updater.h"
#import "Package/Package.h"

@implementation Updater

+ (int)updateDaemon {
    Package *daemonPackage = [Package daemonPackage];
    if (0 > [daemonPackage installAppFromServer])
        return -1;
    return 0;
}

+ (int)updateHelper {
    return 0;
}

@end
