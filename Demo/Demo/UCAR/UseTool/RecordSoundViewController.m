//
//  RecordSoundViewController.m
//  DriverAppRecordingDemo
//
//  Created by 谢佳培 on 2020/9/27.
//

#import "RecordSoundViewController.h"
#import "UCARRecordSoundTool.h"

@interface RecordSoundViewController ()<UCARRecordSoundToolDelegate>

@end

@implementation RecordSoundViewController

#pragma mark - Life Circle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self createSubViews];
}

- (void)createSubViews
{
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIButton *startRecordButtton = [[UIButton alloc]initWithFrame:CGRectMake(40, 400, 100, 40)];
    startRecordButtton.layer.cornerRadius = 5;
    startRecordButtton.layer.masksToBounds = YES;
    startRecordButtton.backgroundColor = [UIColor lightGrayColor];
    [startRecordButtton setTitle:@"开始录音" forState:UIControlStateNormal];
    [startRecordButtton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    startRecordButtton.titleLabel.font = [UIFont systemFontOfSize:14.f];
    [startRecordButtton addTarget:self action:@selector(startRecordClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:startRecordButtton];
    
    UIButton *endRecordButtton = [[UIButton alloc]initWithFrame:CGRectMake(CGRectGetMaxX(startRecordButtton.frame)+100, 400, 100, 40)];
    endRecordButtton.layer.cornerRadius = 5;
    endRecordButtton.layer.masksToBounds = YES;
    endRecordButtton.backgroundColor = [UIColor lightGrayColor];
    [endRecordButtton setTitle:@"结束行程" forState:UIControlStateNormal];
    [endRecordButtton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    endRecordButtton.titleLabel.font = [UIFont systemFontOfSize:14.f];
    [endRecordButtton addTarget:self action:@selector(endTripClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:endRecordButtton];
    
    UIButton *restartTripButtton = [[UIButton alloc]initWithFrame:CGRectMake(CGRectGetMaxX(startRecordButtton.frame)-50, 500, 200, 40)];
    restartTripButtton.layer.cornerRadius = 5;
    restartTripButtton.layer.masksToBounds = YES;
    restartTripButtton.backgroundColor = [UIColor lightGrayColor];
    [restartTripButtton setTitle:@"结束行程后立即开启新订单" forState:UIControlStateNormal];
    [restartTripButtton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    restartTripButtton.titleLabel.font = [UIFont systemFontOfSize:14.f];
    [restartTripButtton addTarget:self action:@selector(restartTripClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:restartTripButtton];
}

// 司机到达乘车点，开始录音
- (void)startRecordClick
{
    [UCARRecordSoundTool shareUCARRecordSoundTool].timeInterval = 180;
    //[UCARRecordSoundTool shareUCARRecordSoundTool].maximumMemory = 0.1;
    [UCARRecordSoundTool shareUCARRecordSoundTool].delegate = self;
    [[UCARRecordSoundTool shareUCARRecordSoundTool] startRecordWithOrderNumber:@"35200505324217" driverID:@"2890893"];
}

// 结束行程，停止录音
- (void)endTripClick
{
    [[UCARRecordSoundTool shareUCARRecordSoundTool] endTrip];
    //[[UCARRecordSoundTool shareUCARRecordSoundTool] decryptAllUCARRecorderFilesWithEncryptKey:@"" modifySuffix:@""];
}

// 结束行程后立即开启新订单
- (void)restartTripClick
{
    [[UCARRecordSoundTool shareUCARRecordSoundTool] endTrip];
    
    // 延时执行，否则会导致startRecord方法在endTrip方法的委托还没执行完成之前就调用了，调用顺序出错
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UCARRecordSoundTool shareUCARRecordSoundTool].timeInterval = 10;
        [[UCARRecordSoundTool shareUCARRecordSoundTool] startRecordWithOrderNumber:@"35207737643077" driverID:@"65732"];
    });
}

// 上传录音文件的委托方法
- (void)uploadRecordingFileWithEncryptedRecorderFilePath:(NSString *)uploadFilePath
{
    NSLog(@"需要即时上传的文件路径为：%@",uploadFilePath);
    
    // 读取加密文件数据进行上传
    NSData *encryptedRecorderFileData = [NSData dataWithContentsOfFile:uploadFilePath];
    if (encryptedRecorderFileData)
    {
        NSLog(@"在这里进行3分钟文件的自动上传");
    }
}




@end
