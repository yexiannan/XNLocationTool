//
//  XNLocationTool.h
//  XNLocationTool_Example
//
//  Created by Luigi on 2019/7/8.
//  Copyright © 2019 yexiannan. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface XNLocationTool : NSObject
+ (XNLocationTool *)locationManager;

/**
 * 获取当前位置信息
 */
+ (void)getLocationResult:(void (^)(double longitude, double latitude, NSString *provinceName, NSString * _Nullable provinceID, NSString * _Nullable cityName, NSString * _Nullable cityID, NSString * _Nullable areaName, NSString * _Nullable  areaID))result Error:(void (^)(NSError *error))error;

/**
 * 根据Name查询ID
 */
+ (void)inquireIDWithName:(NSString *)name Result:(void (^)(NSString * _Nullable ID))result;
/**
 * 根据ID查询Name
 */
+ (void)inquireNameWithID:(NSString *)ID Result:(void (^)(NSString * _Nullable Name))result;

/**
 * 根据省ID查询辖区下所有市
 * @[@{@"ID":@"10086",@"Name":@"福建"}]
 */
+ (void)inquireAllCityInfoWithID:(NSString *)ID Result:(void (^)(NSArray <NSDictionary <NSString *,NSString *>*>* _Nullable resultInfos))result;

@end

NS_ASSUME_NONNULL_END
