//
//  utils.h
//  daemon
//
//  Created by connormckenna on 4/21/13.
//  Copyright (c) 2013 connormckenna. All rights reserved.
//

#ifndef daemon_utils_h
#define daemon_utils_h

uint32_t millis_since_epoch();
float distance(float x, float y);

inline uint32_t millis_since_epoch() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint32_t)(tv.tv_sec * 1000) + (uint32_t)(tv.tv_usec/1000);
}

inline float distance(float x, float y) {
    return sqrt(x * x + y * y);
}

inline void change_distance(float new_dist, float *x, float *y) {
    float ratio = *x / *y;
    *y = sqrt(sqrt((new_dist * new_dist) / (1 + ratio * ratio)));
    *x = ratio * *y;
}

#endif
