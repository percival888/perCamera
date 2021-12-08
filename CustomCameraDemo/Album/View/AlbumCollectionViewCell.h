//
//  AlbumCollectionViewCell.h
//  CustomCameraDemo
//
//  Created by ywb on 2021/11/28.
//

#import <UIKit/UIKit.h>
#import "AlbumPhotoAssetModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface AlbumCollectionViewCell : UICollectionViewCell
@property(strong,nonatomic) AlbumPhotoAssetModel *model;
@end

NS_ASSUME_NONNULL_END
