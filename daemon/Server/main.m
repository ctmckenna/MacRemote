//
//  main.m
//  Server
//
//  Created by connormckenna on 2/13/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <AppKit/AppKit.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/time.h>

static NSInteger height;
static NSInteger width;
static const uint32_t INTERVAL = 35 * 1000000;
static const int port = 10265;
static const char *ping_resp = ":-)";
static const size_t ping_resp_len = 3;

static const char *code_set_resp = "yes";
static const size_t code_set_resp_len = 3;

/*
 void PostMouseEvent(CGMouseButton button, CGEventType type, const CGPoint point) {
 CGEventRef theEvent = CGEventCreateMouseEvent(NULL, type, point, button);
 CGEventSetType(theEvent, type);
 CGEventPost(kCGHIDEventTap, theEvent);
 CFRelease(theEvent);
 }*/
#define DEF_SCALE .8
#define ROLL_SIZE 5
#define MIN_COLLECT_TIME 20

typedef enum event {
    click = 1,
    move,
    drag,
    up,
    ping,
    code,
    stop
} event_t;

void speed_to_scale(float speed, float *scale)
{
    static float max_speed = 4;
    static float max_scale = 5;
    static float min_scale = 1;
    
    float frac = speed >= max_speed ? 1 : speed/max_speed;
    *scale = max_scale * frac;
    if (*scale < min_scale)
        *scale = min_scale;
}

/*void smooth_delta(float *d_x, float *d_y, float *dist, uint32_t d_time)
 {
 static int head = 0;
 static float rolling_speeds[ROLL_SIZE];
 static float sum = 0;
 static bool speeds_initialized = false;
 if (speeds_initialized == false) {
 init_speeds(rolling_speeds, &sum);
 speeds_initialized = true;
 }
 float popped_speed = pop_head(rolling_speeds, &head);
 float new_speed = *dist / d_time;
 insert_tail(rolling_speeds, head, new_speed);
 sum -= popped_speed;
 sum += new_speed;
 float new_dist = (sum / ROLL_SIZE) * d_time;
 float slope = *d_y / (*d_x == 0 ? .001 : *d_x);
 if (slope < 0) slope *= -1;
 float new_x = sqrtf((new_dist * new_dist) / (1 + (slope * slope)));
 float new_y = new_x * slope;
 
 *d_x = *d_x >= 0 ? new_x : new_x * -1;
 *d_y = *d_y >= 0 ? new_y : new_y * -1;
 *dist = new_dist;
 }*/

int scale_delta(float *d_x, float *d_y)
{
    /* milliseconds since 1970 */
    static uint32_t last_time = 0;
    static float max_distance = 0;
    float scale;
    struct timeval tv;
    if (0 > gettimeofday(&tv, NULL))
        return -1;
    uint32_t millis = (uint32_t)tv.tv_sec * 1000 + tv.tv_usec/1000;
    if (0 == last_time) {
        last_time = millis;
        return -1;
    }
    uint32_t d_time = millis - last_time;
    //printf("t: %u\n", d_time);
    if (0 == d_time)
        return -1;
    
    float dist = sqrt(*d_x * *d_x + *d_y * *d_y);
    
    if (dist > max_distance)
        max_distance = dist;
    //printf("dist: %f MAX: %f\n", dist, max_distance);
    float speed = dist/d_time;
    //printf("before: speed: %f time: %u x: %f y: %f\n", speed, d_time, *d_x, *d_y);
    //smooth_delta(d_x, d_y, &dist, d_time);
    //printf("speed: %f time: %u x: %f y: %f\n", speed, d_time, *d_x, *d_y);
    //float speed = dist / d_time;
    speed_to_scale(speed, &scale);
    last_time = millis;
    
    // printf("new delta: x: %f y: %f\n", *d_x, *d_y);
    *d_x = *d_x * scale;
    *d_y = *d_y * scale;
    return 0;
}

