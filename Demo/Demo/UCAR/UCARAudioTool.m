//
//  UCARAudioTool.m
//  UCarDriver
//
//  Created by 谢佳培 on 2020/10/16.
//  Copyright © 2020 szzc. All rights reserved.
//

#import "UCARAudioTool.h"
#import "UCARLameTool.h"
#import "UCARAudioFilePathTool.h"
#import "RNCryptor iOS.h"
#include <mach/mach.h> //获取CPU信息所需要引入的头文件

// 录音存放的文件夹 /Library/Caches/Recorder
#define cachesRecorderPath [NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Caches/Recorder"]

@interface UCARAudioTool()<AVAudioRecorderDelegate, AVAudioPlayerDelegate>

// 录音对象
@property (nonatomic, strong) AVAudioRecorder *audioRecorder;

// 录音文件的名字
@property (nonatomic, strong) NSString *audioFileName;

// 录音的类型
@property (nonatomic, strong) NSString *recordType;

// 录音文件路径
@property (nonatomic, copy, readwrite) NSString *recordPath;

// 是否边录边转mp3
@property (nonatomic, assign) BOOL isConventMp3;

// 计时器
@property (nonatomic, strong) dispatch_source_t timer;

// 录音文件路径数组
@property (nonatomic, strong) NSArray *audioPathList;

@end


@implementation UCARAudioTool

// 工具类单例
SingleM(UCARAudioTool)

#pragma mark - 录音权限

// 检查授权状态
- (void)checkMicrophoneAuthorization:(void (^)(void))permissionGranted withNoPermission:(void (^)(BOOL error))noPermission
{
    // 获取音频媒体授权状态
    AVAuthorizationStatus audioAuthorizationStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (audioAuthorizationStatus)
    {
        case AVAuthorizationStatusNotDetermined:
        {
            // 第一次进入APP提示用户授权
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
                
                granted ? permissionGranted() : noPermission(NO);
            }];
            break;
        }
        case AVAuthorizationStatusAuthorized:
        {
            // 通过授权
            permissionGranted();
            break;
        }
        case AVAuthorizationStatusRestricted:
        {
            // 拒绝授权
            noPermission(YES);
            break;
        }
        case AVAuthorizationStatusDenied:
        {
            // 提示跳转到相机设置(这里使用了blockits的弹窗方法）
            noPermission(NO);
            break;
        }
        default:
            break;
    }
}

#pragma mark - 录音文件名称

// 获取当前日期
- (NSDate *)getCurrentDate
{
    // 设置想要的格式
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init] ;
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    // hh与HH的区别:分别表示12小时制，24小时制
    [formatter setDateFormat:@"YYYY-MM-dd HH:mm:ss SSS"];

    // 设置时区，这一点对时间的处理有时很重要
    NSTimeZone* timeZone = [NSTimeZone timeZoneWithName:@"Asia/Shanghai"];
    [formatter setTimeZone:timeZone];

    // 当前日期
    return [NSDate date];
}

// 生成的音频文件需包含必要信息，以便上传后系统可关联到对应订单和司机
// 信息存储在文件名中，以便上传失败时候仍然能够找到音频文件对应信息
// 需包含：订单号_司机ID_开始毫秒时间戳_结束毫秒时间戳_音频文件原始后缀名
- (NSString *)createRecordFileNameWithOrderNumber:(NSString *)orderNumber driverID:(NSString *)driverID
{

    // 开始录制日期
    NSDate *startRecordDate = [self getCurrentDate];
    
    // 3分钟后录制下一段
    NSTimeInterval duration = self.timeInterval;
    // 结束录制日期
    NSDate *endRecordDate = [startRecordDate initWithTimeIntervalSinceNow: duration];
    
    // 开始录制时间的毫秒时间戳
    NSString *startRecordingTime = [NSString stringWithFormat:@"%ld", (long)[startRecordDate timeIntervalSince1970] * 1000];
    // 结束录制时间的毫秒时间戳
    NSString *endRecordingTime = [NSString stringWithFormat:@"%ld", (long)[endRecordDate timeIntervalSince1970] * 1000];
    
    // 音频文件原始后缀名
    NSString *originalSuffix = self.originalSuffix;
    
    NSString *newRecorderName = [NSString stringWithFormat:@"%@_%@_%@_%@_%@",orderNumber,driverID,startRecordingTime,endRecordingTime,originalSuffix];
    return newRecorderName;
}

// 结束行程时未满3分钟需要给录音文件重新命名
- (NSString *)renameEndTripRecordingFileWithFilePath:(NSString *)recorderFilePath
{
    // 替换行程结束时间为准确的系统当前时间
    NSString *path = recorderFilePath;
    NSString *recordFileName = [path lastPathComponent];
    NSArray *fileComponent = [recordFileName componentsSeparatedByString:@"_"];
    NSString *endRecordTime = fileComponent[3];
    NSDate *endTripDate = [self getCurrentDate];
    NSString *endTripTime = [NSString stringWithFormat:@"%ld", (long)[endTripDate timeIntervalSince1970] * 1000];
    NSString *modifyTimeRecorderFilePath = [path stringByReplacingOccurrencesOfString:endRecordTime withString:endTripTime];
    
    // 在原文件夹给录音文件重新命名
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager moveItemAtPath:recorderFilePath toPath:modifyTimeRecorderFilePath error:nil];
    
    return modifyTimeRecorderFilePath;
}

