//
//  AlbumCollectionViewCell.m
//  CustomCameraDemo
//
//  Created by ywb on 2021/11/28.
//

#import "AlbumCollectionViewCell.h"
#import "Masonry.h"

@interface AlbumCollectionViewCell ()
@property(strong,nonatomic)UIImageView *imageView;
@end

@implementation AlbumCollectionViewCell

-(instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self createUI];
    }
    return self;
}

-(void)createUI {
    self.backgroundColor = [UIColor whiteColor];
    [self.contentView addSubview:self.imageView];
    [self.imageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.contentView).offset(1);
    }];
}

-(void)setModel:(AlbumPhotoAssetModel *)model {
    _model = model;
    __weak __typeof(&*self)weakSelf = self;
    [self accessToImageAccordingToTheAsset:model.asset size:CGSizeMake(250.0, 250.0*model.asset.pixelHeight/model.asset.pixelWidth) resizeMode:PHImageRequestOptionsResizeModeExact completion:^(UIImage *image, NSDictionary *info) {
        @autoreleasepool {
            if (weakSelf.model == model) { //如果异步加载完cell未复用重载数据模型
                weakSelf.imageView.image = [weakSelf fitImage:image scaledToFillSize:CGSizeMake(CGRectGetWidth(weakSelf.frame), CGRectGetHeight(weakSelf.frame))];
            }
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

- (UIImage *)fitImage:(UIImage *)image scaledToFillSize:(CGSize)size {
    @autoreleasepool {
        UIGraphicsBeginImageContext(CGSizeMake(size.width, size.width * image.size.height/image.size.width));
        [image drawInRect:CGRectMake(0, 0,size.width , size.width * image.size.height/image.size.width)];
        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return newImage;
    }
}

-(UIImageView *)imageView{
    if (_imageView == nil) {
        _imageView = [[UIImageView alloc] init];
    }
    return  _imageView;
}

@end