bool x_in_bounds(CGPoint validPt, NSRect frame)
{
    return validPt.x > frame.origin.x && validPt.x < frame.origin.x + frame.size.width;
}

bool y_in_bounds(CGPoint validPt, NSRect frame)
{
    return validPt.y > frame.origin.y && validPt.y < frame.origin.y + frame.size.height;
}

int findScreen(CGPoint validPt, NSArray *screens, NSScreen **currentScreen)
{
    for (int i = 0; i < [screens count]; ++i) {
        NSScreen *screen = [screens objectAtIndex:i];
        NSRect frame = screen.frame;
        if (x_in_bounds(validPt, frame) && y_in_bounds(validPt, frame)) {
            *currentScreen = screen;
            return 0;
        }
    }
    return -1;
}

void validatePt(CGPoint from, CGPoint to, CGPoint *validPt)
{
    static NSScreen *currentScreen = NULL;
    NSArray *screens = [NSScreen screens];
    if (NULL == currentScreen || ![screens containsObject:currentScreen]) {
        if (0 > findScreen(from, screens, &currentScreen))
            currentScreen = [screens objectAtIndex:0];
    }
    if (x_in_bounds(to, currentScreen.frame) && y_in_bounds(to, currentScreen.frame)) {
        *validPt = to;
        return;
    }
    if (0 <= findScreen(to, screens, &currentScreen)) {
        *validPt = to;
        return;
    }
    NSRect curFrame = currentScreen.frame;
    if (to.x <= curFrame.origin.x)
        validPt->x = curFrame.origin.x+.1;
    else if (to.x >= curFrame.origin.x+curFrame.size.width)
        validPt->x = curFrame.origin.x+curFrame.size.width-1;
    else
        validPt->x = to.x;
    if (to.y <= curFrame.origin.y)
        validPt->y = curFrame.origin.y+.1;
    else if (to.y > curFrame.origin.y+curFrame.size.height)
        validPt->y = curFrame.origin.y+curFrame.size.height;
    else
        validPt->y = to.y;
}

int getNewPoint(float x, float y, CGPoint *newPt)
{
    if (0 > scale_delta(&x, &y))
        return -1;
    //get_scaling(&scale, x, y);
    CGPoint pt;
    NSPoint curPt = [NSEvent mouseLocation];
    pt.x = curPt.x + x;
    pt.y = (curPt.y - y);
    validatePt(curPt, pt, newPt);
    newPt->y = height - newPt->y;
    return 0;
}

void getCurPoint(CGPoint *pt) {
    NSPoint curPt = [NSEvent mouseLocation];
    pt->x = curPt.x;
    pt->y = height - curPt.y;
}

void mouseMove(float x, float y)
{
    CGPoint newPt;
    if (0 > getNewPoint(x, y, &newPt))
        return;
    CGEventRef ev = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, newPt, kCGMouseButtonLeft);
    CGEventPost(kCGHIDEventTap, ev);
    CFRelease(ev);
}

void mouseDrag(float x, float y, bool is_dragging)
{
    CGPoint oldPt;
    CGPoint newPt;
    
    getCurPoint(&oldPt);
    if (0 > getNewPoint(x, y, &newPt))
        return;
    CGEventRef ev = NULL;
    
    if (!is_dragging) {
        ev = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, oldPt, kCGMouseButtonLeft);
        CGEventPost(kCGHIDEventTap, ev);
        CGEventSetType(ev, kCGEventLeftMouseDragged);
        CGEventSetLocation(ev, newPt);
        CGEventPost(kCGHIDEventTap, ev);
    } else {
        ev = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDragged, newPt, kCGMouseButtonLeft);
        CGEventPost(kCGHIDEventTap, ev);
    }
    CFRelease(ev);
}

void mouseClick()
{
    NSPoint curPt = [NSEvent mouseLocation];
    curPt.y = height - curPt.y;
    CGEventRef ev = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, curPt, kCGMouseButtonLeft);
    CGEventPost(kCGHIDEventTap, ev);
    CGEventSetType(ev, kCGEventLeftMouseUp);
    CGEventPost(kCGHIDEventTap, ev);
    CFRelease(ev);
}

