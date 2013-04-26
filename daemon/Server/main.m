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
#import "Package/Package.h"
#include <pthread.h>
#include "utils.h"
#include <sys/event.h>

static NSInteger height;
static NSInteger width;
static const uint32_t INTERVAL = 35 * 1000000;
static const int port = 10265;
static const char *ping_resp = ":-)";
static const size_t ping_resp_len = 3;

static const char *passcode = "";

#define EPSILON (.0001)

#define MOVE_LEN (sizeof(char) + sizeof(int) + sizeof(int) + sizeof(int))

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
    volume,
    scroll
} event_t;

typedef enum direction {
    UP,
    DOWN,
    RIGHT,
    LEFT
} direction_t;

struct scroll_data {
    float x;
    float y;
    uint32_t ts;
    uint32_t data_id;
};

static struct scroll_data scroll_data;

void speed_to_scale(float speed, float *scale)
{
    static float max_speed = 8;
    static float max_scale = 15;
    static float min_scale = 1;
    
    float frac = speed >= max_speed ? 1 : speed/max_speed;
    *scale = max_scale * frac;
    if (*scale < min_scale)
        *scale = min_scale;
}

int get_speed(float *d_x, float *d_y, uint32_t ts, float *speed)
{
    /* milliseconds since 1970 */
    static uint32_t last_time = 0;
    if (0 == last_time) {
        last_time = ts;
        return -1;
    }
    uint32_t d_time = ts - last_time;
    if (0 == d_time)
        return -1;
    
    float dist = distance(*d_x, *d_y);
    
    *speed = dist/d_time;
    last_time = ts;
    return 0;
    
}

