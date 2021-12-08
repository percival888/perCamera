//
//  CameraHelper.m
//  CustomCameraDemo
//
//  Created by ywb on 2021/11/27.
//

#import <UIKit/UIKit.h>
#import "CameraHelper.h"

@implementation CameraHelper
+(BOOL)isIphonex {
    if (@available(iOS 11.0, *)) {
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (window.safeAreaInsets.bottom > 0) {
            return YES;
        } else {
            return NO;
        }
    } else {
        return NO;
    }
}

+(CGFloat)getStatusBarHeight {
    if ([self isIphonex]) {
        return 44.0;
    }
    return 20;
}
@end
