//
//  UCARDirverUploadFileTool.m
//  Demo
//
//  Created by 谢佳培 on 2020/11/23.
//

#import "UCARDirverUploadFileTool.h"
#import "UCARWeakProxy.h"

#define WeakSelf(weakSelf) __weak __typeof(self) weakSelf = self
#define StrongSelf(strongSelf) __strong typeof(weakSelf) strongSelf = weakSelf

@implementation UCARAudioRecordConfig

@end

@interface UCARDirverUploadFileTool ()<UCARRecordSoundToolDelegate>

@property (strong, nonatomic) UCARAudioRecordConfig *config;// 接口传入的可以配置的参数数据
@property (assign, nonatomic) BOOL isUploading;// 是否正在上传录音文件
@property (nonatomic, strong) NSTimer *timer; // 循环检测上传计时器
@property (nonatomic, strong) NSTimer *delayTimer; // 延时结束订单计时器
@property (nonatomic, strong) NSMutableArray *pathArr; // 录音文件夹所有加密后待上传的UCAR文件

@end

@implementation UCARDirverUploadFileTool

// 工具类单例 
SingleM(UCARDirverUploadFileTool)

#pragma mark - 开始录音

// 根据配置参数开启录音
- (void)startRecordWithOrderNumber:(NSString *)orderNumber driverID:(NSString *)driverID
{
    // 正在录音
    if ([[UCARRecordSoundTool shareUCARRecordSoundTool] carIsRecording])
    {
        // 正在录制的订单号
        NSString *exitNumber = [UCARRecordSoundTool shareUCARRecordSoundTool].recordingOrderNumber;
        // 该订单号正在录制中
        if ([exitNumber isEqualToString:orderNumber])
        {
            NSLog(@"该订单号正在录制中 %@，不做处理", orderNumber);
            return;
        }
    }
    // 停止录音
    [self stopRecordAudio];
    
    // 开启新录音
    // 因 stopRecordAudio 方法会调用系统代理，时间不确定, 暂时延后 0.5s 执行
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"开启录音 %@", orderNumber);
        
        // 将后端提供的可配置参数与本地的参数关联起来
        [self configureRecordParams];
        [[UCARRecordSoundTool shareUCARRecordSoundTool] startRecordWithOrderNumber:orderNumber driverID:driverID];
    });
}

// 将后端提供的可配置参数与本地的参数关联起来
- (void)configureRecordParams
{
    // 每段录音时间(s)
    if (self.config.duration)
    {
        [UCARRecordSoundTool shareUCARRecordSoundTool].timeInterval = self.config.duration;
    }
    
    // 司机端存储空间(M)
    if (self.config.maxFileSize)
    {
        [UCARRecordSoundTool shareUCARRecordSoundTool].maximumMemory = self.config.maxFileSize;
    }
    
    // 录音文件码率(kbps)
    if (self.config.encodingBitRate)
    {
        [UCARRecordSoundTool shareUCARRecordSoundTool].bitRate = self.config.encodingBitRate;
    }
    
    // 采样率，单位Hz
    if (self.config.samplingRate)
    {
        [UCARRecordSoundTool shareUCARRecordSoundTool].sampleRate = self.config.samplingRate;
    }
    
    // 录音文件格式
    if (self.config.extName.length > 0)
    {
        [UCARRecordSoundTool shareUCARRecordSoundTool].originalSuffix = self.config.extName;
    }
    
    [UCARRecordSoundTool shareUCARRecordSoundTool].delegate = self;
}

#pragma mark - 结束录音

// 延迟结束录音
- (void)endTripRecordAfterDelay
{
    // 配置结束录音延迟时间(s)，默认为5分钟
    NSTimeInterval delay = 300;
    
    if (self.config.laterStopTime > 0)
    {
        delay = self.config.laterStopTime;
    }
    
    // 开启延时计时器
    if (!self.delayTimer || !self.delayTimer.isValid)
    {
        NSLog(@"开启延时计时器，倒计时%f秒", delay);
        
        // 用来存放弱对象的代理。它可以用来避免NSTimer或CADisplayLink导致的引用循环
        UCARWeakProxy *weakProxy = [UCARWeakProxy proxyWithTarget:self];
        self.delayTimer = [NSTimer scheduledTimerWithTimeInterval:delay target:weakProxy selector:@selector(stopRecordAudio) userInfo:nil repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:self.delayTimer forMode:NSRunLoopCommonModes];
    }
}

// 立即停止录音，并销毁延时计时器
- (void)stopRecordAudio
{
    NSLog(@"立即停止录音，并销毁延时计时器");
    
    // 结束行程录音
    [[UCARRecordSoundTool shareUCARRecordSoundTool] endTrip];
    // 清空正在录制中的订单号
    [UCARRecordSoundTool shareUCARRecordSoundTool].recordingOrderNumber = @"";
    
    // 销毁延时结束订单计时器
    if (self.delayTimer)
    {
        [self.delayTimer invalidate];
        self.delayTimer = nil;
    }
}

#pragma mark - 上传录音文件

// 启动定时上传录音
- (void)uploadTaskWithFireTime
{
    // 司机端定时检测间隔(s)，默认5分钟检测一次
    NSTimeInterval time = 300;
    if (self.config.scanInterval)
    {
        time = self.config.scanInterval;
    }
    
    // 启动定时上传
    [self startUploadTask];
    if (!self.timer)
    {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:time repeats:YES block:^(NSTimer * _Nonnull timer) {
            [self startUploadTask];
        }];
        [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    }
}

