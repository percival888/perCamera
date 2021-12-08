//
//  CheckPhotoViewController.m
//  CustomCameraDemo
//
//  Created by ywb on 2021/11/28.
//

#import "CheckPhotoViewController.h"

@interface CheckPhotoViewController ()
@property(strong,nonatomic) UIImageView *photoImageView;
@end

@implementation CheckPhotoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    [self createUI];
    [self loadImage];
    // Do any additional setup after loading the view.
}

-(void)createUI {
    [self.view addSubview:self.photoImageView];
}

-(void)loadImage {
    __weak __typeof(&*self)weakSelf = self;
    [self accessToImageAccordingToTheAsset:self.model.asset size:CGSizeMake(self.model.asset.pixelWidth, self.model.asset.pixelHeight) resizeMode:PHImageRequestOptionsResizeModeExact completion:^(UIImage *image, NSDictionary *info) {
        @autoreleasepool {
            weakSelf.photoImageView.image = image;
        }
    }];
}

// 根据PHAsset获取图片信息
- (void)accessToImageAccordingToTheAsset:(PHAsset *)asset size:(CGSize)size resizeMode:(PHImageRequestOptionsResizeMode)resizeMode completion:(void(^)(UIImage *image,NSDictionary *info))completion
{
    static PHImageRequestID requestID = -2;
    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat width = MIN([UIScreen mainScreen].bounds.size.width, 500);
    if (requestID >= 1 && size.width / width == scale) {
        [[PHCachingImageManager defaultManager] cancelImageRequest:requestID];
    }
    PHImageRequestOptions *option = [[PHImageRequestOptions alloc] init];
    option.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    //    option.resizeMode = PHImageRequestOptionsResizeModeFast;
    option.resizeMode = resizeMode;
    requestID = [[PHCachingImageManager defaultManager] requestImageForAsset:asset targetSize:size contentMode:PHImageContentModeAspectFill options:option resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(result,info);
        });
    }];
    
}

-(UIImageView *)photoImageView {
    if (_photoImageView == nil) {
        _photoImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
        _photoImageView.image = [UIImage imageNamed:@"placeHolder"];
        _photoImageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _photoImageView;
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
