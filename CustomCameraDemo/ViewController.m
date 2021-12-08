//
//  ViewController.m
//  CustomCameraDemo
//
//  Created by ywb on 2021/11/21.
//

#import "ViewController.h"
#import "CameraViewController.h"
#import "AlbumViewController.h"
#import "VideoViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (IBAction)jumpToCamera:(UIButton *)sender {
    CameraViewController *cameraVC = [[CameraViewController alloc] init];
    [self.navigationController pushViewController:cameraVC animated:YES];
}

- (IBAction)videoRecord:(UIButton *)sender {
    VideoViewController *vc = [[VideoViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)jumpToAlbum:(UIButton *)sender {
    AlbumViewController *albumVC = [[AlbumViewController alloc] init];
    [self.navigationController pushViewController:albumVC animated:YES];
}

@end
