//
//  VideoViewController.m
//  CustomCameraDemo
//
//  Created by yanwenbin on 2021/11/30.
//

#import "VideoViewController.h"
#import "RecordProgressView.h"
#import "CameraHelper.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <Photos/Photos.h>
#import "AppDelegate.h"

#define KMaxRecordTimeSeconds 60

@interface VideoViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate>

/*********  设备   *********/
@property (nonatomic ,strong) AVCaptureSession *session; // 会话 由他把输入输出结合在一起，并开始启动捕获设备（摄像头）
@property (nonatomic ,strong) AVCaptureDevice *device; // 视频输入设备
@property (nonatomic ,strong) AVCaptureDevice *audioDevice; // 音频输入设备
@property (nonatomic ,strong) AVCaptureDeviceInput *deviceInput;//图像输入源
@property (nonatomic ,strong) AVCaptureDeviceInput *audioInput; //音频输入源
@property (nonatomic ,strong) AVCaptureAudioDataOutput *audioPutData;   //音频输出源
@property (nonatomic ,strong) AVCaptureVideoDataOutput *videoPutData;   //视频输出源
@property (nonatomic ,strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic ,strong) AVCaptureConnection *connection;
@property (nonatomic ,strong) AVAssetWriter *writer;//视频采集
@property (nonatomic ,strong) AVAssetWriterInput *writerAudioInput;//音频采集
@property (nonatomic ,strong) AVAssetWriterInput *writerVideoInput;//视频采集

/*********  界面UI  *********/
@property (nonatomic, strong) UIView *leftView;
@property (nonatomic, strong) UIButton *cancelBtn;
@property (nonatomic, strong) UIView *timeView;
@property (nonatomic, strong) UILabel *timelabel;
@property (nonatomic, strong) UIButton *turnCamera; //前后置摄像头切换
@property (nonatomic, strong) UIButton *flashBtn;  //闪光灯
@property (nonatomic, strong) RecordProgressView *progressView;
@property (nonatomic, strong) UIButton *recordBtn; //拍摄按钮
@property (nonatomic)UIImageView *focusView; //聚焦
@property (nonatomic, strong) UIButton *videoPlayBtn; //播放上一個录制的视频按钮

/******** 其他 ******/
@property (nonatomic, strong) NSTimer *timer; // 录制定时器
@property (nonatomic ,assign) CGFloat recordTime; // 录制时间
@property (nonatomic ,assign) BOOL videoRecording;  //视频正在录制
@property (nonatomic ,assign) BOOL canWritting;     //可以写入文件
@property (nonatomic ,strong) NSURL *preVideoURL;   //视频预览（存储）地址

@end

@implementation VideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    [self forceOrientationLandscapeWith:self];
    if ([self checkCameraPermission]) {
        [self customCamera];
        [self loadUI];
        [self addTap];
    }
    // Do any additional setup after loading the view.
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    if (self.session) {
        [self.session startRunning];
    }
}

-(void)dealloc {
    NSLog(@"VideoViewController dealloc");
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
}

