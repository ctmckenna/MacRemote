//
//  Package.h
//  cocoa
//
//  Created by connormckenna on 3/30/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Package : NSObject
{
@private
    NSString *packageName;
}
- (Package *)initWithName:(NSString *)packageName;
+ (Package *)helperPackage;
+ (Package *)daemonPackage;
+ (NSString *)getPathInHome:(NSString *)path;

- (int)installAppFromServer;
- (void)install:(NSMutableDictionary *)substituteDict;
- (void)uninstall;
- (void)start;
- (void)restart;
- (void)stop;
@end
