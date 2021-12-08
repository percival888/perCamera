//
//  CameraViewController.m
//  CustomCameraDemo
//
//  Created by ywb on 2021/11/27.
//

#import "CameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <CoreMotion/CoreMotion.h>
#import "AppDelegate.h"
#import "CameraHelper.h"

typedef enum : NSUInteger {
    GravityUp,     //垂直屏幕正方向
    GravityDown,   //垂直屏幕反方向
    GravityLeft,   //横屏home键在左
    GravityRight   //横屏home键在右
} PAGravityDirectionType;

@interface CameraViewController ()<AVCapturePhotoCaptureDelegate>

// ------------- 设备配置等 -------------
//捕获设备，通常是前置摄像头，后置摄像头，麦克风（音频输入）
@property(nonatomic)AVCaptureDevice *device;
//AVCaptureDeviceInput 代表输入设备，使用AVCaptureDevice 来初始化
@property(nonatomic)AVCaptureDeviceInput *input;
//照片输出流
@property (nonatomic)AVCapturePhotoOutput *imageOutPut;
//session：由他把输入输出结合在一起，并开始启动捕获设备（摄像头）
@property(nonatomic)AVCaptureSession *session;
//图像预览层，实时显示捕获的图像
@property(nonatomic)AVCaptureVideoPreviewLayer *previewLayer;

// ------------- UI --------------
//拍照按钮
@property (nonatomic)UIButton *photoButton;
//返回按钮
@property (nonatomic, strong)UIButton *backBtn;
//高清按钮
@property (nonatomic, strong)UIButton *hdButton;
//闪光灯按钮
@property (nonatomic)UIButton *flashButton;
//切换摄像头按钮
@property (nonatomic, strong)UIButton *changeCameraBtn;
//打开手电筒按钮
@property (nonatomic, strong)UIButton *flashlightBtn;
//聚焦
@property (nonatomic)UIImageView *focusView;
//蒙层
@property (nonatomic, strong)UIView *backBlackView;

// -------------- 其他 -----------------
//重力感应对象
@property (nonatomic,strong) CMMotionManager *motionManager;
//重力方向
@property(nonatomic,assign)PAGravityDirectionType gravityDerectionType;

@end

@implementation CameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    [self forceOrientationLandscapeWith:self];
    if ([self checkCameraPermission]) {
        [self customCamera];
        [self loadUI];
        [self addTap];
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    //开始检测重力方向
    [self startUpdateAccelerometerResult];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    //停止检测重力方向
    [self stopUpdate];
}

-(void)dealloc
{
    _motionManager = nil;
    NSLog(@"拍照界面释放");
}

#pragma mark - 初始化相机设备
- (void)customCamera
{
    // 1.1 初始化session会话，用来结合输入输出
    self.session = [[AVCaptureSession alloc] init];
    if ([self.session canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        [self.session setSessionPreset:AVCaptureSessionPreset1280x720];  //拿到的图像的大小可以自行设定
    }
    
    // 1.2 获取视频输入设备(摄像头)
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // 1.3 创建视频输入源 并添加到会话
    self.input = [[AVCaptureDeviceInput alloc]initWithDevice:self.device error:nil];
    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    }
    
    // 1.4 创建视频输出源 并添加到会话
    self.imageOutPut = [[AVCapturePhotoOutput alloc]init];
    if ([self.session canAddOutput:self.imageOutPut]) {
        [self.session addOutput:self.imageOutPut];
    }
    AVCaptureConnection *imageConnection = [self.imageOutPut connectionWithMediaType:AVMediaTypeVideo];
    // 设置 imageConnection 控制相机拍摄图片的角度方向
    if (imageConnection.supportsVideoOrientation) {
        imageConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    }
    
    
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
    
    // 2.1 使用self.session初始化预览层，self.session负责驱动input进行信息的采集，layer负责把图像渲染显示
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewLayer.frame = CGRectMake(0, 0, width,height);
    self.previewLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight; // 图层展示拍摄角度方向
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:self.previewLayer];
    
    // 3.1 属性配置
    if ([self.device lockForConfiguration:nil]) { // 修改设备的属性，先加锁
        //闪光灯自动
        if ([[self.imageOutPut supportedFlashModes] containsObject:@(AVCaptureFlashModeAuto)]) {
            self.imageOutPut.photoSettingsForSceneMonitoring.flashMode = AVCaptureFlashModeAuto;
        }
        //自动白平衡
        if ([self.device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
            [self.device setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
        }
        //解锁
        [self.device unlockForConfiguration];
    }
    
    // 4.1开始采集画面
    [self.session startRunning];
}

// 添加聚焦手势
- (void)addTap {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusGesture:)];
    [self.view addGestureRecognizer:tap];
}

