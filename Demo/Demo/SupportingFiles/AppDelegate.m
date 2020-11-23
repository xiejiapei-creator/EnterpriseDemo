//
//  AppDelegate.m
//  Demo
//
//  Created by 谢佳培 on 2020/10/25.
//

#import "AppDelegate.h"
#import "UCARRecordSoundTool.h"
#import "RecordSoundViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
    RecordSoundViewController *rootVC = [[RecordSoundViewController alloc] init];
    UINavigationController *mainNC = [[UINavigationController alloc] initWithRootViewController:rootVC];
    
    [[UCARRecordSoundTool shareUCARRecordSoundTool] decryptAllUCARRecorderFilesWithEncryptKey:@"" modifySuffix:@""];
    
    [[UCARRecordSoundTool shareUCARRecordSoundTool] convertRecordingFileToFinishedFile];
    [[UCARRecordSoundTool shareUCARRecordSoundTool] convertAudioToUCARWithEncryptKey:@"" modifySuffix:@"" sampleRate:0];
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = mainNC;
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end
