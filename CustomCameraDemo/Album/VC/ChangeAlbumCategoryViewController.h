//
//  ChangeAlbumCategoryViewController.h
//  CustomCameraDemo
//
//  Created by ywb on 2021/11/28.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ChangeAlbumCategoryViewController : UIViewController
@property (nonatomic, strong) NSMutableArray *albumCategoryArr; //相册分类数组
@property (nonatomic, copy) void(^changeCategoryBlock)(NSInteger index); //修改分类回调
@end

NS_ASSUME_NONNULL_END