#pragma mark - 界面布局
-(void)loadUI
{
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
    
    //点击拍照闪现蒙层
    self.backBlackView = [[UIView alloc] init];
    self.backBlackView.frame = self.previewLayer.frame;
    self.backBlackView.backgroundColor = [UIColor blackColor];
    self.backBlackView.alpha = 0;
    [self.view addSubview:self.backBlackView];
    
    //返回按钮
    CGFloat statusBarHeight = [CameraHelper getStatusBarHeight];
    self.backBtn = [[UIButton alloc] initWithFrame:CGRectMake(statusBarHeight-20, 15, 28, 28)];
    [self.backBtn setImage:[UIImage imageNamed:@"xiangjifanhiu"] forState:UIControlStateNormal];
    [self.backBtn addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.backBtn];
    
    //闪光灯按钮
    self.flashButton = [[UIButton alloc] initWithFrame:CGRectMake(statusBarHeight-20, height-28-131, 28, 28)];
    [self.flashButton setImage:[UIImage imageNamed:@"shanguangdeng_zidong"] forState:normal];
    self.flashButton.tag = 3;
    [self.flashButton addTarget:self action:@selector(FlashOn:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.flashButton];
    
    //切换摄像头按钮
    self.changeCameraBtn = [[UIButton alloc] initWithFrame:CGRectMake(statusBarHeight-20, height-28-78, 28, 28)];
    [self.changeCameraBtn setImage:[UIImage imageNamed:@"qianzhishexiangtou"] forState:normal];
    [self.changeCameraBtn setImage:[UIImage imageNamed:@"qianzhishexiangtou_dianji"] forState:UIControlStateSelected];
    [self.changeCameraBtn addTarget:self action:@selector(changeCamera:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.changeCameraBtn];
    
    //手电筒按钮
    self.flashlightBtn = [[UIButton alloc] initWithFrame:CGRectMake(statusBarHeight-20, height-28-25, 28, 28)];
    [self.flashlightBtn setImage:[UIImage imageNamed:@"shoudiantong_guan"] forState:UIControlStateNormal];
    [self.flashlightBtn setImage:[UIImage imageNamed:@"shoudiantong_kai"] forState:UIControlStateSelected];
    [self.flashlightBtn addTarget:self action:@selector(flashLightOpen:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.flashlightBtn];
    
    //拍照按钮
    self.photoButton = [[UIButton alloc] initWithFrame:CGRectMake(width-116-68, (height-68)/2, 68, 68)];
    [self.photoButton setImage:[UIImage imageNamed:@"paizhao"] forState:UIControlStateNormal];
    [self.photoButton addTarget:self action:@selector(shutterCamera) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.photoButton];
}

#pragma mark - IBAction
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

//开启闪光灯
- (void)FlashOn:(UIButton *)sender{
    
    if ([_device lockForConfiguration:nil]) {
        if (sender.tag == 2) {  //当前打开闪光灯
            if ([[self.imageOutPut supportedFlashModes] containsObject:@(AVCaptureFlashModeAuto)]) {
                self.imageOutPut.photoSettingsForSceneMonitoring.flashMode = AVCaptureFlashModeAuto;
                [sender setImage:[UIImage imageNamed:@"shanguangdeng_zidong"] forState:normal];
                sender.tag = 3;
            }
        }
        else if (sender.tag == 3) //当前自动闪光灯
        {
            if ([[self.imageOutPut supportedFlashModes] containsObject:@(AVCaptureFlashModeOff)]) {
                self.imageOutPut.photoSettingsForSceneMonitoring.flashMode = AVCaptureFlashModeOff;
                [sender setImage:[UIImage imageNamed:@"shanguangdeng_guan"] forState:normal];
                sender.tag = 1;
            }
        } else { //当前关闭闪光灯
            if ([[self.imageOutPut supportedFlashModes] containsObject:@(AVCaptureFlashModeOn)]) {
                self.imageOutPut.photoSettingsForSceneMonitoring.flashMode = AVCaptureFlashModeOn;
                [sender setImage:[UIImage imageNamed:@"shanguangdeng_kai"] forState:normal];
                sender.tag = 2;
            }
        }
        [_device unlockForConfiguration];
    }
}

//打开手电筒
-(void)flashLightOpen:(UIButton *)sender
{
    //获取当前相机的方向(前还是后) 前置摄像头不允许开启手电筒
    AVCaptureDevicePosition position = [[self.input device] position];
    if (position == AVCaptureDevicePositionFront) {
        NSLog(@"前置摄像时无法开启手电筒");
        return;
    }
    AVCaptureDevice *device = self.device;
    if ([device hasTorch]) { // 判断是否有闪光灯
        // 请求独占访问硬件设备
        [device lockForConfiguration:nil];
        if (sender.selected == NO) {
            sender.selected = YES;
            [device setTorchMode:AVCaptureTorchModeOn]; // 手电筒开
        } else {
            sender.selected = NO;
            [device setTorchMode:AVCaptureTorchModeOff]; // 手电筒关
        }
        // 请求解除独占访问硬件设备
        [device unlockForConfiguration];
    }
}

//切换摄像头
- (void)changeCamera:(UIButton *)sender
{
    //获取摄像头的数量
    NSUInteger cameraCount = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
    //摄像头小于等于1的时候直接返回
    if (cameraCount <= 1) return;
    AVCaptureDevice *newCamera = nil;
    AVCaptureDeviceInput *newInput = nil;
    //获取当前相机的方向(前还是后)
    AVCaptureDevicePosition position = [[self.input device] position];
    //为摄像头的转换加转场动画
    CATransition *animation = [CATransition animation];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.duration = 0.5;
    animation.type = @"oglFlip";
    if (position == AVCaptureDevicePositionFront) {
        //获取后置摄像头
        newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
        animation.subtype = kCATransitionFromLeft;
        sender.selected = NO;
    }else{
        //获取前置摄像头
        newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
        animation.subtype = kCATransitionFromRight;
        sender.selected = YES;
        self.flashlightBtn.selected = NO;
    }
    [self.previewLayer addAnimation:animation forKey:nil];
    //输入流
    newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil];
    if (newInput != nil) {
        [self.session beginConfiguration];
        //先移除原来的input
        [self.session removeInput:self.input];
        if ([self.session canAddInput:newInput]) {
            [self.session addInput:newInput];
            self.input = newInput;
        } else {
            //如果不能加现在的input，就加原来的input
            [self.session addInput:self.input];
        }
        [self.session commitConfiguration];
    }
}

//获取当前摄像头
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice *device in devices )
        if ( device.position == position ) return device;
    return nil;
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
            [self dismiss];
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
                    [self dismiss];
                }
            });
        }];
        return NO;
    }
    else {
        return YES;
    }
}

