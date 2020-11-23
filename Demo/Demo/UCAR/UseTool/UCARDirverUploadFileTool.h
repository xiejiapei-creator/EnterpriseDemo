//
//  UCARDirverUploadFileTool.h
//  Demo
//
//  Created by 谢佳培 on 2020/11/23.
//

#import <Foundation/Foundation.h>
#import "UCARRecordSoundTool.h"

NS_ASSUME_NONNULL_BEGIN

/// 接口传入的可以配置的参数数据
@interface UCARAudioRecordConfig : NSObject

/// 每段录音时间(s)
@property (nonatomic, assign) NSInteger duration;
/// 结束录音延迟时间(s)
@property (nonatomic, assign) NSInteger laterStopTime;
/// 司机端存储空间(M)
@property (nonatomic, assign) NSInteger maxFileSize;
/// 司机端定时检测间隔(s)
@property (nonatomic, assign) NSInteger scanInterval;
/// 录音文件码率(kbps)
@property (nonatomic, assign) int encodingBitRate;
/// 采样率，单位Hz
@property (nonatomic, assign) int samplingRate;
/// 录音文件格式
@property (nonatomic, copy) NSString *extName;

@end

@interface UCARDirverUploadFileTool : NSObject

/** 工具类单例 */
SingleH(UCARDirverUploadFileTool)

/** 启动定时上传录音 */
- (void)uploadTaskWithFireTime;

/** 停止定时上传录音 */
- (void)stopUploadTask;

/** 根据配置参数开启录音 */
- (void)startRecordWithOrderNumber:(NSString *)orderNumber driverID:(NSString *)driverID;

/** 延迟结束录音 */
- (void)endTripRecordAfterDelay;

/** 立即结束录音 */
- (void)stopRecordAudio;

@end

NS_ASSUME_NONNULL_END