// 删除录制中的文件的.recording表示该文件已经录制完成
- (NSString *)deleteRecordingTagWithFilePath:(NSString *)recorderFilePath
{
    NSString *recordFileName = [recorderFilePath lastPathComponent];
    NSString *recordingTag = [recordFileName substringWithRange:NSMakeRange(0, 10)];
    NSString *deleteRecordingTagFilePath = [recorderFilePath stringByReplacingOccurrencesOfString:recordingTag withString:@""];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager moveItemAtPath:recorderFilePath toPath:deleteRecordingTagFilePath error:nil];
    
    return deleteRecordingTagFilePath;
}

// 中断录音需要删除不确定的结束时间
// 删除录制中的文件的.recording表示该文件已经录制完成
- (NSString *)deleteRecordingTagAndEndTimeWithFilePath:(NSString *)recorderFilePath
{
    // 删除recording Tag
    NSString *recordFileName = [recorderFilePath lastPathComponent];
    NSString *deleteRecordingTagFilePath = recorderFilePath;
    if ([recordFileName containsString:@"recording"])
    {
        NSString *recordingTag = [recordFileName substringWithRange:NSMakeRange(0, 10)];
        deleteRecordingTagFilePath = [recorderFilePath stringByReplacingOccurrencesOfString:recordingTag withString:@""];
    }
    
    // 删除结束录音时间
    NSArray *fileComponent = [recordFileName componentsSeparatedByString:@"_"];
    NSString *endRecordTime;
    if ([recordFileName containsString:@"recording"])
    {
        endRecordTime = fileComponent[4];
    }
    else
    {
        endRecordTime = fileComponent[3];
    }
    endRecordTime = [NSString stringWithFormat:@"_%@",endRecordTime];
    NSString *deleteEndTimeFilePath = [deleteRecordingTagFilePath stringByReplacingOccurrencesOfString:endRecordTime withString:@""];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager moveItemAtPath:recorderFilePath toPath:deleteEndTimeFilePath error:nil];
    
    return deleteEndTimeFilePath;
}

#pragma mark - 控制录音流程

- (void)beginRecordWithRecordName:(NSString *)recordName withRecordType:(NSString *)type withIsConventToMp3:(BOOL)isConventToMp3
{
    __weak __typeof(self) weakSelf = self;
    
    // 正在录制则直接返回
    if ([self carIsRecording])
    {
        return;
    }
    
    // 1. 检查授权状态
    [self checkMicrophoneAuthorization:^{
        
        // 初始化行程状态为未结束
        weakSelf.isEndTrip = NO;

        weakSelf.recordType = type;
        weakSelf.isConventMp3 = isConventToMp3;
        
        // 2. 录音的名字中已经包含录音的类型后缀则不再添加后缀
        if ([recordName containsString:[NSString stringWithFormat:@".%@",weakSelf.recordType]])
        {
            weakSelf.audioFileName = recordName;
        }
        else
        {
            weakSelf.audioFileName = [NSString stringWithFormat:@"%@.%@",recordName,weakSelf.recordType];
        }
        
        // 3. 创建录音文件存放路径
        if (![UCARAudioFilePathTool judgeFileOrFolderExists:cachesRecorderPath])
        {
            // 不存在则创建 /Library/Caches/Recorder 文件夹
            [UCARAudioFilePathTool createFolder:cachesRecorderPath];
        }
        // 给录制中的文件添加recording标识以区分录制完成的文件
        weakSelf.audioFileName = [NSString stringWithFormat:@"%@_%@",@"recording",weakSelf.audioFileName];
        weakSelf.recordPath = [cachesRecorderPath stringByAppendingPathComponent:weakSelf.audioFileName];
        
        // 4. 准备录音
        // prepareToRecord方法根据URL创建文件，并且执行底层Audio Queue初始化的必要过程，将录制启动时的延迟降到最低
        if ([self.audioRecorder prepareToRecord])
        {
            // 开始录音
            // 首次使用应用时如果调用record方法会询问用户是否允许使用麦克风
            [self.audioRecorder record];
            
            // 销毁之前的计时器
            // dispatch_cancel(self.timer);
            self.timer = nil;
            
            // 创建新的计时器时刻监测录制时长
            // 获取队列，这里获取全局队列（tips：可以单独创建一个队列跑定时器）
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
            // 创建定时器（dispatch_source_t本质还是个OC对象）
            self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
            // start参数控制计时器第一次触发的时刻，延迟0s
            dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, 0 * NSEC_PER_SEC);
            // 每隔0.33s执行一次
            uint64_t interval = (uint64_t)(0.33 * NSEC_PER_SEC);
            dispatch_source_set_timer(self.timer, start, interval, 0);
            dispatch_source_set_event_handler(self.timer, ^{
                [self autoEndRecordingWithTime];
            });
            // 开始执行定时器
            dispatch_resume(self.timer);

            
            // 判断是否需要边录边转 MP3
            if (isConventToMp3)
            {
                // 采样率
                [UCARLameTool shareUCARLameTool].sampleRate = self.sampleRate;
                
                [[UCARLameTool shareUCARLameTool] audioRecodingToMP3:weakSelf.recordPath isDeleteSourchFile:YES withSuccessBack:^(NSString * _Nonnull resultPath) {
                    NSLog(@"转 MP3 成功");
                    NSLog(@"转为MP3后的路径 = %@",resultPath);
                    
                    [self successConvertToMP3WithFilePath:resultPath];
                } withFailBack:^(NSString * _Nonnull error) {
                    NSLog(@"转 MP3 失败");
                    
                    // 删除给录制中的文件添加的.recording后缀变成录制完成的文件
                    NSString *failCafFilePath = weakSelf.recordPath;
                    if ([weakSelf.recordPath containsString:@"recording"])
                    {
                        failCafFilePath = [self deleteRecordingTagWithFilePath:weakSelf.recordPath];
                    }
                    
                    [self failConvertToMP3WithFilePath:failCafFilePath];
                }];
            }
        }
        else
        {
            NSLog(@"什么鬼");
        }
    } withNoPermission:^(BOOL error) {
        if (error)
        {
            NSLog(@"无法录音");
        }
        else
        {
            NSLog(@"没有录音权限，请前往 “设置” - “隐私” - “麦克风” 为APP开启权限");
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"麦克风未打开" message:@"录音功能需要录音权限，请到设置中开启" preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                NSLog(@"点击了取消");
            }];
            [alertController addAction:cancelAction];
            
            UIAlertAction *firstAction = [UIAlertAction actionWithTitle:@"去设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
            }];
            [alertController addAction:firstAction];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIApplication sharedApplication].delegate window].rootViewController presentViewController:alertController animated:YES completion:^{NSLog(@"点击了取消");}];
            });
        }
    }];
}

