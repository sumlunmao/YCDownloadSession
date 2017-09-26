//
//  YCDownloadManager.m
//  YCDownloadSession
//
//  Created by wz on 17/3/24.
//  Copyright © 2017年 onezen.cc. All rights reserved.
//  Github: https://github.com/onezens/YCDownloadSession
//

#import "YCDownloadManager.h"
#import "YCDownloadSession.h"

#define kCommonUtilsGigabyte (1024 * 1024 * 1024)
#define kCommonUtilsMegabyte (1024 * 1024)
#define kCommonUtilsKilobyte 1024

@interface YCDownloadManager ()

@property (nonatomic, strong) NSMutableDictionary *itemsDictM;
/**本地通知开关，默认关,一般用于测试。可以根据通知名称，自定义*/
@property (nonatomic, assign) BOOL localPushOn;

@end

@implementation YCDownloadManager

static id _instance;

#pragma mark - init

+ (instancetype)manager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (instancetype)init {
    if (self = [super init]) {
        [self getDownloadItems];
        if(!self.itemsDictM) self.itemsDictM = [NSMutableDictionary dictionary];
        [self addNotification];
    }
    return self;
}

- (void)saveDownloadItems {
    [NSKeyedArchiver archiveRootObject:self.itemsDictM toFile:[self downloadItemSavePath]];
}

- (void)getDownloadItems {
    NSMutableDictionary *items = [NSKeyedUnarchiver unarchiveObjectWithFile:[self downloadItemSavePath]];;
    
    //app闪退或者手动杀死app，会继续下载。APP再次启动默认暂停所有下载
    [items enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        YCDownloadItem *item = obj;
        //app重新启动，将等待和下载的任务的状态变成暂停
        if (item.downloadStatus == YCDownloadStatusDownloading || item.downloadStatus == YCDownloadStatusWaiting) {
            item.downloadStatus = YCDownloadStatusPaused;
        }
    }];
    
    self.itemsDictM = items;
    
}

- (NSString *)downloadItemSavePath {
    NSString *saveDir = [YCDownloadTask saveDir];
    return [saveDir stringByAppendingPathComponent:@"items.data"];
}

- (void)addNotification {
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveDownloadItems) name:kYCDownloadSessionSaveDownloadStatus object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadAllTaskFinished) name:kDownloadAllTaskFinishedNoti object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(downloadTaskFinishedNoti:) name:kDownloadTaskFinishedNoti object:nil];
}


#pragma mark - public


+ (void)setMaxTaskCount:(NSInteger)count {
    [[YCDownloadManager manager] setMaxTaskCount: count];
}

/**
 开始一个后台下载任务
 
 @param downloadURLString 下载url

 */
+ (void)startDownloadWithUrl:(NSString *)downloadURLString fileName:(NSString *)fileName thumbImageUrl:(NSString *)imagUrl{
    [[YCDownloadManager manager] startDownloadWithUrl:downloadURLString fileName:fileName thumbImageUrl:imagUrl];
}

/**
 暂停一个后台下载任务
 
 @param downloadURLString 下载url
 */
+ (void)pauseDownloadWithUrl:(NSString *)downloadURLString {
    [[YCDownloadManager manager] pauseDownloadWithUrl:downloadURLString];
}

/**
 继续开始一个后台下载任务
 
 @param downloadURLString 下载url
 */
+ (void)resumeDownloadWithUrl:(NSString *)downloadURLString {
    [[YCDownloadManager manager] resumeDownloadWithUrl:downloadURLString];
}

/**
 删除一个后台下载任务，同时会删除当前任务下载的缓存数据
 
 @param downloadURLString 下载url
 */
+ (void)stopDownloadWithUrl:(NSString *)downloadURLString {
    [[YCDownloadManager manager] stopDownloadWithUrl:downloadURLString];
}

/**
 暂停所有的下载
 */
+ (void)pauseAllDownloadTask {
    [[YCDownloadManager manager] pauseAllDownloadTask];
}

+ (NSArray *)downloadList {
    return [[YCDownloadManager manager] downloadList];
}
+ (NSArray *)finishList {
    return [[YCDownloadManager manager] finishList];
}