int scale_delta(float *d_x, float *d_y, uint32_t ts)
{
    float scale;
    float speed;
    if (0 > get_speed(d_x, d_y, ts, &speed))
        return -1;
    speed_to_scale(speed, &scale);
    
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

int getNewPoint(float x, float y, CGPoint *newPt, uint32_t ts)
{
    if (0 > scale_delta(&x, &y, ts))
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

void mouseMove(float x, float y, uint32_t ts)
{
    CGPoint newPt;
    if (0 > getNewPoint(x, y, &newPt, ts))
        return;
    CGEventRef ev = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, newPt, kCGMouseButtonLeft);
    CGEventPost(kCGHIDEventTap, ev);
    CFRelease(ev);
}

void mouseDrag(float x, float y, bool is_dragging, uint32_t ts)
{
    CGPoint oldPt;
    CGPoint newPt;
    
    getCurPoint(&oldPt);
    if (0 > getNewPoint(x, y, &newPt, ts))
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

void postScroll(int scroll_x, int scroll_y)
{
   // printf("scroll: [x: %d] [y: %d]\n", scroll_x, scroll_y);
    CGEventRef ev = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitPixel, 2, scroll_y, scroll_x);
    CGEventPost(kCGHIDEventTap, ev);
    CFRelease(ev);
}

void server_sleep(long millis)
{
    struct timespec ts;
    size_t nanoseconds = millis * 1000000;
    ts.tv_nsec = nanoseconds % 1000000000;
    ts.tv_sec = nanoseconds  / 1000000000;
    nanosleep(&ts, NULL);
}

void adjust_speed(double distance_traveled, double friction, double *speed)
{
    double c = sqrt((*speed * *speed) - (2 * distance_traveled * friction));
    double time = ((*speed * -1) + c) / (friction * -1);
    *speed = *speed - (time * friction);
}

double get_distance_traveled(double speed, double friction, time_t time, bool *hit_end)
{
    time_t time_left = speed / friction;
    if (time_left < time) {
        *hit_end = true;
        time = time_left;
    }
    return (time * speed) - (0.5 * (time * time) * friction);
}

direction_t get_direction(struct scroll_data sd)
{
    direction_t direction = UP;
    if (sd.y < 0)
        direction = DOWN;
    else if (sd.x > 0)
        direction = RIGHT;
    else if (sd.x < 0)
        direction = LEFT;
    return direction;
}

struct scroll_data get_data_diff(struct scroll_data shared_data, struct scroll_data *local_data)
{
    struct scroll_data actionable_data;
    float x = shared_data.x - local_data->x;
    float y = shared_data.y - local_data->y;
    if (x * x > y * y) {
        actionable_data.x = x;
        actionable_data.y = 0;
    } else {
        actionable_data.x = 0;
        actionable_data.y = y;
    }
    actionable_data.ts = shared_data.ts;
    actionable_data.data_id = shared_data.data_id;
    
    local_data->x = shared_data.x;
    local_data->y = shared_data.y;
    local_data->ts = shared_data.ts;
    local_data->data_id = shared_data.data_id;
    return actionable_data;
}

/*
 speed is units per second
 */
void *mouseScroll(void *ptr)
{
    static const double FRICTION = ((double)1 / (double)120);        // units of velocity lost per second
    static const double SPEED_FACTOR = 5;
    int fd = *(int *)ptr;
    long res;
    uint8_t t;
    double speed = 0;
    time_t last_time = 0;
    struct scroll_data data_buf;
    memset(&data_buf, 0, sizeof(data_buf));
    while (true) {
        if (0 >= (res = read(fd, &t, sizeof(t))))
            continue;
        last_time = data_buf.ts;
        struct scroll_data new_data = get_data_diff(scroll_data, &data_buf);
        if (new_data.x == 0 && new_data.y == 0)
            continue;
        //printf("x: %f y: %f t: %ld\n", new_data.x, new_data.y, new_data.ts - last_time);
        speed = (distance(new_data.x, new_data.y) / (new_data.ts - last_time)) * SPEED_FACTOR;
        //printf("speed: %f\n", speed);
        direction_t direction = get_direction(new_data);
        time_t post_sleep = millis_since_epoch();
        time_t pre_sleep = post_sleep - 35;
        bool hit_end = false;
        while (speed > EPSILON) {
            int distance_traveled = (int)get_distance_traveled(speed, FRICTION, post_sleep - pre_sleep, &hit_end);
            //printf("distance traveled: %d sleep: %ld\n", distance_traveled, post_sleep - pre_sleep);
            if (hit_end && distance_traveled <= 0)
                break;
            switch (direction) {
                case UP:
                    postScroll(0, distance_traveled);
                    break;
                case DOWN:
                    postScroll(0, distance_traveled * -1);
                    break;
                case LEFT:
                    postScroll(distance_traveled * -1, 0);
                    break;
                case RIGHT:
                    postScroll(distance_traveled, 0);
                    break;
            }
            if (scroll_data.data_id != new_data.data_id)
                break;
            pre_sleep = post_sleep;
            adjust_speed(distance_traveled, FRICTION, &speed);
            server_sleep(25);
            post_sleep = millis_since_epoch();
            
        }
    }
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

void set_volume(int volume_change, uint32_t timestamp)
{
    static NSString *setVolume = @"set volume output volume ((output volume of (get volume settings)) + %d)";
    static NSMutableArray *cmd = nil;
    if (cmd == nil)
        cmd = [[NSMutableArray alloc] initWithObjects:@"/usr/bin/osascript", @"-e", nil];
    [cmd addObject:[NSString stringWithFormat:setVolume, volume_change]];
    [Package runCommandWithArgs:cmd];
    [cmd removeObjectAtIndex:[cmd count]-1];
    NSSound *sound = [NSSound soundNamed:@"volume"];
    [sound play];
}

void parse_move_buf(char *buffer, float *x, float *y, uint32_t *timestamp) {
    int x_i = (int)ntohl(*(uint32_t *)(buffer+1));
    int y_i = (int)ntohl(*(uint32_t *)(buffer+5));
    *timestamp = (uint32_t)ntohl(*(uint32_t *)(buffer + 9));
    *x = (float)x_i / 1000.0;
    *y =  (float)y_i / 1000.0;
}

void check_kill_scroll(char ev, uint32_t timestamp) {
    switch(ev) {
        case click:
        case move:
        case drag:
            if (timestamp - scroll_data.ts > 600)
                scroll_data.data_id += 1;
            break;
    }
}

int handle_events(int sockfd, socklen_t socklen, struct sockaddr_in sa) {
    char buffer[512];
    size_t buf_len = sizeof(buffer);
    ssize_t rec_len;
    int volume_change;
    float x;
    float y;
    uint32_t timestamp;
    char ping_msg[255];
    static bool is_dragging = false;
    pthread_t scroll_thread;
    uint8_t t = 0;
    static int scroll_pipe[2] = {-1, -1};
    if (0 > pipe(scroll_pipe))
        return -1;
    pthread_create(&scroll_thread, NULL, &mouseScroll, &scroll_pipe[0]);
    while (true) {
        rec_len = recvfrom(sockfd, buffer, buf_len, 0, (struct sockaddr *)&sa, &socklen);
        if (rec_len < 0) {
            perror("error receiving message");
            exit(EXIT_FAILURE);
        }
        if (rec_len < 1)
            continue;
        char ev = buffer[0];
        switch(ev) {
            case click:
                scroll_data.data_id += 1;
                mouseClick();
                break;
            case move:
                if (rec_len < MOVE_LEN)continue;
                scroll_data.data_id += 1;
                parse_move_buf(buffer, &x, &y, &timestamp);
                mouseMove(x, y, timestamp);
                break;
            case drag:
                if (rec_len < MOVE_LEN) continue;
                scroll_data.data_id += 1;
                parse_move_buf(buffer, &x, &y, &timestamp);
                mouseDrag(x, y, is_dragging, timestamp);
                is_dragging = true;
                break;
            case up:
                is_dragging = false;
                mouseUp();
                break;
            case ping:
                strncpy(ping_msg, buffer+1, rec_len-1);
                memset(ping_msg+rec_len-1, '\0', 1);
                if (rec_len - 1 != strlen(passcode))//1 event character
                    break;
                if (0 == memcmp(buffer + 1, passcode, rec_len - 1)) {
                    sa.sin_port = htons(port+1);
                    sendto(sockfd, ping_resp, ping_resp_len, 0, (struct sockaddr *)&sa, socklen);
                }
                break;
            case volume:
                if (rec_len < 5) continue;
                volume_change = (int)ntohl(*(uint32_t *)(buffer + 1));
                timestamp = (uint32_t)ntohl(*(uint32_t *)(buffer + 5));
                set_volume(volume_change, timestamp);
                break;
            case scroll: 
                if (rec_len < MOVE_LEN) continue;
                parse_move_buf(buffer, &x, &y, &timestamp);
                scroll_data.x += x;
                scroll_data.y += y;
                scroll_data.ts = timestamp;
                scroll_data.data_id += 1;
                write(scroll_pipe[1], &t, sizeof(t));
            default:
                continue;
        }
        check_kill_scroll(ev, timestamp);
    }
    return 0;
}

int main(int argc, const char * argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    height = [[[NSScreen screens] objectAtIndex:0] frame].size.height;
    width = [[[NSScreen screens] objectAtIndex:0] frame].size.width;
    if (argc >= 2) {
        passcode = argv[1];
    }
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