// 停止定时上传录音
- (void)stopUploadTask
{
    [self.timer invalidate];
    self.timer = nil;
}

// 开启上传录音任务
- (void)startUploadTask
{
    // 正在上传则直接返回
    if (self.isUploading)
    {
        return;
    }
    NSLog(@"检测录音文件");
    
    // 转换所有文件为待上传状态
    [[UCARRecordSoundTool shareUCARRecordSoundTool] convertAudioToUCARWithEncryptKey:@"U2FsdGVkX1+21W0Epk68cW2rlAt/TuHcDO4A+UYtbjI=" modifySuffix:@"UCAR" sampleRate:11025];
    
    // 获取待上传的文件
    [self.pathArr removeAllObjects];
    NSMutableArray *pathArr = [[UCARRecordSoundTool shareUCARRecordSoundTool] getAllUCARRecorderFiles].mutableCopy;
    if (pathArr.count == 0)
    {
        NSLog(@"没有找到待上传的录音文件");
        return;
    }
    [self.pathArr addObjectsFromArray:pathArr];
    
    NSLog(@"找到待上传的录音文件, 准备上传");
    WeakSelf(weakSelf);
    [self startUploadItemsCompletion:^(NSMutableArray *successResultPath) {
        NSLog(@"本次批量上传成功%lu个录音", (unsigned long)successResultPath.count);
        StrongSelf(strongSelf);
        strongSelf.isUploading = NO;
    }];
}

// 批量上传录音文件
- (void)startUploadItemsCompletion:(void(^)(NSMutableArray *successResultPath))completion
{
    // 待上传的文件数为0则直接返回
    if (self.pathArr.count < 1)
    {
        return;
    }

    // 准备保存上传成功的录音文件名称的数组，用于知道哪些文件上传成功了
    // 元素个数与上传的图片个数相同，先用 NSNull 占位
    NSMutableArray* result = [NSMutableArray array];
    for (NSInteger i = 0; i<self.pathArr.count; i++)
    {
        [result addObject:[NSNull null]];
    }
    
    // 批量逐个上传
    dispatch_group_t group = dispatch_group_create();
    for (int i = 0; i<self.pathArr.count; i++)
    {
        dispatch_group_enter(group);
        
        // 待上传的录音文件的数据和名称
        NSData *UCARRecorderFileData = [NSData dataWithContentsOfFile:self.pathArr[i]];
        NSString *name = [self.pathArr[i] lastPathComponent];
        
        WeakSelf(weakSelf);
        self.isUploading = YES;// 设置上传状态为正在上传
        [self startUploadItem:UCARRecorderFileData name:name completion:^(BOOL success) {
            StrongSelf(strongSelf);
            
            // 上传成功
            if (success)
            {
                // 加入上传成功的文件名称
                @synchronized (result) {
                    // NSMutableArray 不是线程安全的，所以加个同步锁
                    result[i] = name;
                }
                
                // 删除已上传文件
                if (strongSelf.pathArr.count > 0)
                {
                    NSString *filePath = strongSelf.pathArr[i];
                    [[UCARRecordSoundTool shareUCARRecordSoundTool] deleteRecordFileWithFilePath:filePath];
                    
                    dispatch_group_leave(group);
                }
            }
            else
            {
                dispatch_group_leave(group);
            }
        }];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (completion)
        {
            completion(result);
        }
    });
}

// 上传单个录音文件
- (void)startUploadItem:(id)item name:(NSString *)name completion:(void(^)(BOOL success))completion
{
    NSLog(@"录音文件开始上传");
    
    /*
    UCARHttpRequestConfig *config = [UCARHttpRequestConfig defaultConfig];
    config.subURL = UCAR_HTTP_RECORD_UPLOADFILE;
    config.postDataFormatBlock = ^(id<AFMultipartFormData> formData) {
        [formData appendPartWithFileData:item name:@"record" fileName:name mimeType:@"UCAR"];
    };
    
    [[UCARHttpManager sharedManager] asyncPostWithConfig:config success:^(id  _Nonnull response, NSDictionary * _Nullable request) {
        NSLog(@"[recordUpload]上传成功的文件名:%@", name);
        if (completion) {
            completion(YES);
        }
        
    } failure:^(id  _Nullable response, NSDictionary * _Nullable request, NSError * _Nonnull error) {
        NSLog(@"[recordUpload]上传失败的文件名:%@", name);
        if (completion) {
            completion(NO);
        }
    }];
     */
}

#pragma mark - UCARRecordSoundToolDelegate

// 上传录音文件的委托方法
// 用于录制完时间间隔为3分钟的音频文件后自动上传的方法
- (void)uploadRecordingFileWithEncryptedRecorderFilePath:(NSString *)uploadFilePath
{
    // 没有在上传则进行上传录音文件流程
    if (![UCARDirverUploadFileTool shareUCARDirverUploadFileTool].isUploading)
    {
        // 可以使用uploadFilePath参数上传当前录制完成的加密文件，也可以使用startUploadTask上传所有的加密文件
        [[UCARDirverUploadFileTool shareUCARDirverUploadFileTool] startUploadTask];
    }
}

#pragma mark - Getter

- (NSMutableArray *)pathArr
{
    if (!_pathArr)
    {
        _pathArr = @[].mutableCopy;
    }
    return _pathArr;
}

- (UCARAudioRecordConfig *)config
{
    if (!_config)
    {
        _config = [[UCARAudioRecordConfig alloc] init];
    }
    return _config;
}

@end
