//
//  ServerInterface.m
//  Mac Remote
//
//  Created by connormckenna on 2/3/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#import "ServerInterface.h"
#import <ServiceManagement/SMLoginItem.h>
#import <AppKit/NSWorkspace.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#import "AppDelegate.h"

@implementation ServerInterface
static NSString *serverRunningKey = @"serverRunningKey";
static NSString *passcodeKey = @"mobilePasscodeKey";
static CFStringRef serverBundleId = CFSTR("com.foggy-city.remote-control-server");
static const char *ping_resp = ":-)";

static const char *code_set_resp = "yes";
static bool passcodeSet = NO;
static bool alive = NO;

static bool listening = false;

static const int SERVER_PORT = 10265;

static NSTimer *passcodeSetTimer = NULL;

//for reference, these are events accepted by helper app
typedef enum event {
    click = 1,
    move,
    drag,
    up,
    ping,
    code,
    stop
} event_t;


+ (void)getServerStatus {
    alive = NO;
    [ServerInterface startListening];
    [ServerInterface sendEvent:ping :[[ServerInterface getPasscode] cStringUsingEncoding:NSASCIIStringEncoding]];
    [NSTimer scheduledTimerWithTimeInterval:1 target:[ServerInterface class] selector:@selector(pingTimer:) userInfo:NULL repeats:YES];
}

+ (void)setServerPasscode {
    if (passcodeSetTimer != NULL)
        [passcodeSetTimer invalidate];
    passcodeSet = NO;
    [ServerInterface startListening];
    const char *passcode = [[ServerInterface getPasscode] cStringUsingEncoding:NSASCIIStringEncoding];
    [ServerInterface sendEvent:code :passcode];
    passcodeSetTimer = [NSTimer scheduledTimerWithTimeInterval:1 target:[ServerInterface class] selector:@selector(passcodeSetTimer:) userInfo:NULL repeats:YES];
}

+ (void)passcodeSetTimer:(NSTimer *)theTimer  {
    if (passcodeSet) {
        [theTimer invalidate];
    } else {
        const char *passcode = [[ServerInterface getPasscode] cStringUsingEncoding:NSASCIIStringEncoding];
        [ServerInterface sendEvent:code :passcode];
    }
        
}

+ (BOOL)startServer {
    //if (!SMLoginItemSetEnabled(serverBundleId, true))
    //    return FALSE;
    
    [ServerInterface setServerPasscode];
    return TRUE;
}

+ (BOOL)stopServer {
    //if (!SMLoginItemSetEnabled(serverBundleId, false))
    //    return FALSE;
    if (passcodeSetTimer != NULL)
        [passcodeSetTimer invalidate];
    [ServerInterface sendEvent:stop :""];
    return TRUE;
}

+ (void)pingTimer:(NSTimer *)theTimer {
    static int count = 0;
    if (alive) {
        count = 0;
        [theTimer invalidate];
        [[AppDelegate getInstance] setRunning];
    } else if(count < 1) {
        ++count;
        [ServerInterface sendEvent:ping :[[ServerInterface getPasscode] cStringUsingEncoding:NSASCIIStringEncoding]];
    } else {
        count = 0;
        [theTimer invalidate];
        [[AppDelegate getInstance] setStopped];
    }
}


+ (int)sendEvent:(int) ev :(const char *)msg {
    struct sockaddr_in sa;
    memset(&sa, 0, sizeof(sa));
    sa.sin_family = AF_INET;
    inet_aton("127.0.0.1", &sa.sin_addr);
    sa.sin_port = htons(SERVER_PORT);
    
    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    
    char buffer[strlen(msg)+2];//one extra for event
    memset(buffer, (unsigned char)ev, 1);
    strcpy(buffer+1, msg);
    socklen_t socklen = sizeof(sa);
    sendto(sockfd, buffer, sizeof(buffer), 0, (struct sockaddr *)&sa, socklen);
    return 0;
}

+ (void)startListening {
    if (listening)
        return;
    listening = true;
    dispatch_queue_t aQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(aQueue, ^{
        [ServerInterface listen:(SERVER_PORT+1)];
    });
}

+ (int)listen:(int)port {
    struct sockaddr_in sa;
    memset(&sa, 0, sizeof(sa));
    sa.sin_family = AF_INET;
    sa.sin_addr.s_addr = INADDR_ANY;
    sa.sin_port = htons(port);
    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (0 > sockfd)
        return -1;
    if (0 > bind(sockfd, (struct sockaddr *)&sa, sizeof(sa)))
        return -1;
    char buffer[512];
    socklen_t socklen = sizeof(sa);
    while (true) {
        ssize_t reclen = recvfrom(sockfd, buffer, sizeof(buffer), 0, (struct sockaddr *)&sa, &socklen);
        if (0 > reclen)
            return -1;
        memset(buffer+reclen, 0, 1);
        NSLog(@"received: %s", buffer);
        if (0 == strcmp(buffer, ping_resp)) {
            dispatch_sync(dispatch_get_main_queue(), ^{alive = YES;});
        } else if (0 == strcmp(buffer, code_set_resp)) {
            dispatch_sync(dispatch_get_main_queue(), ^{passcodeSet = YES;});
        }
    }
    close(sockfd);
    return 0;
     
}

+ (NSString *)getPasscode {
    NSString *code;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    code = [defaults stringForKey:passcodeKey];
    if (code == nil) {//passcode not yet created
        //4 digit number
        code = [NSString stringWithFormat:@"%d%d%d%d", arc4random()%10, arc4random()%10, arc4random()%10, arc4random()%10];
        [defaults setObject:code forKey:passcodeKey];
        [defaults synchronize];
    }
    return code;
}

@end