// 结束录音
- (void)endRecord
{
    // 销毁计时器
    if (self.timer)
    {
        dispatch_cancel(self.timer);
        self.timer = nil;
    }
    
    if (_audioRecorder)
    {
        // 停止录音
        [self.audioRecorder stop];

        // 销毁录音器
        self.audioRecorder = nil;
    }
}

// 是否正在录音
- (BOOL)carIsRecording
{
    if (_audioRecorder && _audioRecorder.isRecording)
    {
        return YES;
    }
    
    return NO;
}

#pragma mark - 3分钟循环录音

// 录音文件每3分钟保存一个文件，保存成功则录制下一段，时长可配置
- (void)autoEndRecordingWithTime
{
    // 刷新音量数据
    [self.audioRecorder updateMeters];
    
    // 当前录音时长
    NSLog(@"当前录音时长：%f",self.audioRecorder.currentTime);
    
    // 录音文件每3分钟保存一个文件，保存成功则录制下一段，时长可配置
    if (self.audioRecorder.currentTime >= self.timeInterval)
    {
        // 结束录音
        [self endRecord];
    }
}

// 重新录音
- (void)restartRecord
{
    // 开始录音，以caf作为录音原始文件后缀
    NSString *newRecorderName = [self createRecordFileNameWithOrderNumber:self.orderNumber driverID:self.driverID];
    
    // 重新开始录音
    [self beginRecordWithRecordName:newRecorderName withRecordType:@"caf" withIsConventToMp3:YES];
}

// 这里只是补全个检测音量变化的方法，并没有使用到，不用在意
// 获取录音时候的一些参数，监测声波变化
// 需要设置meteringEnabled参数为YES
// 启动一个计时器NSTimer，并在每次轮询的时候调用下面这个方法更新录音参数
-(void)audioPowerChange
{
    // 启动一个计时器NSTimer，并在每次轮询的时候更新录音参数
    [self.audioRecorder updateMeters];
    
    // peakPowerForChannel:方法返回峰值
    float peak0 = ([_audioRecorder peakPowerForChannel:0] + 160.0) * (1.0 / 160.0);
    float peak1 = ([_audioRecorder peakPowerForChannel:1] + 160.0) * (1.0 / 160.0);
    
    // averagePowerForChannel:返回平均值，两个值的范围都是-160~0
    float ave0 = ([_audioRecorder averagePowerForChannel:0] + 160.0) * (1.0 / 160.0);
    float ave1 = ([_audioRecorder averagePowerForChannel:1] + 160.0) * (1.0 / 160.0);
    
    NSLog(@"峰值0:%f，峰值1:%f，平均值0:%f，平均值1:%f",peak0,peak1,ave0,ave1);
    
    // 取得第一个通道的音频，注意音频强度范围时-160到0
    float power = [self.audioRecorder averagePowerForChannel:0];
    CGFloat progress = (1.0 / 160.0) * (power + 160.0);
    // 音频波动
    UIProgressView *audioPower = [[UIProgressView alloc] initWithFrame:CGRectMake(150, 100, 200, 100)];
    [audioPower setProgress:progress];
}

#pragma mark - 内存溢出覆盖最早的录音