#pragma mark - 界面布局
-(void)loadUI {
    [self.view addSubview:self.focusView];
    double width = 0.0;
    double height = 0.0;
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    if (screenSize.width > screenSize.height) {
        width = screenSize.width;
        height = screenSize.height;
    } else {
        width = screenSize.height;
        height = screenSize.width;
    }
    CGFloat statusBarHeight = [CameraHelper getStatusBarHeight];
    self.leftView = [[UIView alloc] init];
    self.leftView.frame = CGRectMake(statusBarHeight, 0, statusBarHeight+44.0, height);
    [self.view addSubview:self.leftView];
    // 返回按钮
    self.cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.cancelBtn.frame = CGRectMake(15, 10, 28, 28);
    [self.cancelBtn setImage:[UIImage imageNamed:@"xiangjifanhiu"] forState:UIControlStateNormal];
    [self.cancelBtn addTarget:self action:@selector(dismissVC) forControlEvents:UIControlEventTouchUpInside];
    [self.leftView addSubview:self.cancelBtn];
    // 旋转摄像头
    self.turnCamera = [UIButton buttonWithType:UIButtonTypeCustom];
    self.turnCamera.frame = CGRectMake(15, height-25-75, 28, 28);
    [self.turnCamera setImage:[UIImage imageNamed:@"qianzhishexiangtou"] forState:UIControlStateNormal];
    [self.turnCamera addTarget:self action:@selector(turnCameraAction) forControlEvents:UIControlEventTouchUpInside];
    [self.turnCamera sizeToFit];
    [self.leftView addSubview:self.turnCamera];
    // 闪光灯
    self.flashBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.flashBtn.frame = CGRectMake(15, height-28-25, 28, 28);
    [self.flashBtn setImage:[UIImage imageNamed:@"shanguangdeng_guan"] forState:UIControlStateNormal];
    [self.flashBtn addTarget:self action:@selector(flashAction) forControlEvents:UIControlEventTouchUpInside];
    [self.flashBtn sizeToFit];
    [self.leftView addSubview:self.flashBtn];
    // 进度条
    self.progressView = [[RecordProgressView alloc] initWithFrame:CGRectMake(width - 32 - 68, (height - 68)/2.0, 68, 68)];
    self.progressView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.progressView];
    // 录制按钮
    self.recordBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.recordBtn addTarget:self action:@selector(startRecord) forControlEvents:UIControlEventTouchUpInside];
    self.recordBtn.frame = CGRectMake(5, 5, 58, 58);
    self.recordBtn.backgroundColor = [UIColor whiteColor];
    self.recordBtn.layer.cornerRadius = 29;
    self.recordBtn.layer.masksToBounds = YES;
    [self.progressView addSubview:self.recordBtn];
    [self.progressView resetProgress];
    // 录制时间视图
    self.timeView = [[UIView alloc] init];
    self.timeView.hidden = YES;
    self.timeView.frame = CGRectMake((width - 100)/2, height, 100, 34);
//    self.timeView.backgroundColor = [UIColor colorWithRGB:0x242424 alpha:0.7];
    self.timeView.layer.cornerRadius = 4;
    self.timeView.layer.masksToBounds = YES;
    self.timeView.center = CGPointMake(self.progressView.center.x, CGRectGetMaxY(self.progressView.frame)+20);
    [self.view addSubview:self.timeView];
    //
    UIView *redPoint = [[UIView alloc] init];
    redPoint.frame = CGRectMake(0, 0, 6, 6);
    redPoint.layer.cornerRadius = 3;
    redPoint.layer.masksToBounds = YES;
    redPoint.center = CGPointMake(20, 17);
    redPoint.backgroundColor = [UIColor redColor];
    [self.timeView addSubview:redPoint];
    // 时间
    self.timelabel = [[UILabel alloc] init];
    self.timelabel.font = [UIFont boldSystemFontOfSize:15];
    self.timelabel.textAlignment = NSTextAlignmentCenter;
    self.timelabel.textColor = [UIColor whiteColor];
    self.timelabel.frame = CGRectMake(20, 0, 60, 34);
    [self.timeView addSubview:self.timelabel];
    // 播放按钮
    self.videoPlayBtn = [[UIButton alloc] init];
    self.videoPlayBtn.frame = CGRectMake(width - 32 - 50, height - 50, 50, 30);
    [self.videoPlayBtn setTitle:@"play" forState:UIControlStateNormal];
    [self.videoPlayBtn addTarget:self action:@selector(lastVideoPlay) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.videoPlayBtn];
}

- (void)updateViewWithRecording
{
    self.timeView.hidden = NO;
    self.turnCamera.hidden = YES;
    self.cancelBtn.hidden = YES;
    self.videoPlayBtn.hidden = YES;
    [self changeToRecordStyle];
}

