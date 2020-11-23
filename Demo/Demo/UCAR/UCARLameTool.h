//
//  UCARLameTool.h
//  UCarDriver
//
//  Created by 谢佳培 on 2020/10/16.
//  Copyright © 2020 szzc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UCARSingle.h"

NS_ASSUME_NONNULL_BEGIN

@interface UCARLameTool : NSObject

/** 工具类单例 */
SingleH(UCARLameTool)

/** 采样率，可配置，默认为11025.0 */
@property (nonatomic, assign) int sampleRate;

/** 录音完成的调用 */
- (void)sendEndRecord;

/**caf 转 mp3 ：录音完成后根据用户需要去调用转码
 * @param sourcePath 需要转mp3的caf路径
 * @param isDelete 是否删除原来的caf文件，YES：删除、NO：不删除
 * @param success 成功的回调
 * @param fail 失败的回调
 */
- (void)audioToMP3:(NSString *)sourcePath isDeleteSourchFile: (BOOL)isDelete withSuccessBack:(void(^)(NSString *resultPath))success withFailBack:(void(^)(NSString *error))fail;

/**caf 转 mp3 : 录音的同时转码
 * @param sourcePath 需要转mp3的caf路径
 * @param isDelete 是否删除原来的caf文件，YES：删除、NO：不删除
 * @param success 成功的回调
 * @param fail 失败的回调
 */
- (void)audioRecodingToMP3:(NSString *)sourcePath isDeleteSourchFile: (BOOL)isDelete withSuccessBack:(void(^)(NSString *resultPath))success withFailBack:(void(^)(NSString *error))fail;


@end

NS_ASSUME_NONNULL_END