// 计算录音文件总的大小
- (double)calculationRecordFileSizeSum
{
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES) firstObject];
    NSString *recordFilePath = [libraryPath stringByAppendingString:@"/Caches/Recorder/"];
    NSLog(@"录音文件路径为：%@",recordFilePath);
    
    NSFileManager *manager = [NSFileManager defaultManager];
    // 获得当前文件的所有子文件:subpathsAtPath:
    NSArray *pathList = [manager subpathsAtPath:recordFilePath];

    NSMutableArray *audioPathList = [NSMutableArray array];
    // 遍历这个文件夹下面的子文件，只获得录音文件
    for (NSString *audioPath in pathList)
    {
        if (![audioPath containsString:@"recording"])
        {
            // 成功生成的加密文件
            BOOL isUCAR = [audioPath.pathExtension isEqualToString:self.modifySuffix];
            // 未成功生成加密文件的剩余mp3文件
            BOOL isFailMp3 = [audioPath.pathExtension isEqualToString:@"mp3"];
            // 未成功生成mp3的剩余caf文件
            BOOL isFailCaf = [audioPath.pathExtension isEqualToString:@"caf"];
            
            // 通过对比文件的延展名（扩展名、尾缀）来区分是不是录音文件
            if (isUCAR || isFailMp3 || isFailCaf)
            {
                // 把筛选出来的文件放到数组中 -> 得到所有的音频文件
                [audioPathList addObject:audioPath];
            }
        }
    }
    self.audioPathList = audioPathList;
    NSLog(@"获得当前文件的所有子文件：%@",pathList);
    NSLog(@"所有的音频文件：%@",audioPathList);
    
    double allRecordFileSize = 0;
    for (NSString *audioPath in audioPathList)
    {
        // 每个录音文件的路径
        NSString *everyRecordFilePath = [recordFilePath stringByAppendingString:audioPath];
        // 每个录音文件的大小
        NSNumber *everyRecordFileSize = [manager attributesOfItemAtPath:everyRecordFilePath error:nil][NSFileSize];
        // 所有录音文件的大小
        allRecordFileSize += [everyRecordFileSize doubleValue];
    }
    allRecordFileSize = allRecordFileSize / 1024.0 / 1024.0;
    NSLog(@"所有的音频文件大小为：%fMB",allRecordFileSize);
    
    return allRecordFileSize;
}

// 内存溢出则覆盖最早的录音
- (void)coverEarliestRecordFileWithMemoryLimit:(double)maximumMemory
{
    NSLog(@"所有的音频文件限制大小为：%fMB",maximumMemory);
    
    // 所有的音频文件大小
    double allRecordFileSize = [self calculationRecordFileSizeSum];
    // 已经录制的所有的音频文件大小如果小于音频文件限制大小则表示还需要继续录制
    // 如果大于系统可用存储空间的最小值（暂定为100MB）则表示系统还允许继续录制
    // 未溢出则直接返回
    if (allRecordFileSize < maximumMemory && [self getFreeDiskSpace] > 100)
    {
        return;
    }
    
    // 按照录音文件的录制开始时间进行升序排序
    NSArray *orderedAudioPathList = [self.audioPathList sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        
        // 获取文件名 20201010-055153-20201012035704.UCAR
        NSString *fileName1 = obj1;
        NSString *fileName2 = obj2;
        
        // 获取开始时间 20201012035704
        NSArray *file1Component = [fileName1 componentsSeparatedByString:@"_"];
        NSString *number1 = file1Component[2];
        NSArray *file2Component = [fileName2 componentsSeparatedByString:@"_"];
        NSString *number2 = file2Component[2];
        
        // 比较integerValue
        if ([number1 integerValue] > [number2 integerValue])
        {
            return NSOrderedDescending;
        }
        else if ([number1 integerValue] < [number2 integerValue])
        {
            return NSOrderedAscending;
        }
        else
        {
            return NSOrderedSame;
        }
    }];
    NSLog(@"排序后的所有的音频文件：%@",orderedAudioPathList);
    
    // 覆盖最早的录音，其实就是删除最早的录音
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES) firstObject];
    NSString *recordFilePath = [libraryPath stringByAppendingString:@"/Caches/Recorder/"];
    NSString *earliestRecordFilePath = [recordFilePath stringByAppendingString:orderedAudioPathList[0]];
    
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:earliestRecordFilePath error:&error];
    if (error == nil)
    {
        NSLog(@"成功删除最早的录音文件");
    }
}

// 获取未使用的磁盘空间
- (double)getFreeDiskSpace
{
    NSError *error = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
    if (error) return -1;
    int64_t space =  [[attrs objectForKey:NSFileSystemFreeSize] longLongValue];
    if (space < 0) space = -1;
    
    NSString *freeDiskInfo = [NSString stringWithFormat:@" %.2f MB == %.2f GB", space/1024/1024.0, space/1024/1024/1024.0];
    NSLog(@"磁盘空闲空间为：%@",freeDiskInfo);
    
    double freeDisk = space/1024/1024.0;
    return freeDisk;
}

#pragma mark - 录音文件加密