void mouseUp()
{
    NSPoint curPt = [NSEvent mouseLocation];
    curPt.y = height - curPt.y;
    CGEventRef ev = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, curPt, kCGMouseButtonLeft);
    CGEventPost(kCGHIDEventTap, ev);
    CFRelease(ev);
}

int handle_events(int sockfd, socklen_t socklen, struct sockaddr_in sa) {
    char buffer[512];
    size_t buf_len = sizeof(buffer);
    ssize_t rec_len;
    int x_i;
    int y_i;
    float x;
    float y;
    char ping_msg[255];
    static char secret_code[255];
    static bool is_dragging = false;
    static bool stopped = false;
    while (true) {
        rec_len = recvfrom(sockfd, buffer, buf_len, 0, (struct sockaddr *)&sa, &socklen);
        if (rec_len < 0) {
            perror("error receiving message");
            exit(EXIT_FAILURE);
        }
        if (rec_len < 1)
            continue;
        char ev = buffer[0];
        if (stopped && ev != code)
            continue;
        switch(ev) {
            case click:
                mouseClick();
                break;
            case move:
                if (buf_len < 9)continue;
                x_i = (int)ntohl(*(uint32_t *)(buffer+1));
                y_i = (int)ntohl(*(uint32_t *)(buffer+5));
                x = (float)x_i / 1000.0;
                y =  (float)y_i / 1000.0;
                mouseMove(x, y);
                break;
            case drag:
                if (buf_len < 9) continue;
                x_i = (int)ntohl(*(uint32_t *)(buffer+1));
                y_i = (int)ntohl(*(uint32_t *)(buffer+5));
                x = (float)x_i / 1000.0;
                y =  (float)y_i / 1000.0;
                mouseDrag(x, y, is_dragging);
                is_dragging = true;
                break;
            case up:
                is_dragging = false;
                mouseUp();
                break;
            case ping:
                strncpy(ping_msg, buffer+1, rec_len-1);
                memset(ping_msg+rec_len-1, '\0', 1);
                if (0 == strcmp(ping_msg, secret_code)) {
                    sa.sin_port = htons(port+1);
                    sendto(sockfd, ping_resp, ping_resp_len, 0, (struct sockaddr *)&sa, socklen);
                }
                break;
            case code:
                stopped = false;
                strncpy(secret_code, buffer+1, rec_len-1);
                memset(secret_code + rec_len - 1, '\0', 1);
                sa.sin_port = htons(port+1);
                sendto(sockfd, code_set_resp, code_set_resp_len, 0, (struct sockaddr *)&sa, socklen);
                break;
            case stop:
                stopped = true;
                break;
            default:
                continue;
        }
    }
    return 0;
}

int main(int argc, const char * argv[])
{
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    height = [[[NSScreen screens] objectAtIndex:0] frame].size.height;
    width = [[[NSScreen screens] objectAtIndex:0] frame].size.width;
    struct sockaddr_in sa;
    memset(&sa, 0, sizeof(sa));
    sa.sin_family = AF_INET;
    sa.sin_addr.s_addr = INADDR_ANY;
    sa.sin_port = htons(port);
    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd == -1) {
        printf("%s", "Error creating socket\n");
        exit(EXIT_FAILURE);
    }
    socklen_t socklen = sizeof(sa);
    
    int rec = bind(sockfd, (struct sockaddr *)&sa, socklen);
    if (rec == -1) {
        fprintf(stderr, "failed to bind. :( !!!\n");
        exit(EXIT_FAILURE);
    }
    
    if (0 > handle_events(sockfd, socklen, sa)) {
        fprintf(stderr, "event handler broked :(");
        exit(EXIT_FAILURE);
    }
    
    [pool release];
    return 0;
}