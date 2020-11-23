//
//  DirverViewController.h
//  Demo
//
//  Created by 谢佳培 on 2020/11/23.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, UCARDispatchServiceStatus)
{
    UCARDispatchServiceStatusOrderSuccess = 4,
    UCARDispatchServiceStatusPickUpPassenger = 18,
    UCARDispatchServiceStatusWaitingService = 5,
    UCARDispatchServiceStatusInService = 6,
    UCARDispatchServiceStatusEndService = 15,
    UCARDispatchServiceStatusCancel = 8
};

@interface DirverViewController : UIViewController

@end

NS_ASSUME_NONNULL_END