// 生成的音频文件需要加密保存，司机端本地不可查看/检索/播放
- (NSString *)encryptedRecorderDataWithFilePath:(NSString *)recorderFilePath encryptKey:(NSString *)encryptKey modifySuffix:(NSString *)modifySuffix
{
    // 需要加密的音频文件数据
    NSData *recorderFileData = [NSData dataWithContentsOfFile:recorderFilePath];
    // 错误
    NSError *error = nil;
    // RNCryptor加密
    NSData *encryptedRecorderFileData;
    if (encryptKey.length > 0)
    {
        encryptedRecorderFileData = [RNEncryptor encryptData:recorderFileData withSettings:kRNCryptorAES256Settings password: encryptKey error:&error];
    }
    
    // 更改录音文件格式
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = recorderFilePath;
    NSString *modifySuffixRecorderFilePath;
    if (modifySuffix.length > 0)
    {
        modifySuffixRecorderFilePath = [path stringByReplacingOccurrencesOfString:@"mp3" withString:modifySuffix];
    }
    
    // 在原文件夹生成加密后的文件
    if (![fileManager createFileAtPath:modifySuffixRecorderFilePath contents:encryptedRecorderFileData attributes:nil])
    {
        // 这样写是因为createFileAtPath这个方法只返回了一个布尔值，并没有具体的错误信息，使用errno可以解决这个问题
        NSLog(@"加密错误码: %d - 加密错误信息: %s", errno, strerror(errno));
        
        // 删除给录制中的文件添加的.recording后缀变成录制完成的文件
        NSString *failMP3Path = recorderFilePath;
        if ([recorderFilePath containsString:@"recording"])
        {
            failMP3Path = [self deleteRecordingTagWithFilePath:recorderFilePath];
        }
         
        NSLog(@"加密失败的MP3的路径 = %@",failMP3Path);
        
        return nil;
    }
    else
    {
        NSLog(@"成功在原文件夹生成加密后的文件");
        
        // 删除未加密的mp3原始录音文件
        [fileManager removeItemAtPath:recorderFilePath error:&error];
        if (error == nil)
        {
            NSLog(@"成功删除未加密的mp3原始录音文件");
        }
        else
        {
            NSLog(@"删除源文件失败的错误信息为：%@",error);
            
            NSString *failDeleteMP3FilePath = recorderFilePath;
            if ([recorderFilePath containsString:@"recording"])
            {
                failDeleteMP3FilePath = [self deleteRecordingTagWithFilePath:recorderFilePath];
            }
            NSLog(@"抱歉，删除未加密的mp3原始录音文件失败，该文件转为完成状态，路径为：%@",failDeleteMP3FilePath);
        }
        
        // 删除给录制中的文件添加的.recording后缀变成录制完成的文件
        NSString *UCARFilePath = modifySuffixRecorderFilePath;
        if ([modifySuffixRecorderFilePath containsString:@"recording"])
        {
            UCARFilePath = [self deleteRecordingTagWithFilePath:modifySuffixRecorderFilePath];
        }
        
        // 返回生成的加密文件的路径
        return UCARFilePath;
    }
}

// 对目录下的所有UCAR音频文件进行解密，作测试用
- (void)decryptAllUCARRecorderFilesWithEncryptKey:(NSString *)encryptKey modifySuffix:(NSString *)modifySuffix
{
    // 防止encryptKey和modifySuffix为空，导致加密和解密失败
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *recorderPlistPath = [documentPath stringByAppendingPathComponent:@"Recorder.plist"];
    NSDictionary *dictionaryFromRecorderPlist = [NSDictionary dictionaryWithContentsOfFile:recorderPlistPath];
    NSLog(@"从录音Plist文件中读取到的字典为：%@",dictionaryFromRecorderPlist);
    if (encryptKey == nil || [encryptKey isEqualToString:@""])
    {
        encryptKey = dictionaryFromRecorderPlist[@"encryptKey"];
    }
    if (modifySuffix == nil || [modifySuffix isEqualToString:@""])
    {
        modifySuffix = dictionaryFromRecorderPlist[@"modifySuffix"];
    }
    
    // 读取加密数据
    NSArray *UCARAudioList = [[UCARAudioTool shareUCARAudioTool] getAllUCARRecorderFiles];
    if (UCARAudioList.count > 0)
    {
        for (NSString *UCARRecorderFilePath in UCARAudioList)
        {
            NSData *UCARRecorderFileData = [NSData dataWithContentsOfFile:UCARRecorderFilePath];
            
            // RNCryptor解密
            NSError *error = nil;
            NSData *decryptRecorderFileData = [RNDecryptor decryptData:UCARRecorderFileData withPassword:encryptKey error:&error];
            
            // 更改录音文件格式
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString *path = UCARRecorderFilePath;
            NSString *modifySuffixRecorderFilePath = [path stringByReplacingOccurrencesOfString:modifySuffix withString:@"mp3"];
            
            // 在原文件夹生成加密后的文件
            if (![fileManager createFileAtPath:modifySuffixRecorderFilePath contents:decryptRecorderFileData attributes:nil])
            {
                // 这样写是因为createFileAtPath这个方法只返回了一个布尔值，并没有具体的错误信息，使用errno可以解决这个问题
                NSLog(@"解密错误码: %d - 解密错误信息: %s", errno, strerror(errno));
            }
            else
            {
                NSLog(@"成功在原文件夹生成解密后的文件");
                [fileManager removeItemAtPath:UCARRecorderFilePath error:&error];
                if (error == nil)
                {
                    NSLog(@"成功删除加密的录音文件");
                }
            }
        }
    }
}

// 获得目录下的所有UCAR文件
- (NSArray *)getAllUCARRecorderFiles
{
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES) firstObject];
    NSString *recordFilePath = [libraryPath stringByAppendingString:@"/Caches/Recorder/"];
    NSLog(@"录音文件目录路径为：%@",recordFilePath);
    
    // 防止modifySuffix为空
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *recorderPlistPath = [documentPath stringByAppendingPathComponent:@"Recorder.plist"];
    NSDictionary *dictionaryFromRecorderPlist = [NSDictionary dictionaryWithContentsOfFile:recorderPlistPath];
    if (self.modifySuffix == nil || [self.modifySuffix isEqualToString:@""])
    {
        self.modifySuffix = dictionaryFromRecorderPlist[@"modifySuffix"];
    }
    
    NSFileManager *manager = [NSFileManager defaultManager];
    // 获得当前文件的所有子文件:subpathsAtPath:
    NSArray *pathList = [manager subpathsAtPath:recordFilePath];

    NSMutableArray *UCARAudioPathList = [NSMutableArray array];
    // 遍历这个文件夹下面的子文件，获得所有UCAR文件
    for (NSString *audioPath in pathList)
    {
        // UCAR文件
        if ([audioPath.pathExtension isEqualToString:self.modifySuffix])
        {
            [UCARAudioPathList addObject:audioPath];
        }
    }
    NSLog(@"所有UCAR文件：%@",UCARAudioPathList);
    
    // 存储UCAR文件的路径列表
    NSMutableArray *UCARAudioFilePathList = [NSMutableArray array];
    if (UCARAudioPathList.count > 0)
    {
        for (NSString *audioPath in UCARAudioPathList)
        {
            // 每个UCAR录音文件的路径
            NSString *UCARRecordFilePath = [recordFilePath stringByAppendingString:audioPath];
            [UCARAudioFilePathList addObject:UCARRecordFilePath];
        }
    }
    
    // 返回UCAR文件的路径列表
    return [UCARAudioFilePathList copy];
}