+ (BOOL)isDownloadWithUrl:(NSString *)downloadURLString {
    return [[self manager] isDownloadWithUrl:downloadURLString];
}

+ (YCDownloadStatus)downloasStatusWithUrl:(NSString *)downloadURLString {
    return [[self manager] downloasStatusWithUrl:downloadURLString];
}

+ (YCDownloadItem *)downloadItemWithUrl:(NSString *)downloadURLString {
    return [[self manager] downloadItemWithUrl:downloadURLString];
}

+(void)allowsCellularAccess:(BOOL)isAllow {
    [[YCDownloadManager manager] allowsCellularAccess:isAllow];
}

+(void)localPushOn:(BOOL)isOn {
    [[YCDownloadManager manager] localPushOn:isOn];
}

#pragma mark tools
+(BOOL)isAllowsCellularAccess{
    return [[YCDownloadManager manager] isAllowsCellularAccess];
}


+ (NSUInteger)videoCacheSize {
    NSUInteger size = 0;
    NSArray *downloadList = [self downloadList];
    NSArray *finishList = [self finishList];
    for (YCDownloadTask *task in downloadList) {
        size += task.downloadedSize;
    }
    for (YCDownloadTask *task in finishList) {
        size += task.fileSize;
    }
    return size;
    
}
+ (NSUInteger)fileSystemFreeSize {
    NSUInteger totalFreeSpace = 0;
    NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
    
    if (dictionary) {
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        totalFreeSpace = [freeFileSystemSizeInBytes unsignedIntegerValue];
    }
    return totalFreeSpace;
}

+ (void)saveDownloadStatus {
    [[YCDownloadManager manager] saveDownloadItems];
}
+ (NSString *)fileSizeStringFromBytes:(uint64_t)byteSize {
    if (kCommonUtilsGigabyte <= byteSize) {
        return [NSString stringWithFormat:@"%@GB", [self numberStringFromDouble:(double)byteSize / kCommonUtilsGigabyte]];
    }
    if (kCommonUtilsMegabyte <= byteSize) {
        return [NSString stringWithFormat:@"%@MB", [self numberStringFromDouble:(double)byteSize / kCommonUtilsMegabyte]];
    }
    if (kCommonUtilsKilobyte <= byteSize) {
        return [NSString stringWithFormat:@"%@KB", [self numberStringFromDouble:(double)byteSize / kCommonUtilsKilobyte]];
    }
    return [NSString stringWithFormat:@"%zdB", byteSize];
}


+ (NSString *)numberStringFromDouble:(const double)num {
    NSInteger section = round((num - (NSInteger)num) * 100);
    if (section % 10) {
        return [NSString stringWithFormat:@"%.2f", num];
    }
    if (section > 0) {
        return [NSString stringWithFormat:@"%.1f", num];
    }
    return [NSString stringWithFormat:@"%.0f", num];
}

#pragma mark - private

- (void)setMaxTaskCount:(NSInteger)count{
    [YCDownloadSession downloadSession].maxTaskCount = count;
}


- (void)startDownloadWithUrl:(NSString *)downloadURLString fileName:(NSString *)fileName thumbImageUrl:(NSString *)imagUrl {
    
    YCDownloadItem *item = [[YCDownloadItem alloc] init];
    item.downloadUrl = downloadURLString;
    item.downloadStatus = YCDownloadStatusDownloading;
    item.fileName = fileName;
    item.thumbImageUrl = imagUrl;
    [self.itemsDictM setValue:item forKey:downloadURLString];
    [[YCDownloadSession downloadSession] startDownloadWithUrl:downloadURLString delegate:item];
    [self saveDownloadItems];
    
}


- (void)resumeDownloadWithUrl:(NSString *)downloadURLString {
    YCDownloadItem *item = [self.itemsDictM valueForKey:downloadURLString];
    item.downloadStatus = YCDownloadStatusDownloading;
    [[YCDownloadSession downloadSession] resumeDownloadWithUrl:downloadURLString delegate:item];
    [self saveDownloadItems];
}


- (void)pauseDownloadWithUrl:(NSString *)downloadURLString {
    YCDownloadItem *item = [self.itemsDictM valueForKey:downloadURLString];
    item.downloadStatus = YCDownloadStatusPaused;
    [[YCDownloadSession downloadSession] pauseDownloadWithUrl:downloadURLString];
    [self saveDownloadItems];
}