#pragma mark - 方法
// 返回
-(void)dismiss {
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [self forceOrientationPortraitWith:self]; //竖屏
    [self.navigationController popViewControllerAnimated:YES];
}

// 保存照片
- (void)shutterCamera
{
    AVCaptureConnection * videoConnection = [self.imageOutPut connectionWithMediaType:AVMediaTypeVideo];
    if (videoConnection ==  nil) {
        return;
    }
    
    [UIView animateWithDuration:0.06 animations:^{
        self.backBlackView.alpha = 1;
    } completion:^(BOOL finished) {
        
        [UIView animateWithDuration:0.2 animations:^{
            self.backBlackView.alpha = 0;
        }];
        
    }];
    AVCapturePhotoSettings *set = [AVCapturePhotoSettings photoSettings];
    [self.imageOutPut capturePhotoWithSettings:set delegate:self];
}

// 图片处理
-(void)handleOriginalImage:(UIImage *)image
{
    UIImage * fixImage;
    //获取当前相机的方向(前还是后) 需完成图片旋转  前置摄像头需处理左右成像问题
    AVCaptureDevicePosition position = [[self.input device] position];
    if (position == AVCaptureDevicePositionBack) {
        fixImage = [self fixOrientation:image isForeCapture:NO deviceGravityType:self.gravityDerectionType];
    }
    else
    {
        fixImage = [self fixOrientation:image isForeCapture:YES deviceGravityType:self.gravityDerectionType];
    }
    //存储
    [[PHPhotoLibrary sharedPhotoLibrary]performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:fixImage];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (error) {
            NSLog(@"%@",@"保存失败");
        } else {
            NSLog(@"%@",@"保存成功");
        }
    }];
}

