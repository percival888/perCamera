//
//  RecordProgressView.h
//  CustomCameraDemo
//
//  Created by yanwenbin on 2021/11/30.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface RecordProgressView : UIView
- (instancetype)initWithFrame:(CGRect)frame;
-(void)updateProgressWithValue:(CGFloat)progress;
-(void)resetProgress;
@end

NS_ASSUME_NONNULL_END
