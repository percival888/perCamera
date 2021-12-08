//
//  AlbumViewController.m
//  CustomCameraDemo
//
//  Created by ywb on 2021/11/27.
//

#import "AlbumViewController.h"
#import "AlbumCollectionViewCell.h"
#import "ChangeAlbumCategoryViewController.h"
#import "CheckPhotoViewController.h"
#import <AVKit/AVKit.h>

#define PhotoCellIdentifier @"photoCell"

@interface AlbumViewController ()<UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property(strong,nonatomic)UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray *albumDataArr;  //图片数据
@property (nonatomic, strong) NSMutableArray *albumCategoryArr; //相册分类数组
@property (nonatomic, strong) NSMutableArray *currentSelectAlbumDataArr; //选中分类下的相册数据
@end

@implementation AlbumViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self createUI];
    if ([self checkAlbumPermission]) {
        [self loadPhotoData];
    }
}

#pragma mark - UI
-(void)createUI {
    [self.view addSubview:self.collectionView];
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithTitle:@"修改相册分类" style:UIBarButtonItemStylePlain target:self action:@selector(changeAlbumCategory)];
    self.navigationItem.rightBarButtonItem = rightItem;
}

#pragma mark - 加载数据
//获取数据
-(void)loadPhotoData {
    [self getAlbumData];
    [self.collectionView reloadData];
}

//获取相册数据
-(void)getAlbumData {
    [self.albumCategoryArr removeAllObjects];
    [self.albumDataArr removeAllObjects];
    __weak __typeof(&*self)weakSelf = self;
    NSMutableArray *arr = [NSMutableArray array];
    // 所有智能相册  经由相机得来的相册
    PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    for (NSInteger i = 0; i < smartAlbums.count; i++) {
        PHCollection *collection = smartAlbums[i];
        NSLog(@"第一次相册分类，智能相册----%@",collection.localizedTitle);
        //遍历获取相册
        if ([collection isKindOfClass:[PHAssetCollection class]]) {
            PHAssetCollection *assetCollection = (PHAssetCollection *)collection;
            PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:nil];
            NSArray *assets;
            if (fetchResult.count > 0) {
                // 某个相册里面的所有PHAsset对象
                assets = [weakSelf getAllPhotosAssetInAblumCollection:assetCollection ascending:NO];
                if (assets.count > 0 && collection.localizedTitle && ![collection.localizedTitle isEqualToString:@"最近删除"] && ![collection.localizedTitle isEqualToString:@"最近添加"]) {
                    [arr addObject:assets];
                    NSLog(@"筛选出有图片或视频的相册分类----%@----%ld",collection.localizedTitle,assets.count);
                    [self.albumCategoryArr addObject:collection.localizedTitle];
                }
            }
        }
    }
    // 相册  包含从iTunes 同步来的相册，以及用户在 Photos 中自己建立的相册
    PHFetchResult *customAlbums = [PHAssetCollection fetchAssetCollectionsWithType: PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    for (NSInteger i = 0; i < customAlbums.count; i++) {
        PHCollection *collection = customAlbums[i];
        NSLog(@"第一次相册分类，itunes或自定义----%@",collection.localizedTitle);
        //遍历获取相册
        if ([collection isKindOfClass:[PHAssetCollection class]]) {
            PHAssetCollection *assetCollection = (PHAssetCollection *)collection;
            PHFetchResult *fetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:nil];
            NSArray *assets;
            if (fetchResult.count > 0) {
                // 某个相册里面的所有PHAsset对象
                assets = [weakSelf getAllPhotosAssetInAblumCollection:assetCollection ascending:NO];
                if (assets.count > 0 && collection.localizedTitle && ![collection.localizedTitle isEqualToString:@"最近删除"] && ![collection.localizedTitle isEqualToString:@"最近添加"]) {
                    [arr addObject:assets];
                    NSLog(@"筛选出有图片或视频的相册分类----%@----%ld",collection.localizedTitle,assets.count);
                    [self.albumCategoryArr addObject:collection.localizedTitle];
                }
            }
        }
    }
    for (NSArray *subleArr in arr) {
        NSMutableArray <AlbumPhotoAssetModel *>*dataSubArr = [NSMutableArray array];
        for (NSInteger i = subleArr.count - 1;i >= 0 ;i--) {
            AlbumPhotoAssetModel *albumModel = [[AlbumPhotoAssetModel alloc] init];
            PHAsset *asset = subleArr[i];
            albumModel.asset = asset;
            [dataSubArr addObject:albumModel];
        }
        [self.albumDataArr addObject:dataSubArr];
    }
    if (self.albumDataArr.count > 0) {
        self.currentSelectAlbumDataArr = self.albumDataArr.firstObject;
        if (self.albumCategoryArr.count > 0) {
            self.title = self.albumCategoryArr.firstObject;
        }
    }
}

// 获取相册里的所有图片的PHAsset对象
- (NSArray *)getAllPhotosAssetInAblumCollection:(PHAssetCollection *)assetCollection ascending:(BOOL)ascending
{
    // 存放所有图片对象
    NSMutableArray *assets = [NSMutableArray array];
    // 是否按创建时间排序
    PHFetchOptions *option = [[PHFetchOptions alloc] init];
    option.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:ascending]];
