//
//  UCARAudioFilePathTool.h
//  UCarDriver
//
//  Created by 谢佳培 on 2020/10/16.
//  Copyright © 2020 szzc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UCARAudioFilePathTool : NSObject

/** 判断文件或文件夹是否存在 */
+(BOOL)judgeFileOrFolderExists:(NSString *)filePathName;

/** 判断文件是否存在 */
+(BOOL)judgeFileExists:(NSString *)filePath;

/** 创建文件夹目录 */
+(NSString *)createFolder:(NSString *)folderName;

@end

NS_ASSUME_NONNULL_END
