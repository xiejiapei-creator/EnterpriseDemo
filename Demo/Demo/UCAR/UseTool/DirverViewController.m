//
//  DirverViewController.m
//  Demo
//
//  Created by 谢佳培 on 2020/11/23.
//

#import "DirverViewController.h"
#import "UCARDirverUploadFileTool.h"
#import <AFNetworking.h>

@interface DirverViewController ()

@end

@implementation DirverViewController

#pragma mark - 开始和结束录音

// 开始录音
- (void)startRecordAudio
{
    BOOL openRecord = YES;
    NSString *orderNo = @"35200505324217";
    NSString *driverId = @"2890893";
    
    // 若允许录音
    if (openRecord)
    {
        // 开启录音
        [[UCARDirverUploadFileTool shareUCARDirverUploadFileTool] startRecordWithOrderNumber:orderNo driverID:driverId];
    }
}

// 更新服务状态
- (void)updateServiceStatusRequestWithServiceStatus:(UCARDispatchServiceStatus)status
{
    // 结束服务状态
    if (status == UCARDispatchServiceStatusEndService)
    {
        // 延迟结束录音
        [[UCARDirverUploadFileTool shareUCARDirverUploadFileTool] endTripRecordAfterDelay];
    }
}

// 退出登录请求
- (void)driverLogoutRequest
{
    // 结束录音
    [[UCARDirverUploadFileTool shareUCARDirverUploadFileTool] stopRecordAudio];
}

#pragma mark - 上传录音文件

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 监听网络连接状态
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(netWorkStatusChanged:) name:AFNetworkingReachabilityDidChangeNotification object:nil];
    
    // 定时检测录音文件并上传
    [[UCARDirverUploadFileTool shareUCARDirverUploadFileTool] uploadTaskWithFireTime];
}

- (void)netWorkStatusChanged:(NSNotification *)notice
{
    // 获取网络状态
    NSDictionary *dic = notice.userInfo;
    NSInteger status = [[dic objectForKey:AFNetworkingReachabilityNotificationStatusItem] integerValue];
    
    // 无网络则停止检测录音文件和上传
    if(status == AFNetworkReachabilityStatusNotReachable)
    {
        [[UCARDirverUploadFileTool shareUCARDirverUploadFileTool] stopUploadTask];
        return;
    }
    else
    {
        // 定时检测录音文件并上传
        [[UCARDirverUploadFileTool shareUCARDirverUploadFileTool] uploadTaskWithFireTime];
    }
}

@end