- (void)stopDownloadWithUrl:(NSString *)downloadURLString {
    [self.itemsDictM removeObjectForKey:downloadURLString];
    [[YCDownloadSession downloadSession] stopDownloadWithUrl:downloadURLString];
    [self saveDownloadItems];
}

- (void)pauseAllDownloadTask {
    [self.itemsDictM enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        YCDownloadItem *item = obj;
        item.downloadStatus = YCDownloadStatusPaused;
    }];
    [[YCDownloadSession downloadSession] pauseAllDownloadTask];
    [self saveDownloadItems];
}

-(NSArray *)downloadList {
    NSMutableArray *arrM = [NSMutableArray array];
    
    [self.itemsDictM enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        YCDownloadItem *item = obj;
        if(item.downloadStatus != YCDownloadStatusFinished){
            [arrM addObject:item];
        }
    }];
    
    return arrM;
}
- (NSArray *)finishList {
    NSMutableArray *arrM = [NSMutableArray array];
    [self.itemsDictM enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        YCDownloadItem *item = obj;
        if(item.downloadStatus == YCDownloadStatusFinished){
            [arrM addObject:item];
        }
    }];
    return arrM;
}

-(void)allowsCellularAccess:(BOOL)isAllow {
    [[YCDownloadSession downloadSession] allowsCellularAccess:isAllow];
}

- (BOOL)isAllowsCellularAccess {
    return [[YCDownloadSession downloadSession] isAllowsCellularAccess];
}

- (BOOL)isDownloadWithUrl:(NSString *)downloadURLString {
    
    YCDownloadItem *item = [self.itemsDictM valueForKey:downloadURLString];
    return item.downloadStatus == YCDownloadStatusFinished;
}

- (YCDownloadStatus)downloasStatusWithUrl:(NSString *)downloadURLString {
    YCDownloadItem *item = [self.itemsDictM valueForKey:downloadURLString];
    return item.downloadStatus;
}

- (YCDownloadItem *)downloadItemWithUrl:(NSString *)downloadURLString {
    YCDownloadItem *item = [self.itemsDictM valueForKey:downloadURLString];
    return item;
}

- (void)localPushOn:(BOOL)isOn {
    self.localPushOn = isOn;
}

#pragma mark notificaton


- (void)downloadAllTaskFinished{
    [self localPushWithTitle:@"YCDownloadSession" detail:@"所有的下载任务已完成！"];
}

- (void)downloadTaskFinishedNoti:(NSNotification *)noti{
    
    YCDownloadItem *item = noti.object;
    if (item) {
        NSString *detail = [NSString stringWithFormat:@"%@ 视频，已经下载完成！", item.fileName];
        [self localPushWithTitle:@"YCDownloadSession" detail:detail];
    }
}


#pragma mark local push

- (void)localPushWithTitle:(NSString *)title detail:(NSString *)body  {
    
    if (!self.localPushOn) return;
    
    // 1.创建本地通知
    UILocalNotification *localNote = [[UILocalNotification alloc] init];
    
    // 2.设置本地通知的内容
    // 2.1.设置通知发出的时间
    localNote.fireDate = [NSDate dateWithTimeIntervalSinceNow:3.0];
    // 2.2.设置通知的内容
    localNote.alertBody = body;
    // 2.3.设置滑块的文字（锁屏状态下：滑动来“解锁”）
    localNote.alertAction = @"滑动来“解锁”";
    // 2.4.决定alertAction是否生效
    localNote.hasAction = NO;
    // 2.5.设置点击通知的启动图片
    //    localNote.alertLaunchImage = @"123Abc";
    // 2.6.设置alertTitle
    localNote.alertTitle = title;
    // 2.7.设置有通知时的音效
    localNote.soundName = @"default";
    // 2.8.设置应用程序图标右上角的数字
    localNote.applicationIconBadgeNumber = 0;
    
    // 2.9.设置额外信息
    localNote.userInfo = @{@"type" : @1};
    
    // 3.调用通知
    [[UIApplication sharedApplication] scheduleLocalNotification:localNote];
    
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
