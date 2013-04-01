//
//  StringUtil.m
//  cocoa
//
//  Created by connormckenna on 3/30/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#import "StringUtil.h"

@implementation StringUtil

struct buffer {
    char *ptr;
    size_t len;
    size_t wloc;
};

+ (char *)makeCString:(NSString *)string {
    char *buf = malloc([string length] + 1);
    if (![string getCString:buf maxLength:[string length]+1 encoding:NSASCIIStringEncoding]) {
        free(buf);
        return NULL;
    }
    return buf;
}

+ (struct buffer *)makeBuffer:(size_t)len {
    char *ptr = malloc(len);
    struct buffer *buf = malloc(sizeof(struct buffer));
    buf->ptr = ptr;
    buf->len = len;
    buf->wloc = 0;
    return buf;
}

+ (void)bufferCopy:(struct buffer *)buf :(char *)ptr :(size_t) len {
    if (buf->len - buf->wloc < len) {
        buf->ptr = realloc(buf->ptr, buf->len *2);
        buf->len = buf->len * 2;
    }
    memcpy(buf->ptr + buf->wloc, ptr, len);
    buf->wloc += len;
}

+ (char *)strchrnul:(char *)str :(char)c {
    for (; *str && *str != c; ++str);
    return str;
}

+ (NSString *)substitute:(NSString *)str :(NSMutableDictionary *)dict {
    char *cStr = [StringUtil makeCString:str];
    struct buffer *buf = [StringUtil makeBuffer:strlen(cStr)*2];
    char *p1 = cStr;
    while (YES) {
        char *p2 = [StringUtil strchrnul:p1 :'{'];
        [StringUtil bufferCopy:buf :p1 :(p2-p1)];
        p1 = p2;
        p2 = [StringUtil strchrnul:p1 :'}'];
        if (!*p2) break;
        size_t key_len = p2 - (p1 + 1);
        char *key = malloc(key_len + 1);
        memcpy(key, p1 + 1, key_len);
        memset(key + key_len, 0, 1);
        NSString *replacement = [dict objectForKey:[NSString stringWithCString:key encoding:NSASCIIStringEncoding]];
        if (replacement != nil) {
            char *replacementC = [StringUtil makeCString:replacement];
            [StringUtil bufferCopy:buf :replacementC :strlen(replacementC)];
            free(replacementC);
        }
        free(key);
        p1 = p2 + 1;
    }
    [StringUtil bufferCopy:buf :"\0" :1];
    NSString *newStr = [NSString stringWithCString:buf->ptr encoding:NSASCIIStringEncoding];
    free(buf->ptr);
    free(buf);
    free(cStr);
    return newStr;
}
@end
