//
//  PAWGS84TOGCJ02.h
//  平安E手持
//
//  Created by 黄秋伟(EX-HUANGQIUWEI001) on 2019/2/18.
//  Copyright © 2019年 唐飞. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PAWGS84TOGCJ02 : NSObject

//判断是否已经超出中国范围
+(BOOL)isLocationOutOfChina:(CLLocationCoordinate2D)location;
//转GCJ-02
+(CLLocationCoordinate2D)transformFromWGSToGCJ:(CLLocationCoordinate2D)wgsLoc;



@end

NS_ASSUME_NONNULL_END