- (void)updateViewWithStop
{
    [self.progressView resetProgress];
    self.timeView.hidden = YES;
    self.turnCamera.hidden = NO;
    self.cancelBtn.hidden = NO;
    self.videoPlayBtn.hidden = false;
    [self changeToStopStyle];
}

- (void)changeToRecordStyle
{
    self.recordBtn.backgroundColor = [UIColor orangeColor];
    [UIView animateWithDuration:0.2 animations:^{
        CGPoint center = self.recordBtn.center;
        CGRect rect = self.recordBtn.frame;
        rect.size = CGSizeMake(28, 28);
        self.recordBtn.frame = rect;
        self.recordBtn.layer.cornerRadius = 4;
        self.recordBtn.center = center;
    }];
}

- (void)changeToStopStyle
{
    self.recordBtn.backgroundColor = [UIColor whiteColor];
    [UIView animateWithDuration:0.2 animations:^{
        CGPoint center = self.recordBtn.center;
        CGRect rect = self.recordBtn.frame;
        rect.size = CGSizeMake(58, 58);
        self.recordBtn.frame = rect;
        self.recordBtn.layer.cornerRadius = 29;
        self.recordBtn.center = center;
    }];
}

#pragma mark - 初始化相机
-(void)customCamera {
    
    // 1.1 初始化session会话
    self.session = [[AVCaptureSession alloc] init];
    if ([self.session canSetSessionPreset:AVCaptureSessionPresetHigh]){
        self.session.sessionPreset = AVCaptureSessionPresetHigh;
    }else if ([self.session canSetSessionPreset:AVCaptureSessionPresetiFrame960x540]) {
        self.session.sessionPreset = AVCaptureSessionPresetiFrame960x540;
    }
    
    // 1.2 获取视频输入设备(摄像头)
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [_device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus];
    
    // 1.3 创建视频输入源 并添加到会话
    NSError *error = nil;
    self.deviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.device error:&error];
    if (!error) {
        if ([self.session canAddInput:self.deviceInput]) {
            [self.session addInput:self.deviceInput];
        }
    }

    // 1.4 创建视频输出源 并添加到会话
    NSDictionary *videoSetting = @{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)};
    self.videoPutData = [[AVCaptureVideoDataOutput alloc] init];
    self.videoPutData.videoSettings = videoSetting;
    self.videoPutData.alwaysDiscardsLateVideoFrames = YES; //立即丢弃旧帧，节省内存，默认YES
    dispatch_queue_t videoQueue = dispatch_queue_create("vidio", DISPATCH_QUEUE_CONCURRENT);
    [self.videoPutData setSampleBufferDelegate:self queue:videoQueue];
    if ([self.session canAddOutput:self.videoPutData]) {
        [self.session addOutput:self.videoPutData];
    }
    
    // 1.5 设置视频输出源方向
    AVCaptureConnection *imageConnection = [self.videoPutData connectionWithMediaType:AVMediaTypeVideo];
    // 设置 imageConnection 控制相机拍摄图片的角度方向
    if (imageConnection.supportsVideoOrientation) {
        imageConnection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
    }
    
    // 2.1 获取音频输入设备
    self.audioDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    // 2.2 创建音频输入源 并添加到会话
    NSError *audioError = nil;
    self.audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.audioDevice error:&audioError];
    if (!audioError) {
        if ([self.session canAddInput:self.audioInput]) {
            [self.session addInput:self.audioInput];
        }
    }
    
    // 2.3 创建音频输出源 并添加到会话
    self.audioPutData = [[AVCaptureAudioDataOutput alloc] init];
    if ([self.session canAddOutput:self.audioPutData]) {
        [self.session addOutput:self.audioPutData];
    }
    dispatch_queue_t audioQueue = dispatch_queue_create("audio", DISPATCH_QUEUE_CONCURRENT);
    [self.audioPutData setSampleBufferDelegate:self queue:audioQueue]; // 设置写入代理
    
    // 3.1 使用self.session，初始化预览层，self.session负责驱动input进行信息的采集，layer负责把图像渲染显示
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:self.session];
    double width = 0.0;
    double height = 0.0;
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    if (screenSize.width > screenSize.height) {
        width = screenSize.width;
        height = screenSize.height;
    } else {
        width = screenSize.height;
        height = screenSize.width;
    }
    self.previewLayer.frame = CGRectMake(0, 0, width,height);
    self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight; // 图层展示拍摄角度方向
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:self.previewLayer];
    
    // 3.2 开始采集
    [self.session startRunning];
}

