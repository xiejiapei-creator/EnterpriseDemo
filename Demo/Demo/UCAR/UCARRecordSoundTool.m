//
//  UCARRecordSoundTool.m
//  UCarDriver
//
//  Created by 谢佳培 on 2020/10/16.
//  Copyright © 2020 szzc. All rights reserved.
//UCAR

#import "UCARRecordSoundTool.h"
#import "UCARRecorderKit.h"

@interface UCARRecordSoundTool()<AudioToolDelegate>

/** 录音文件的路径 */
@property (nonatomic, copy, readwrite) NSString *recordCachePath;

@end

@implementation UCARRecordSoundTool

// 工具类单例
SingleM(UCARRecordSoundTool)

// 司机到达，开始录音
-(void)startRecordWithOrderNumber:(NSString *)orderNumber driverID:(NSString *)driverID
{
    NSLog(@"司机到达，开始录音");
    
    // 委托对象
    [UCARAudioTool shareUCARAudioTool].delegate = self;
    
    // 正在录制中的订单号
    self.recordingOrderNumber = orderNumber;
    
    // 配置默认参数
    [self defaultParameterConfiguration];

    // 初始化录制状态为未录制
    [UCARAudioTool shareUCARAudioTool].isRecording = NO;
    // 录音文件每3分钟保存一个文件，保存成功则录制下一段，时长可配置，以秒为单位
    [UCARAudioTool shareUCARAudioTool].timeInterval = self.timeInterval;
    // 音频文件在司机端本地最多占用1024M存储空间，空间满时自动覆盖生成时间最早的文件，空间上限可配置
    [UCARAudioTool shareUCARAudioTool].maximumMemory = self.maximumMemory;
    
    // 需要订单号 + 司机ID + 当前日期重新生成3分钟录音文件的文件名
    [UCARAudioTool shareUCARAudioTool].orderNumber = orderNumber;
    [UCARAudioTool shareUCARAudioTool].driverID = driverID;
    
    // 加密
    [UCARAudioTool shareUCARAudioTool].encryptKey = self.encryptKey;
    [UCARAudioTool shareUCARAudioTool].modifySuffix = self.modifySuffix;
    
    NSDictionary *dict = @{@"encryptKey": self.encryptKey, @"modifySuffix": self.modifySuffix, @"sampleRate": @(self.sampleRate)};
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *recorderPlistPath = [documentPath stringByAppendingPathComponent:@"Recorder.plist"];
    NSURL *recorderPlistPathUrl = [NSURL fileURLWithPath:recorderPlistPath];
    if ( [dict writeToURL:recorderPlistPathUrl atomically:YES] )
    {
        NSLog(@"加密密钥成功写入Plist文件，路径为：%@",recorderPlistPath);
    }
    
    // 原始文件后缀名
    [UCARAudioTool shareUCARAudioTool].originalSuffix = self.originalSuffix;
    
    // 比特率和采样率
    [UCARAudioTool shareUCARAudioTool].sampleRate = self.sampleRate;
    [UCARAudioTool shareUCARAudioTool].bitRate = self.bitRate * 1000;
    
    // 开始录音，以caf作为录音原始文件后缀
    NSString *newRecorderName = [[UCARAudioTool shareUCARAudioTool] createRecordFileNameWithOrderNumber:orderNumber driverID:driverID];
    [[UCARAudioTool shareUCARAudioTool] beginRecordWithRecordName:newRecorderName withRecordType:@"caf" withIsConventToMp3:YES];
}

// 结束行程
-(void)endTrip
{
    NSLog(@"抵达目的地，行程结束");
    
    // 结束行程时，把当前正在录制的音频保存，可能不足3分钟
    [UCARAudioTool shareUCARAudioTool].isEndTrip = YES;
    [[UCARAudioTool shareUCARAudioTool] endRecord];
}