//根据摄像头类型 重力方向旋转照片
- (UIImage *)fixOrientation:(UIImage *)aImage isForeCapture:(BOOL)isFore deviceGravityType:(PAGravityDirectionType)gravityType
{
    UIImage *img;
    if (!isFore) { //后置摄像头
        if (gravityType == GravityRight) { //后置摄像头 横屏拍摄home键在右边
            CGAffineTransform transform = CGAffineTransformIdentity;
            transform = CGAffineTransformTranslate(transform, 0, 0);
            transform = CGAffineTransformRotate(transform, 0);
            CGContextRef ctx =CGBitmapContextCreate(NULL, aImage.size.height, aImage.size.width,CGImageGetBitsPerComponent(aImage.CGImage),0,CGImageGetColorSpace(aImage.CGImage),CGImageGetBitmapInfo(aImage.CGImage));
            CGContextConcatCTM(ctx, transform);
            CGContextDrawImage(ctx,CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            CGImageRef cgimg =CGBitmapContextCreateImage(ctx);
            img = [UIImage imageWithCGImage:cgimg];
            CGContextRelease(ctx);
            CGImageRelease(cgimg);
        }
        else if (gravityType == GravityLeft) //后置摄像头 横屏拍摄home键在左边
        {
            CGAffineTransform transform = CGAffineTransformIdentity;
            transform = CGAffineTransformTranslate(transform, aImage.size.height, aImage.size.width);
            transform = CGAffineTransformRotate(transform, -M_PI);
            CGContextRef ctx =CGBitmapContextCreate(NULL, aImage.size.height, aImage.size.width,CGImageGetBitsPerComponent(aImage.CGImage),0,CGImageGetColorSpace(aImage.CGImage),CGImageGetBitmapInfo(aImage.CGImage));
            CGContextConcatCTM(ctx, transform);
            CGContextDrawImage(ctx,CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            CGImageRef cgimg =CGBitmapContextCreateImage(ctx);
            img = [UIImage imageWithCGImage:cgimg];
            CGContextRelease(ctx);
            CGImageRelease(cgimg);
        }
        else if (gravityType == GravityUp) //后置摄像头 竖屏拍摄
        {
            CGAffineTransform transform = CGAffineTransformIdentity;
            transform = CGAffineTransformTranslate(transform, 0, aImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            CGContextRef ctx =CGBitmapContextCreate(NULL, aImage.size.width, aImage.size.height,CGImageGetBitsPerComponent(aImage.CGImage),0,CGImageGetColorSpace(aImage.CGImage),CGImageGetBitmapInfo(aImage.CGImage));
            CGContextConcatCTM(ctx, transform);
            CGContextDrawImage(ctx,CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            CGImageRef cgimg =CGBitmapContextCreateImage(ctx);
            img = [UIImage imageWithCGImage:cgimg];
            CGContextRelease(ctx);
            CGImageRelease(cgimg);
        }
        else if (gravityType == GravityDown) //后置摄像头 竖屏倒置拍摄
        {
            CGAffineTransform transform = CGAffineTransformIdentity;
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            CGContextRef ctx =CGBitmapContextCreate(NULL, aImage.size.width, aImage.size.height,CGImageGetBitsPerComponent(aImage.CGImage),0,CGImageGetColorSpace(aImage.CGImage),CGImageGetBitmapInfo(aImage.CGImage));
            CGContextConcatCTM(ctx, transform);
            CGContextDrawImage(ctx,CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            CGImageRef cgimg =CGBitmapContextCreateImage(ctx);
            img = [UIImage imageWithCGImage:cgimg];
            CGContextRelease(ctx);
            CGImageRelease(cgimg);
        }
    }
    else  //前置摄像头
    {
        if (gravityType == GravityRight) //前置摄像头 横屏拍摄home键在右边
        {
            CGAffineTransform transform = CGAffineTransformIdentity;
            transform = CGAffineTransformTranslate(transform, aImage.size.height, aImage.size.width);
            transform = CGAffineTransformRotate(transform, M_PI);
            transform = CGAffineTransformTranslate(transform, aImage.size.height,0);
            transform = CGAffineTransformScale(transform, -1, 1);
            CGContextRef ctx =CGBitmapContextCreate(NULL, aImage.size.height, aImage.size.width,CGImageGetBitsPerComponent(aImage.CGImage),0,CGImageGetColorSpace(aImage.CGImage),CGImageGetBitmapInfo(aImage.CGImage));
            CGContextConcatCTM(ctx, transform);
            CGContextDrawImage(ctx,CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            CGImageRef cgimg =CGBitmapContextCreateImage(ctx);
            img = [UIImage imageWithCGImage:cgimg];
            CGContextRelease(ctx);
            CGImageRelease(cgimg);
        }
        else if (gravityType == GravityLeft) //前置摄像头 横屏拍摄home键在左边
        {
            CGAffineTransform transform = CGAffineTransformIdentity;
            transform = CGAffineTransformTranslate(transform, 0, 0);
            transform = CGAffineTransformRotate(transform, 0);
            transform = CGAffineTransformTranslate(transform, aImage.size.height,0);
            transform = CGAffineTransformScale(transform, -1, 1);
            CGContextRef ctx =CGBitmapContextCreate(NULL, aImage.size.height, aImage.size.width,CGImageGetBitsPerComponent(aImage.CGImage),0,CGImageGetColorSpace(aImage.CGImage),CGImageGetBitmapInfo(aImage.CGImage));
            CGContextConcatCTM(ctx, transform);
            CGContextDrawImage(ctx,CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            CGImageRef cgimg =CGBitmapContextCreateImage(ctx);
            img = [UIImage imageWithCGImage:cgimg];
            CGContextRelease(ctx);
            CGImageRelease(cgimg);
        }
        else if (gravityType == GravityUp) //前置摄像头 竖屏拍摄
        {
            CGAffineTransform transform = CGAffineTransformIdentity;
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            transform = CGAffineTransformTranslate(transform, aImage.size.height,0);
            transform = CGAffineTransformScale(transform, -1, 1);
            CGContextRef ctx =CGBitmapContextCreate(NULL, aImage.size.width, aImage.size.height,CGImageGetBitsPerComponent(aImage.CGImage),0,CGImageGetColorSpace(aImage.CGImage),CGImageGetBitmapInfo(aImage.CGImage));
            CGContextConcatCTM(ctx, transform);
            CGContextDrawImage(ctx,CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            CGImageRef cgimg =CGBitmapContextCreateImage(ctx);
            img = [UIImage imageWithCGImage:cgimg];
            CGContextRelease(ctx);
            CGImageRelease(cgimg);
        }
        else if (gravityType == GravityDown) //前置摄像头 竖屏倒置
        {
            CGAffineTransform transform = CGAffineTransformIdentity;
            transform = CGAffineTransformTranslate(transform, 0, aImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            transform = CGAffineTransformTranslate(transform, aImage.size.height,0);
            transform = CGAffineTransformScale(transform, -1, 1);
            CGContextRef ctx =CGBitmapContextCreate(NULL, aImage.size.width, aImage.size.height,CGImageGetBitsPerComponent(aImage.CGImage),0,CGImageGetColorSpace(aImage.CGImage),CGImageGetBitmapInfo(aImage.CGImage));
            CGContextConcatCTM(ctx, transform);
            CGContextDrawImage(ctx,CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            CGImageRef cgimg =CGBitmapContextCreateImage(ctx);
            img = [UIImage imageWithCGImage:cgimg];
            CGContextRelease(ctx);
            CGImageRelease(cgimg);
        }
    }
    return img;
}

//开始监测重力感应
- (void)startUpdateAccelerometerResult{
    if ([self.motionManager isAccelerometerAvailable] == YES) {
        [self.motionManager setAccelerometerUpdateInterval:0.06];
        __weak __typeof(&*self)weakSelf = self;
        [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMAccelerometerData *accelerometerData, NSError *error)
         {
             double x = accelerometerData.acceleration.x;
             double y = accelerometerData.acceleration.y;
             if (fabs(y) >= fabs(x))
             {
                 if (y >= 0){
                     //Down
//                     NSLog(@"Down");
                     weakSelf.gravityDerectionType = GravityDown;
                 }
                 else{
                     //Portrait
//                     NSLog(@"Portrait");
                     weakSelf.gravityDerectionType = GravityUp;
                 }
             }
             else
             {
                 if (x >= 0){
                     //Right
//                     NSLog(@"Right");
                     weakSelf.gravityDerectionType = GravityLeft; //Home键在左
                 }
                 else{
                     //Left
//                     NSLog(@"Left");
                     weakSelf.gravityDerectionType = GravityRight; //Home键在右
                 }
             }
         }];
    }
}

//停止重力感应
- (void)stopUpdate
{
    if ([self.motionManager isAccelerometerActive] == YES)
    {
        [self.motionManager stopAccelerometerUpdates];
    }
}

//图片写入定位信息等
-(void)setGPSToImageByLat:(double)lat lon:(double)longi image:(UIImage *)image {
    NSData *data = UIImageJPEGRepresentation(image,0.7);
    if(!data || [data length] == 0)
    {
        return;
    }
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    NSDictionary *dict = (__bridge NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    
    NSMutableDictionary *metaDataDic = [dict mutableCopy];
    
    //GPS
    NSMutableDictionary *gpsDic =[NSMutableDictionary dictionary];
    //[gpsDic setObject:@"N"forKey:(NSString*)kCGImagePropertyGPSLatitudeRef];
    [gpsDic setObject:[NSNumber numberWithDouble:lat] forKey:(NSString*)kCGImagePropertyGPSLatitude];
    //[gpsDic setObject:@"E"forKey:(NSString*)kCGImagePropertyGPSLongitudeRef];
    [gpsDic setObject:[NSNumber numberWithDouble:longi] forKey:(NSString *)kCGImagePropertyGPSLongitude];
    
    [metaDataDic setObject:gpsDic forKey:(NSString*)kCGImagePropertyGPSDictionary];
    
    //其他exif信息
    NSMutableDictionary *exifDic =[[metaDataDic objectForKey:(NSString*)kCGImagePropertyTIFFDictionary]mutableCopy];
    if(!exifDic)
    {
        exifDic = [NSMutableDictionary dictionary];
    }
    [exifDic setObject:[NSString stringWithFormat:@"eApp%lf,%lfGD",lat,longi] forKey:(NSString*)kCGImagePropertyTIFFMake];

    [metaDataDic setObject:exifDic forKey:(NSString*)kCGImagePropertyTIFFDictionary];
    
    //写进图片
    CFStringRef UTI = CGImageSourceGetType(source);
    NSMutableData *data1 = [NSMutableData data];
    CGImageDestinationRef destination =CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data1, UTI, 1,NULL);
    if(!destination)
    {
        return;
    }
    
    CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef)metaDataDic);
    if(!CGImageDestinationFinalize(destination))
    {
        return;
    }
    
    // 需要将data直接写入到文件夹或相册，转换为图片再存入会丢失附加信息
}

//压缩照片 上传照片大小限制
+(UIImage *)compressWithImage:(UIImage *)image  maxLength:(NSInteger)maxLength
{
    if (!image) {
        return image;
    }
    
    NSInteger length = ((NSData *)UIImageJPEGRepresentation(image, 0.7)).length;
    
    NSLog(@"上传照片大小限制---图片原始大小：%ld",length);
    
    float pressValue = 0.2;
    float scale = 1.5;
    
    if (length > maxLength*5.0) {
        pressValue = 0.05;
        scale = 2;
    }
    
    UIImage *newImage;
    
    if (length < maxLength) {
        return image;
    }
    
    newImage = [UIImage imageWithData:UIImageJPEGRepresentation(image, pressValue)];
    
    NSInteger newLength = ((NSData *)UIImageJPEGRepresentation(newImage, 0.7)).length;
    
    //压缩图片质量 确保压缩到maxLength以内
    for (int i = 0; i < 3; i++) {
        
        if (newLength < maxLength) {
            break;
        }
        
        if (pressValue < 0.05) {
            break;
        }
        
        pressValue /= 2;
        newImage = [UIImage imageWithData:UIImageJPEGRepresentation(image, pressValue)];
        newLength = ((NSData *)UIImageJPEGRepresentation(newImage, 0.7)).length;
    }
    
    //如果仍大于500k 且无法继续压缩图片质量 进行尺寸压缩
    for (int i = 0; i < 5; i++) {
        
        if (newLength < maxLength) {
            break;
        }
        
        CGSize size = CGSizeMake(newImage.size.width/scale, newImage.size.height/scale);
        UIGraphicsBeginImageContext(size);
        [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
        newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        newLength = ((NSData *)UIImageJPEGRepresentation(newImage, 0.7)).length;
    }
    
    NSLog(@"上传照片大小限制---压缩完图片大小：%ld",newLength);
    
    return newImage;
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

- (CMMotionManager *)motionManager
{
    if (!_motionManager) {
        _motionManager = [[CMMotionManager alloc] init];
    }
    return _motionManager;
}

#pragma mark - 代理方法
// 将屏幕坐标系的点转换为previewLayer坐标系的点
- (CGPoint)captureDevicePointForPoint:(CGPoint)point {
    return [self.previewLayer captureDevicePointOfInterestForPoint:point];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    
}

-(void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    if (!error) {
        NSData *imageData = [photo fileDataRepresentation];
        UIImage *image = [UIImage imageWithData:imageData];
        //处理图片
        [self handleOriginalImage:image];
    }
}



@end
