//
//  UCARSingle.h
//  UCarDriver
//
//  Created by 谢佳培 on 2020/10/16.
//  Copyright © 2020 szzc. All rights reserved.
//

#define SingleH(name) +(instancetype)share##name;

#define SingleM(name)  \
static id instanceMessages;\
+(instancetype)allocWithZone:(struct _NSZone *)zone\
{\
\
static dispatch_once_t onceToken;\
\
dispatch_once(&onceToken, ^{\
\
instanceMessages = [super allocWithZone:zone];\
\
});\
\
return instanceMessages;\
}\
-(id)copy\
{\
return instanceMessages;\
}\
+(instancetype)share##name\
{\
    \
    static dispatch_once_t onceToken;\
    \
    dispatch_once(&onceToken, ^{\
        \
        instanceMessages = [[self alloc]init];\
        \
    });\
    \
    return instanceMessages;\
}