// 用于将因中断等原因未自动转换成功的caf文件和mp3文件加密转化为UCAR文件
- (NSArray *)convertAudioToUCARWithEncryptKey:(NSString *)encryptKey modifySuffix:(NSString *)modifySuffix sampleRate:(int)sampleRate
{
    NSArray *UCARAudioDataList = [[UCARAudioTool shareUCARAudioTool] convertAudioToUCARWithEncryptKey:encryptKey modifySuffix:modifySuffix sampleRate:sampleRate];
    return UCARAudioDataList;
}

// 获得所有的录音文件
- (BOOL)carIsRecording
{
    return [[UCARAudioTool shareUCARAudioTool] carIsRecording];
}

// 删除录音文件
- (void)deleteRecordFileWithFilePath:(NSString *)recordFilePath
{
    [[UCARAudioTool shareUCARAudioTool] deleteRecordFileWithFilePath:recordFilePath];
}

// 获得目录下的所有UCAR文件数据，可用于上传
- (NSArray *)getAllUCARRecorderFilesData
{
    NSArray *UCARAudioList = [[UCARAudioTool shareUCARAudioTool] getAllUCARRecorderFiles];
    // 存储UCAR文件的数据
    NSMutableArray *UCARAudioDataList = [NSMutableArray array];
    if (UCARAudioList.count > 0)
    {
        for (NSString *UCARRecorderFilePath in UCARAudioList)
        {
            NSData *UCARRecorderFileData = [NSData dataWithContentsOfFile:UCARRecorderFilePath];
            [UCARAudioDataList addObject:UCARRecorderFileData];
        }
    }
    return UCARAudioDataList;
}

// 获得目录下的所有UCAR文件
- (NSArray *)getAllUCARRecorderFiles
{
    return [[UCARAudioTool shareUCARAudioTool] getAllUCARRecorderFiles];
}

// 因为录音中断，将recording标志删除掉，变成录音完成的文件
- (void)convertRecordingFileToFinishedFile
{
    [[UCARAudioTool shareUCARAudioTool] convertRecordingFileToFinishedFile];
}

// 删除录制中的文件的.recording表示该文件已经录制完成
- (NSString *)deleteRecordingTagWithFilePath:(NSString *)recorderFilePath
{
    NSString *deleteRecordingTagFilePath = [[UCARAudioTool shareUCARAudioTool] deleteRecordingTagWithFilePath:recorderFilePath];
    return deleteRecordingTagFilePath;
}

// 上传录音文件的委托方法
- (void)uploadRecordingFileWithEncryptedRecorderFilePath:(NSString *)recorderFilePath
{
    // 调用上传录音文件
    if (self.delegate && [self.delegate respondsToSelector:@selector(uploadRecordingFileWithEncryptedRecorderFilePath:)])
    {
        [self.delegate uploadRecordingFileWithEncryptedRecorderFilePath:recorderFilePath];
    }
}

// 对目录下的所有UCAR音频文件进行解密，作测试用
- (void)decryptAllUCARRecorderFilesWithEncryptKey:(NSString *)encryptKey modifySuffix:(NSString *)modifySuffix
{
    [[UCARAudioTool shareUCARAudioTool] decryptAllUCARRecorderFilesWithEncryptKey:encryptKey modifySuffix:modifySuffix];
}

// 配置默认参数
- (void)defaultParameterConfiguration
{
    if (!self.maximumMemory)
    {
        self.maximumMemory = 1024;
    }
    
    if (!self.timeInterval)
    {
        self.timeInterval = 180.0;
    }
    
    if (!self.encryptKey)
    {
        self.encryptKey = @"U2FsdGVkX1+21W0Epk68cW2rlAt/TuHcDO4A+UYtbjI=";
    }
    
    if (!self.modifySuffix)
    {
        self.modifySuffix = @"UCAR";
    }
    
    if (!self.originalSuffix)
    {
        self.originalSuffix = @"MP3";
    }
    
    if (!self.sampleRate)
    {
        self.sampleRate = 11025;
    }
    
    if (!self.bitRate)
    {
        self.bitRate = 128;
    }
}

// 录音文件的目录路径
- (NSString *)recordCachePath
{
    return [UCARAudioTool shareUCARAudioTool].recordCachePath;
}

@end

