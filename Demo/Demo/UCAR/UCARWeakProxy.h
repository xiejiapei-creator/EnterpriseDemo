//
//  UCARWeakProxy.h
//  Demo
//
//  Created by 谢佳培 on 2020/11/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 用来存放弱对象的代理。它可以用来避免NSTimer或CADisplayLink导致的引用循环
@interface UCARWeakProxy : NSProxy

/// 代理目标
@property (nonatomic, weak, readonly) id target;

/// 为目标创建新的弱代理，返回一个新的代理对象
+ (instancetype)proxyWithTarget:(id)target;

@end

NS_ASSUME_NONNULL_END
