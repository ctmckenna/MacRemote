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
+ (int)runCommandWithArgs:(NSArray *)arr;
+ (int)runCommandWithArgs:(NSArray *)arr :(BOOL)async;

- (int)installAppFromServer;
- (void)install:(NSString *)passcode;
- (void)uninstall;
- (void)start:(NSString *)passcode;
- (void)restart;
- (void)stop;
@end