// 获取摄像头
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position] == position) {
            return camera;
        }
    }
    return nil;
}

#pragma mark - 录制
//开始、停止录制
- (void)startRecord {
    if (self.videoRecording) {
        [self stopVideoRecord];
        [self updateViewWithStop];
    } else {
        self.recordTime = 0;
        self.timelabel.text = @"00:00";
        [self setUpWriter];
    }
}

// 文件写入配置
- (void)setUpWriter
{
    // 1. 获取存储路径
    self.preVideoURL = [self createVideoFilePathUrl];
    // 2.开启异步线程进行写入配置
    dispatch_queue_t writeQueueCreate = dispatch_queue_create("writeQueueCreate", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(writeQueueCreate, ^{
        // 3.生成视频采集对象
        NSError *error = nil;
        self.writer = [AVAssetWriter assetWriterWithURL:self.preVideoURL fileType:AVFileTypeMPEG4 error:&error];
        if (!error) {
            double width = 0.0;
            double height = 0.0;
            CGSize screenSize = [UIScreen mainScreen].bounds.size;
            if (screenSize.width > screenSize.height) {
                width = screenSize.width;
                height = screenSize.height;
            } else {
                width = screenSize.height;
                height = screenSize.width;
            }
            
            // 4.生成图像采集对象并添加到视频采集对象
            NSInteger numPixels = width * height;
            //每像素比特
            CGFloat bitsPerPixel = 12.0;
            NSInteger bitsPerSecond = numPixels * bitsPerPixel;
            // 码率和帧率设置
            NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond),
                                                     AVVideoExpectedSourceFrameRateKey : @(30),
                                                     AVVideoMaxKeyFrameIntervalKey : @(30),
                                                     AVVideoProfileLevelKey : AVVideoProfileLevelH264BaselineAutoLevel };
            //视频属性
            NSDictionary *videoSetting = @{ AVVideoCodecKey : AVVideoCodecTypeH264,
                                            AVVideoWidthKey : @(width),
                                            AVVideoHeightKey : @(height),
                                            AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
                                            AVVideoCompressionPropertiesKey : compressionProperties };
            self.writerVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSetting];
            self.writerVideoInput.expectsMediaDataInRealTime = YES; //expectsMediaDataInRealTime 必须设为yes，需要从capture session 实时获取数据
            //            self.writerVideoInput.transform = CGAffineTransformMakeRotation(M_PI/2.0);
            
            if ([self.writer canAddInput:self.writerVideoInput]) {
                [self.writer addInput:self.writerVideoInput];
            }
            
            // 5.生成音频采集对象并添加到视频采集对象
            NSDictionary *audioSetting = @{ AVEncoderBitRatePerChannelKey : @(28000),
                                            AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                            AVNumberOfChannelsKey : @(1),
                                            AVSampleRateKey : @(22050) };
            self.writerAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSetting];
            
            self.writerAudioInput.expectsMediaDataInRealTime = YES; //expectsMediaDataInRealTime 必须设为yes，需要从capture session 实时获取数据
            
            if ([self.writer canAddInput:self.writerAudioInput]) {
                [self.writer addInput:self.writerAudioInput];
            }
            
            self.videoRecording = YES;
            // 开始录制界面布局
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateViewWithRecording];
                if (!self.timer) {
                    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
                }
            });
            
        }else{
            NSLog(@"write 初始化失败：%@",error);
        }
    });
}

