//
//  CheckVideoViewController.m
//  CustomCameraDemo
//
//  Created by yanwenbin on 2021/12/2.
//

#import "CheckVideoViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "CameraHelper.h"

@interface CheckVideoViewController ()
@property (nonatomic ,strong) AVPlayer *player;
@property (nonatomic ,strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) UIButton *cancelBtn;
@end

@implementation CheckVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self loadUI];
    [self loadPlayer];
    
    // Do any additional setup after loading the view.
}

-(void)dealloc {
    NSLog(@"CheckVideoViewController dealloc");
}

- (void)loadUI {
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    CGFloat statusBarHeight = [CameraHelper getStatusBarHeight];
    self.cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.cancelBtn.frame = CGRectMake(statusBarHeight, 10, 28, 28);
    [self.cancelBtn setImage:[UIImage imageNamed:@"xiangjifanhiu"] forState:UIControlStateNormal];
    [self.cancelBtn addTarget:self action:@selector(dismissVC) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.cancelBtn];
}

- (void)loadPlayer {
    if (self.playerLayer) {
        [self.playerLayer removeFromSuperlayer];
        self.player = nil;
        self.playerLayer = nil;
    }

    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:[AVAsset assetWithURL:self.preVideoURL]];
    self.player = [[AVPlayer alloc]initWithPlayerItem:playerItem];

    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.playerLayer.frame = self.view.frame;

    [self.view.layer insertSublayer:self.playerLayer atIndex:0];
    [self.player play];
}

- (void)dismissVC {
    [self.player pause];
    [self.navigationController popViewControllerAnimated:YES];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