//    NSPredicate *media = [NSPredicate predicateWithFormat:@"mediaType == %ld", PHAssetMediaTypeImage];
//    NSCompoundPredicate *compoundPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[media]];
//    option.predicate = compoundPredicate;
    // 获取所有图片对象
    PHFetchResult *result = [PHAsset fetchAssetsInAssetCollection:assetCollection options:option];
    // 遍历
    [result enumerateObjectsUsingBlock:^(PHAsset *asset, NSUInteger idx, BOOL * _Nonnull stop) {
        [assets addObject:asset];
    }];
    return assets;
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

#pragma mark - 相册权限
- (BOOL)checkAlbumPermission
{
    PHAuthorizationStatus authStatus = [PHPhotoLibrary authorizationStatus];
    if (authStatus == PHAuthorizationStatusRestricted || authStatus == PHAuthorizationStatusDenied) {
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"请打开相册权限" message:@"设置-隐私-照片" preferredStyle:UIAlertControllerStyleAlert];
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
    } else if (authStatus == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus selectStatus) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                if (selectStatus == PHAuthorizationStatusAuthorized) {
                    [self loadPhotoData];
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

#pragma mark - IBAction
-(void)changeAlbumCategory {
    ChangeAlbumCategoryViewController *changeCategoryVC = [[ChangeAlbumCategoryViewController alloc] init];
    changeCategoryVC.albumCategoryArr = self.albumCategoryArr;
    __weak __typeof(&*self)weakSelf = self;
    changeCategoryVC.changeCategoryBlock = ^(NSInteger index) {
        if (weakSelf.albumDataArr.count > index) {
            weakSelf.currentSelectAlbumDataArr = weakSelf.albumDataArr[index];
            [weakSelf.collectionView reloadData];
        }
        if (weakSelf.albumCategoryArr.count > index) {
            weakSelf.title = weakSelf.albumCategoryArr[index];
        }
    };
    [self.navigationController pushViewController:changeCategoryVC animated:YES];
}

#pragma mark - 方法
// 返回
-(void)dismiss {
    [self.navigationController popViewControllerAnimated:YES];
}

// 查看图片
-(void)checkPhoto: (AlbumPhotoAssetModel *)model {
    CheckPhotoViewController *checkPhotoVC = [[CheckPhotoViewController alloc] init];
    checkPhotoVC.model = model;
    [self.navigationController pushViewController:checkPhotoVC animated:YES];
}

// 播放视频
-(void)playVideoWithAsset:(PHAsset *)asset {
    PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
    options.version = PHImageRequestOptionsVersionCurrent;
    options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
    
    PHImageManager *manager = [PHImageManager defaultManager];
    [manager requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
        AVURLAsset *urlAsset = (AVURLAsset *)asset;
        
        NSURL *url = urlAsset.URL;
        dispatch_async(dispatch_get_main_queue(), ^{
            AVPlayerViewController *avPlayerVC = [[AVPlayerViewController alloc] init];
            avPlayerVC.view.frame = self.view.frame;
            avPlayerVC.showsPlaybackControls = YES;
            avPlayerVC.player = [AVPlayer playerWithURL:url];
            [self presentViewController:avPlayerVC animated:YES completion:^{
                [avPlayerVC.player play];
            }];
        });
    }];
}

#pragma mark - 懒加载
-(UICollectionView *)collectionView {
    if (_collectionView == nil) {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        _collectionView = [[UICollectionView alloc] initWithFrame:self.view.frame collectionViewLayout:layout];
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        _collectionView.backgroundColor = [UIColor clearColor];
        [_collectionView registerClass:[AlbumCollectionViewCell class] forCellWithReuseIdentifier:PhotoCellIdentifier];
    }
    return _collectionView;
}

-(NSMutableArray *)albumDataArr {
    if (_albumDataArr == nil) {
        _albumDataArr = [NSMutableArray array];
    }
    return _albumDataArr;
}

-(NSMutableArray *)albumCategoryArr {
    if (_albumCategoryArr == nil) {
        _albumCategoryArr = [NSMutableArray array];
    }
    return _albumCategoryArr;
}

-(NSMutableArray *)currentSelectAlbumDataArr {
    if (_currentSelectAlbumDataArr == nil) {
        _currentSelectAlbumDataArr = [NSMutableArray array];
    }
    return _currentSelectAlbumDataArr;
}

#pragma mark - 代理方法
-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.currentSelectAlbumDataArr.count;
}

-(__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    AlbumCollectionViewCell *cell = (AlbumCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:PhotoCellIdentifier forIndexPath:indexPath];
    AlbumPhotoAssetModel *model = self.currentSelectAlbumDataArr[indexPath.row];
    cell.model = model;
    return cell;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat width = self.view.frame.size.width/5;
    return CGSizeMake(width, width);
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    AlbumPhotoAssetModel *model = self.currentSelectAlbumDataArr[indexPath.row];
    PHAsset *asset = model.asset;
    if (asset.mediaType == PHAssetMediaTypeImage) {
        [self checkPhoto:model];
    } else if (asset.mediaType == PHAssetMediaTypeVideo) {
        [self playVideoWithAsset:asset];
    }
}

@end