// 停止录制视频
-(void)stopVideoRecord {
    self.canWritting = NO;
    self.videoRecording = NO;
    [self.session stopRunning];
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }

    __weak typeof(self)weakSelf = self;

    dispatch_queue_t writeQueue = dispatch_queue_create("writeQueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(writeQueue, ^{

        if (weakSelf.writer.status == AVAssetWriterStatusWriting) {

            [weakSelf.writer finishWritingWithCompletionHandler:^{
                [weakSelf saveVideoToAlbum];
                [self.session startRunning];
            }];
        }
    });
}

#pragma mark - IBAction
// 返回
- (void)dismissVC {
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self forceOrientationPortraitWith:self]; //竖屏
    [self.navigationController popViewControllerAnimated:YES];
}

// 切换摄像头
- (void)turnCameraAction {
    [self.session stopRunning];
    // 1. 获取当前摄像头
    AVCaptureDevicePosition position = self.deviceInput.device.position;
    
    //2. 获取当前需要展示的摄像头
    if (position == AVCaptureDevicePositionBack) {
        position = AVCaptureDevicePositionFront;
    } else {
        position = AVCaptureDevicePositionBack;
    }
    
    // 3. 根据当前摄像头创建新的device
    AVCaptureDevice *device = [self getCameraDeviceWithPosition:position];
    
    // 4. 根据新的device创建input
    AVCaptureDeviceInput *newInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
    
    //5. 在session中切换input
    if (newInput != nil) {
        [self.session beginConfiguration];
        //先移除原来的input
        [self.session removeInput:self.deviceInput];
        if ([self.session canAddInput:newInput]) {
            [self.session addInput:newInput];
            self.deviceInput = newInput;
        } else {
            //如果不能加现在的input，就加原来的input
            [self.session addInput:self.deviceInput];
        }
        [self.session commitConfiguration];
    }
    
    [self.session startRunning];
}

// 闪光灯
- (void)flashAction {
    if ([self.device lockForConfiguration:nil]) {

        if ([self.device hasFlash]) {

            if (self.device.flashMode == AVCaptureFlashModeAuto) {
                self.device.flashMode = AVCaptureFlashModeOn;
                [self.flashBtn setImage:[UIImage imageNamed:@"shanguangdeng_kai"] forState:UIControlStateNormal];

            }else if (self.device.flashMode == AVCaptureFlashModeOn){
                self.device.flashMode = AVCaptureFlashModeOff;
                [self.flashBtn setImage:[UIImage imageNamed:@"shanguangdeng_guan"] forState:UIControlStateNormal];

            }else{

                self.device.flashMode = AVCaptureFlashModeAuto;
                [self.flashBtn setImage:[UIImage imageNamed:@"shanguangdeng_zidong"] forState:normal];
            }
        }
        [self.device unlockForConfiguration];
    }
}

// 聚焦
- (void)focusGesture:(UITapGestureRecognizer*)gesture{
    CGPoint point = [gesture locationInView:gesture.view];
    [self focusAtPoint:point];
}

