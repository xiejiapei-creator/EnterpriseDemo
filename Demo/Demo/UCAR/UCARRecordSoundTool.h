//
//  UCARRecordSoundTool.h
//  UCarDriver
//
//  Created by 谢佳培 on 2020/10/16.
//  Copyright © 2020 szzc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "UCARSingle.h"

NS_ASSUME_NONNULL_BEGIN

// 录音文件的委托
@protocol UCARRecordSoundToolDelegate <NSObject>

/** 上传录音文件的委托方法 */
- (void)uploadRecordingFileWithEncryptedRecorderFilePath:(NSString *)uploadFilePath;

@end

@interface UCARRecordSoundTool : NSObject

/** 工具类单例 */
SingleH(UCARRecordSoundTool)

/** 委托 */
@property (nonatomic, weak) id<UCARRecordSoundToolDelegate> delegate;

/** 正在录制的订单号 */
@property (nonatomic, copy) NSString *recordingOrderNumber;

/** 录音文件的目录路径 */
@property (nonatomic, copy, readonly) NSString *recordCachePath;

/** 录音间隔时间，以秒为单位，可配置，默认3分钟 */
@property(nonatomic,assign) NSTimeInterval timeInterval;

/** 录音文件最大占用内存大小，以MB为单位，可配置，默认1024MB */
@property(nonatomic,assign) double maximumMemory;

/** 用于加密的key，可配置，默认为一串随机数  */
@property (nonatomic, copy) NSString *encryptKey;

/** 加密文件的后缀，可配置，默认为UCAR */
@property (nonatomic, copy) NSString *modifySuffix;

/** 音频文件原始后缀名，可配置，默认为MP3 */
@property (nonatomic, copy) NSString *originalSuffix;

/** 采样率，可配置，默认为11025 */
@property (nonatomic, assign) int sampleRate;

/** 比特率，可配置，默认为128kbps */
@property (nonatomic, assign) int bitRate;

/**司机到达，开始录音
 * @param orderNumber 订单号
 * @param driverID 司机ID
 */
-(void)startRecordWithOrderNumber:(NSString *)orderNumber driverID:(NSString *)driverID;

/** 是否正在录音 */
- (BOOL)carIsRecording;

/** 结束行程 */
-(void)endTrip;

/**用于将因中断等原因未自动转换成功的caf文件和mp3文件加密转化为UCAR文件
 * @return 转化而成的UCAR文件的数据列表用于上传
 */
- (NSArray *)convertAudioToUCARWithEncryptKey:(NSString *)encryptKey modifySuffix:(NSString *)modifySuffix sampleRate:(int)sampleRate;

/**删除录音文件
 * @param recordFilePath 录音文件的路径
 */
- (void)deleteRecordFileWithFilePath:(NSString *)recordFilePath;

/**获得目录下的所有UCAR文件数据，可用于上传
 * @return 所有UCAR文件数据
 */
- (NSArray *)getAllUCARRecorderFilesData;

/**获得目录下的所有UCAR文件
 * @return 所有UCAR文件
 */
- (NSArray *)getAllUCARRecorderFiles;

/** 因为录音中断，将recording标志删除掉，变成录音完成的文件 */
- (void)convertRecordingFileToFinishedFile;

/**删除录制中的文件的.recording表示该文件已经录制完成
 * @return 返回删除.recording标志后的新路径
 */
- (NSString *)deleteRecordingTagWithFilePath:(NSString *)recorderFilePath;

/** 对目录下的所有UCAR音频文件进行解密，作测试用 */
- (void)decryptAllUCARRecorderFilesWithEncryptKey:(NSString *)encryptKey modifySuffix:(NSString *)modifySuffix;

@end

NS_ASSUME_NONNULL_END