#pragma mark - AVAudioRecorderDelegate

// 录制完成或者调用stop时，回调用这个方法。但是如果是系统中断录音，则不会调用这个方法
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    
    if (flag)// 录音正常结束
    {
        NSLog(@"录音文件地址：%@",recorder.url.path) ;
        NSLog(@"录音文件大小：%@",[[NSFileManager defaultManager] attributesOfItemAtPath:recorder.url.path error:nil][NSFileSize]) ;
          
        // 判断是否需要转 MP3
        if (self.isConventMp3)
        {
            [[UCARLameTool shareUCARLameTool] sendEndRecord];
        }
    }
    else// 未正常结束
    {
        if ([recorder deleteRecording])// 录音文件删除成功
        {
            NSLog(@"录音文件删除成功");
        }
        else// 录音文件删除失败
        {
            NSLog(@"录音文件删除失败");
        }
    }
    
    // 音频文件在司机端本地最多占用1024M存储空间，空间满时自动覆盖生成时间最早的文件，空间上限可配置
    [self coverEarliestRecordFileWithMemoryLimit:self.maximumMemory];
    NSLog(@"录音结束");
}

// caf成功转化为mp3之后的操作
- (void)successConvertToMP3WithFilePath:(NSString *)resultPath
{
    // 生成的音频文件需要加密保存，司机端本地不可查看/检索/播放
    NSString *modifySuffixRecorderFilePath = [self encryptedRecorderDataWithFilePath:resultPath encryptKey:self.encryptKey modifySuffix:self.modifySuffix];
    
    // 生成加密文件失败则直接返回
    if (modifySuffixRecorderFilePath == nil || [modifySuffixRecorderFilePath isEqualToString:@""])
    {
        if (!self.isEndTrip)
        {
            [self restartRecord];
        }
        
        return;
    }
    
    // 上传文件的路径
    NSString *uploadFilePath;
    
    // 尚未结束行程时，保存成功则录制下一段
    if (!self.isEndTrip)
    {
        uploadFilePath = modifySuffixRecorderFilePath;
        [self restartRecord];
    }
    
    // 结束行程时未满3分钟需要给录音文件重新命名
    if (self.isEndTrip)
    {
        NSString *renameEndTripRecordingFilePath = [self renameEndTripRecordingFileWithFilePath:modifySuffixRecorderFilePath];
        NSLog(@"结束行程时未满3分钟需要给录音文件重新命名，修改后地址为：%@",renameEndTripRecordingFilePath);
        uploadFilePath = renameEndTripRecordingFilePath;
    }
    
    // 调用上传录音文件的方法
    if (self.delegate && [self.delegate respondsToSelector:@selector(uploadRecordingFileWithEncryptedRecorderFilePath:)])
    {
        [self.delegate uploadRecordingFileWithEncryptedRecorderFilePath:uploadFilePath];
    }
}

// caf转化为mp3失败之后的操作
- (void)failConvertToMP3WithFilePath:(NSString *)cafFilePath
{
    // 录音文件每3分钟保存一个文件，保存成功则录制下一段，时长可配置
    if (!self.isEndTrip)
    {
        [self restartRecord];
    }
    
    // 结束行程时未满3分钟需要给录音文件重新命名
    if (self.isEndTrip)
    {
        NSString *renameEndTripRecordingFilePath = [self renameEndTripRecordingFileWithFilePath:cafFilePath];
        NSLog(@"结束行程时未满3分钟需要给录音文件重新命名，修改后地址为：%@",renameEndTripRecordingFilePath);
    }
}

#pragma mark - 处理录制中断事件

// AVAudioSession通知：接收录制中断事件通知，并处理相关事件
// 监听诸如系统来电，闹钟响铃，Facetime……导致的音频录制终端事件
- (void)handleNotification:(NSNotification *)notification
{
    NSArray *allKeys = notification.userInfo.allKeys;
    // 判断事件类型
    if([allKeys containsObject:AVAudioSessionInterruptionTypeKey])
    {
        AVAudioSessionInterruptionType audioInterruptionType = [[notification.userInfo valueForKey:AVAudioSessionInterruptionTypeKey] integerValue];
        switch (audioInterruptionType)
        {
            case AVAudioSessionInterruptionTypeBegan:
                NSLog(@"录音被打断……开始");
                break;
            case AVAudioSessionInterruptionTypeEnded:
                NSLog(@"录音被打断……结束");
                break;
        }
    }
    
    // 判断中断的音频录制是否可恢复录制
    if([allKeys containsObject:AVAudioSessionInterruptionOptionKey])
    {
        AVAudioSessionInterruptionOptions shouldResume = [[notification.userInfo valueForKey:AVAudioSessionInterruptionOptionKey] integerValue];
        if(shouldResume)
        {
            NSLog(@"录音被打断…… 结束 可以恢复录音了");
        }
    }
}

