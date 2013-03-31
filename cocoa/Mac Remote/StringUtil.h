//
//  StringUtil.h
//  cocoa
//
//  Created by connormckenna on 3/30/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface StringUtil : NSObject
+ (NSString *)substitute:(NSString *)str :(NSMutableDictionary *)dict;

@end