- (void)focusAtPoint:(CGPoint)point{
    CGSize size = self.view.bounds.size;
    // focusPoint 函数后面Point取值范围是取景框左上角（0，0）到取景框右下角（1，1）之间,有时按这个来但位置不对，按实际适配
    CGPoint focusPoint = CGPointMake( point.x /size.width , point.y/size.height );
    if ([self.device lockForConfiguration:nil]) {
        [self.session beginConfiguration];
        /*****必须先设定聚焦位置，在设定聚焦方式******/
        //聚焦点的位置
        if ([self.device isFocusPointOfInterestSupported]) {
            [self.device setFocusPointOfInterest:focusPoint];
        } else {
            NSLog(@"聚焦点修改失败");
        }
        // 聚焦模式
        if ([self.device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            [self.device setFocusMode:AVCaptureFocusModeAutoFocus];
        }else{
            NSLog(@"聚焦模式修改失败");
        }
        //曝光点的位置
        if ([self.device isExposurePointOfInterestSupported]) {
            [self.device setExposurePointOfInterest:focusPoint];
        } else {
            NSLog(@"曝光点修改失败");
        }
        //曝光模式
        if ([self.device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            [self.device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
        } else {
            NSLog(@"曝光模式修改失败");
        }
        [self.device unlockForConfiguration];
        [self.session commitConfiguration];
        _focusView.center = point;
        _focusView.hidden = NO;
        [UIView animateWithDuration:0.2 animations:^{
            self.focusView.transform = CGAffineTransformMakeScale(1.25, 1.25);
        }completion:^(BOOL finished) {
            [UIView animateWithDuration:0.3 animations:^{
                self.focusView.transform = CGAffineTransformIdentity;
            } completion:^(BOOL finished) {
                self.focusView.hidden = YES;
            }];
        }];
    }
}

// 录制计时
- (void)updateProgress {
    if (self.recordTime >= KMaxRecordTimeSeconds) {
        [self stopVideoRecord];
        return;
    }
    self.recordTime++;
    [self.progressView updateProgressWithValue:self.recordTime*1.0/KMaxRecordTimeSeconds];
    self.timelabel.text = [NSString stringWithFormat:@"%02li:%02li",lround(floor(self.recordTime/60.f)),lround(floor(self.recordTime/1.f))%60];
}

// 播放上一个视频
- (void)lastVideoPlay {
    AVPlayerViewController *avPlayerVC = [[AVPlayerViewController alloc] init];
    avPlayerVC.view.frame = self.view.frame;
    avPlayerVC.showsPlaybackControls = YES;
    avPlayerVC.player = [AVPlayer playerWithURL:self.preVideoURL];
    [self presentViewController:avPlayerVC animated:YES completion:^{
        [avPlayerVC.player play];
    }];
}

#pragma mark - 旋转屏幕
// 横屏 home键在右边
-(void)forceOrientationLandscapeWith:(UIViewController *)VC{
    AppDelegate *appdelegate=(AppDelegate *)[UIApplication sharedApplication].delegate;
    appdelegate.isForcePortrait = NO;
    appdelegate.isForceLandscape = YES;
    if ([appdelegate respondsToSelector:@selector(application:supportedInterfaceOrientationsForWindow:)]) {
        [appdelegate application:[UIApplication sharedApplication] supportedInterfaceOrientationsForWindow:VC.view.window];
        //强制翻转屏幕，Home键在右边。
        [[UIDevice currentDevice] setValue:@(UIInterfaceOrientationLandscapeRight) forKey:@"orientation"];
        //刷新
        [UIViewController attemptRotationToDeviceOrientation];
    }
}

// 竖屏
- (void)forceOrientationPortraitWith:(UIViewController *)VC{
    AppDelegate *appdelegate=(AppDelegate *)[UIApplication sharedApplication].delegate;
    appdelegate.isForcePortrait = YES;
    appdelegate.isForceLandscape = NO;
    if ([appdelegate respondsToSelector:@selector(application:supportedInterfaceOrientationsForWindow:)]) {
        [appdelegate application:[UIApplication sharedApplication] supportedInterfaceOrientationsForWindow:VC.view.window];
        //强制翻转屏幕
        [[UIDevice currentDevice] setValue:@(UIDeviceOrientationPortrait) forKey:@"orientation"];
        //刷新
        [UIViewController attemptRotationToDeviceOrientation];
    }
}

#pragma mark - 相机权限
- (BOOL)checkCameraPermission
{
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusDenied || authStatus == AVAuthorizationStatusRestricted) {
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"请打开相机权限" message:@"设置-隐私-相机" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *done = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL * url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url options:@{UIApplicationOpenSettingsURLString:@YES} completionHandler:nil];
            }
        }];
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self dismissVC];
        }];
        [alertVC addAction:done];
        [alertVC addAction:cancel];
        [self presentViewController:alertVC animated:NO completion:^{
        }];
        return NO;
    } else if (authStatus == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                if (granted) {
                    [self customCamera];
                    [self loadUI];
                    [self addTap];
                } else {
                    [self dismissVC];
                }
            });
        }];
        return NO;
    }
    else {
        return YES;
    }
}