// 移除通知
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// 因为录音中断，将recording标志删除掉，变成录音完成的文件
- (void)convertRecordingFileToFinishedFile
{
    NSLog(@"因为录音中断，将recording标志删除掉，变成录音完成的文件");
    
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES) firstObject];
    NSString *recordFilePath = [libraryPath stringByAppendingString:@"/Caches/Recorder/"];
    NSLog(@"录音文件目录路径为：%@",recordFilePath);
    
    NSFileManager *manager = [NSFileManager defaultManager];
    // 获得当前文件的所有子文件:subpathsAtPath:
    NSArray *pathList = [manager subpathsAtPath:recordFilePath];

    // 遍历这个文件夹下面的子文件，获得因中断等原因未自动转换成功的caf文件和mp3文件
    for (NSString *audioPath in pathList)
    {
        if ([audioPath containsString:@"recording"])
        {
            // 每个正在录音的文件的路径
            NSString *recordingFilePath = [recordFilePath stringByAppendingString:audioPath];
            
            // 因为录音中断，将recording标志删除掉，变成录音完成的文件
            // 同时删除结束录音时间
            [self deleteRecordingTagAndEndTimeWithFilePath:recordingFilePath];
        }
    }
}

// 用于将因中断等原因未自动转换成功的caf文件和mp3文件加密转化为UCAR文件
- (NSArray *)convertAudioToUCARWithEncryptKey:(NSString *)encryptKey modifySuffix:(NSString *)modifySuffix sampleRate:(int)sampleRate
{
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES) firstObject];
    NSString *recordFilePath = [libraryPath stringByAppendingString:@"/Caches/Recorder/"];
    NSLog(@"录音文件目录路径为：%@",recordFilePath);
    
    // 防止encryptKey和modifySuffix为空，导致加密和解密失败
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *recorderPlistPath = [documentPath stringByAppendingPathComponent:@"Recorder.plist"];
    NSDictionary *dictionaryFromRecorderPlist = [NSDictionary dictionaryWithContentsOfFile:recorderPlistPath];
    NSLog(@"从录音Plist文件中读取到的字典为：%@",dictionaryFromRecorderPlist);
    if (encryptKey == nil || [encryptKey isEqualToString:@""])
    {
        encryptKey = dictionaryFromRecorderPlist[@"encryptKey"];
    }
    if (modifySuffix == nil || [modifySuffix isEqualToString:@""])
    {
        modifySuffix = dictionaryFromRecorderPlist[@"modifySuffix"];
    }
    if (sampleRate == 0)
    {
        sampleRate = [dictionaryFromRecorderPlist[@"sampleRate"] intValue];
    }
    
    NSFileManager *manager = [NSFileManager defaultManager];
    // 获得当前文件的所有子文件:subpathsAtPath:
    NSArray *pathList = [manager subpathsAtPath:recordFilePath];

    NSMutableArray *cafAudioPathList = [NSMutableArray array];
    NSMutableArray *mp3AudioPathList = [NSMutableArray array];
    // 遍历这个文件夹下面的子文件，获得因中断等原因未自动转换成功的caf文件和mp3文件
    for (NSString *audioPath in pathList)
    {
        if (![audioPath containsString:@"recording"])
        {
            // 未成功生成加密文件的剩余mp3文件
            if ([audioPath.pathExtension isEqualToString:@"mp3"])
            {
                [mp3AudioPathList addObject:audioPath];
            }
        }
    }
    for (NSString *audioPath in pathList)
    {
        if (![audioPath containsString:@"recording"])
        {
            // 未成功生成mp3的剩余caf文件
            if ([audioPath.pathExtension isEqualToString:@"caf"])
            {
                NSString *cafAudioName = [audioPath stringByDeletingPathExtension];
                
                for (NSString *mp3AudioPath in mp3AudioPathList)
                {
                    NSString *mp3AudioName = [mp3AudioPath stringByDeletingPathExtension];
                    if ([cafAudioName isEqualToString:mp3AudioName])// 相等说明是同一个录音文件则直接删除即可
                    {
                        // 每个caf录音文件的路径
                        NSString *cafRecordFilePath = [recordFilePath stringByAppendingString:audioPath];
                        [self deleteRecordFileWithFilePath:cafRecordFilePath];
                    }
                    else// 否则加入caf待转录列表
                    {
                        [cafAudioPathList addObject:audioPath];
                    }
                }
            }
        }
    }
    NSLog(@"未成功生成mp3的剩余caf文件：%@",cafAudioPathList);
    NSLog(@"未成功生成加密文件的剩余mp3文件：%@",mp3AudioPathList);
    
    // 存储转化而成的UCAR文件的数据用于上传
    NSMutableArray *UCARAudioPathList = [NSMutableArray array];
    // 将剩余caf文件转化为UCAR
    if (cafAudioPathList.count > 0)
    {
        for (NSString *audioPath in cafAudioPathList)
        {
            // 每个caf录音文件的路径
            NSString *cafRecordFilePath = [recordFilePath stringByAppendingString:audioPath];
            
            // 采样率
            [UCARLameTool shareUCARLameTool].sampleRate = sampleRate;
            
            // 转为MP3
            [[UCARLameTool shareUCARLameTool] audioToMP3:cafRecordFilePath isDeleteSourchFile:YES withSuccessBack:^(NSString * _Nonnull resultPath) {
                NSLog(@"转为MP3后的路径 = %@",resultPath);
                
                // 将mp3文件进行加密
                NSString *encryptedRecorderDataWithFilePath = [self encryptedRecorderDataWithFilePath:resultPath encryptKey:encryptKey modifySuffix:modifySuffix];
                if (encryptedRecorderDataWithFilePath && ![encryptedRecorderDataWithFilePath isEqualToString:@""])
                {
                    [UCARAudioPathList addObject:encryptedRecorderDataWithFilePath];
                }
                
            } withFailBack:^(NSString * _Nonnull error) {
                
                NSLog(@"将caf文件转换为mp3文件失败：%@",error);
            }];
        }
    }

    // 将剩余mp3文件转化为UCAR
    if (mp3AudioPathList.count > 0)
    {
        for (NSString *audioPath in mp3AudioPathList)
        {
            // 每个mp3录音文件的路径
            NSString *mp3RecordFilePath = [recordFilePath stringByAppendingString:audioPath];
            // 将mp3文件进行加密
            NSString *encryptedRecorderDataWithFilePath = [self encryptedRecorderDataWithFilePath:mp3RecordFilePath encryptKey:encryptKey modifySuffix:modifySuffix];
            if (encryptedRecorderDataWithFilePath && ![encryptedRecorderDataWithFilePath isEqualToString:@""])
            {
                [UCARAudioPathList addObject:encryptedRecorderDataWithFilePath];
            }
        }
    }
    
    // 返回转化而成的UCAR文件的路径列表用于上传
    return [UCARAudioPathList copy];
}

