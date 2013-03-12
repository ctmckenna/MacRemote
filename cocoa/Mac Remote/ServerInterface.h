//
//  ServerInterface.h
//  Mac Remote
//
//  Created by connormckenna on 2/3/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ServerInterface : NSObject
+ (void)getServerStatus;
+ (BOOL)startServer;
+ (BOOL)stopServer;
+ (NSString *)getPasscode;
@end