#pragma mark - 代理

//视频录制回调
-(void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{

    if (!self.videoRecording) {
        return;
    }

    CMFormatDescriptionRef desMedia = CMSampleBufferGetFormatDescription(sampleBuffer);
    CMMediaType mediaType = CMFormatDescriptionGetMediaType(desMedia);

    if (mediaType == kCMMediaType_Video) {
        
        /**
         * 注意：
         * 对于 开始播放时间startSessionAtSourceTime的 开启时机需要放在类型为
         * kCMMediaType_Video 里判断，因为如果放在外边，可能会导致录制的时候
         * 是没有画面的，但是有声音，这就导致了预览视频的时候发现开头有一段空白视频
         * 但是是有声音的
         * 所以需要将 startSessionAtSourceTime 方法放在类型为kCMMediaType_Video里
         * 确保第一帧为图像在开启录制
         */
        
        if (!self.canWritting) {
            [self.writer startWriting];
            CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            self.canWritting = YES;
            [self.writer startSessionAtSourceTime:timestamp];
        }
    }
    
    if (self.canWritting) {
        if (mediaType == kCMMediaType_Video) {
            if (self.writerVideoInput.readyForMoreMediaData) {
                BOOL success = [self.writerVideoInput appendSampleBuffer:sampleBuffer];
                if (!success) {
                    NSLog(@"video write failed");
                }
            }
        }else if (mediaType == kCMMediaType_Audio){
            if (self.writerAudioInput.readyForMoreMediaData) {
                BOOL success = [self.writerAudioInput appendSampleBuffer:sampleBuffer];
                if (!success) {
                    NSLog(@"audio write failed");
                }
            }
        }
    }
}

#pragma mark - 其他
//写入的视频路径 用于视频标志，需要唯一
- (NSURL *)createVideoFilePathUrl
{
    NSString *documentPath = [NSHomeDirectory() stringByAppendingString:@"/Documents/shortVideo"];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];

    NSString *destDateString = [dateFormatter stringFromDate:[NSDate date]];
    NSString *videoName = [destDateString stringByAppendingString:@".mp4"];

    NSString *filePath = [documentPath stringByAppendingFormat:@"/%@",videoName];

    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL isDir;
    if (![manager fileExistsAtPath:documentPath isDirectory:&isDir]) {
        [manager createDirectoryAtPath:documentPath withIntermediateDirectories:YES attributes:nil error:nil];

    }
    
    return [NSURL fileURLWithPath:filePath];
}

- (void)saveVideoToAlbum {
    PHPhotoLibrary *photoLibrary = [PHPhotoLibrary sharedPhotoLibrary];
    [photoLibrary performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:self.preVideoURL];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            NSLog(@"已将视频保存至相册");
        } else {
            NSLog(@"未能保存视频到相册");
        }
    }];
}

// 添加聚焦手势
- (void)addTap {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusGesture:)];
    [self.view addGestureRecognizer:tap];
}

#pragma mark - 懒加载
-(UIImageView *)focusView
{
    if (_focusView == nil) {
        _focusView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 80, 80)];
        _focusView.backgroundColor = [UIColor clearColor];
        _focusView.image = [UIImage imageNamed:@"icon_1"];
        _focusView.hidden = YES;
    }
    return _focusView;
}


@end