// 删除录音文件
- (void)deleteRecordFileWithFilePath:(NSString *)recordFile
{
    NSError *error;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:recordFile error:&error];
    if (error == nil)
    {
        NSLog(@"成功删除录音文件");
    }
}

#pragma mark - 创建录音器

- (AVAudioRecorder *)audioRecorder
{
    __weak typeof(self) weakSelf = self;
    
    if (!_audioRecorder)
    {
//0. 设置录音会话
        // 音频会话是应用程序和操作系统之间的中间人。应用程序不需要具体知道怎样和音频硬件交互的细节，只需要把所需的音频行为委托给音频会话管理即可。
        /* Category
         * AVAudioSessionCategoryPlayAndRecord :录制和播放。打断不支持混音播放的APP，不会响应手机静音键开关
         * AVAudioSessionCategoryAmbient       :用于非以语音为主的应用，随着静音键和屏幕关闭而静音
         * AVAudioSessionCategorySoloAmbient   :类似AVAudioSessionCategoryAmbient不同之处在于它会中止其它应用播放声音
         * AVAudioSessionCategoryPlayback      :用于以语音为主的应用，不会随着静音键和屏幕关闭而静音，可在后台播放声音
         * AVAudioSessionCategoryRecord        :用于需要录音的应用，除了来电铃声，闹钟或日历提醒之外的其它系统声音都不会被播放，只提供单纯录音功能
         */
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
        // 启动会话
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        
        // 注册音频录制中断通知
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(handleNotification:) name:AVAudioSessionInterruptionNotification object:nil];
        
//1. 确定录音存放的位置
        NSURL *url = [NSURL URLWithString:weakSelf.recordPath];
//2. 设置录音参数
        NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];

        /**设置编码格式AVFormatIDKey
         * kAudioFormatLinearPCM: 无损压缩，内容非常大
         * kAudioFormatMPEG4AAC
         */
        [recordSettings setValue:[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey:AVFormatIDKey];

        // 设置采样率AVSampleRateKey：必须保证和转码设置的相同
        // 采样率越高，文件越大，质量越好，反之，文件小，质量相对差一些，但是低于普通的音频，人耳并不能明显的分辨出好坏
        // 建议使用标准的采样率，8000、16000、22050、44100(11025.0)
        [recordSettings setValue:[NSNumber numberWithInt:self.sampleRate] forKey:AVSampleRateKey];

        // 设置通道数AVNumberOfChannelsKey，用于指定记录音频的通道数。
        // 1为单声道，2为立体声。这里必须设置为双声道，不然转码生成的 MP3 会声音尖锐变声
        [recordSettings setValue:[NSNumber numberWithInt:2] forKey:AVNumberOfChannelsKey];

        // 设置音频质量AVEncoderAudioQualityKey，音频质量越高，文件的大小也就越大
        [recordSettings setValue:[NSNumber numberWithInt:AVAudioQualityMin] forKey:AVEncoderAudioQualityKey];

        // 音频的编码比特率 BPS传输速率 一般为128kbps
        // [recordSettings setValue:[NSNumber numberWithInt:128000] forKey:AVEncoderBitRateKey];
        
//3. 创建录音对象
        NSError *error;
        _audioRecorder = [[AVAudioRecorder alloc] initWithURL:url settings:recordSettings error:&error];
        
        // 开启音量监测
        _audioRecorder.meteringEnabled = YES;
        // 设置录音完成委托回调
        _audioRecorder.delegate = self;
        
        if(error)
        {
            NSLog(@"创建录音对象时发生错误，错误信息：%@",error.localizedDescription);
        }
    }
    return _audioRecorder;
}

- (NSString *)recordCachePath
{
    NSString *libraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask,YES) firstObject];
    NSString *recordCachePath = [libraryPath stringByAppendingString:@"/Caches/Recorder/"];
    NSLog(@"录音文件目录路径为：%@",recordCachePath);
    
    return recordCachePath;
}

@end



