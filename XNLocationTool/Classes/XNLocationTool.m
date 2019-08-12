//
//  XNLocationTool.m
//  XNLocationTool_Example
//
//  Created by Luigi on 2019/7/8.
//  Copyright © 2019 yexiannan. All rights reserved.
//

#import "XNLocationTool.h"
#import <CoreLocation/CoreLocation.h>
#import "FMDB.h"

typedef void(^LocationResult)(double longitude, double latitude, NSString *provinceName, NSString * _Nullable provinceID, NSString * _Nullable cityName, NSString * _Nullable cityID, NSString * _Nullable areaName, NSString * _Nullable  areaID);

typedef void(^LocationError)(NSError *error);

@interface XNLocationTool ()<CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager* locationManager;
@property (nonatomic, copy) LocationResult result;
@property (nonatomic, copy) LocationError error;
@property (nonatomic, strong) FMDatabase *db;
@property (nonatomic, strong) NSOperationQueue *inquireLocationQueue;
@end

@implementation XNLocationTool
+ (XNLocationTool *)locationManager{
    static dispatch_once_t oncetoken;
    static XNLocationTool *shareInstance;
    dispatch_once(&oncetoken, ^{
        shareInstance = [[self alloc] init];
        shareInstance.locationManager = [[CLLocationManager alloc] init];
        
        //创建数据库查询队列，并设置最大并发数为1使之串行执行
        shareInstance.inquireLocationQueue = [[NSOperationQueue alloc] init];
        shareInstance.inquireLocationQueue.maxConcurrentOperationCount = 1;
        
        //设置数据库操作者
        //pod加载资源方式有所不同 如直接添加至项目请修改此加载资源方式
        NSString *bundlePath = [[NSBundle bundleForClass:[self class]].resourcePath
                                stringByAppendingPathComponent:@"/XNLocationTool.bundle"];
        NSBundle *resource_bundle = [NSBundle bundleWithPath:bundlePath];
        NSString *dbFilePath = [resource_bundle pathForResource:@"lianlianche" ofType:@"db"];

        shareInstance.db = [FMDatabase databaseWithPath:dbFilePath];
    });
    return shareInstance;
}

- (void)initWithLongitude:(double)longitude Latitude:(double)latitude ProvinceName:(nonnull NSString *)provinceName ProvinceID:(nonnull NSString *)provinceID CityName:(nonnull NSString *)cityName CityID:(nonnull NSString *)cityID AreaName:(nonnull NSString *)areaName AreaID:(nonnull NSString *)areaID{
    self.longitude = longitude;
    self.latitude = latitude;
    self.provinceName = provinceName;
    self.provinceID = provinceID;
    self.cityName = cityName;
    self.cityID = cityID;
    self.areaName = areaName;
    self.areaID = areaID;
}

#pragma mark - 定位
+ (void)getLocationResult:(void (^)(double, double, NSString * _Nonnull, NSString * _Nullable, NSString * _Nullable, NSString * _Nullable, NSString * _Nullable, NSString * _Nullable))result Error:(void (^)(NSError * _Nonnull))error{
    XNLocationTool *tool = [XNLocationTool locationManager];
    tool.result = result;
    tool.error = error;
    tool.locationManager.delegate = tool;
    
    if ([tool.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [tool.locationManager requestWhenInUseAuthorization];
    }
    
    [tool.locationManager startUpdatingLocation];
    
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations{
    
    [self.locationManager stopUpdatingLocation];
    //将代理置空,解决触发2次代理问题
    self.locationManager.delegate = nil;
    
    CLLocation *location = [locations lastObject];
    CLLocationCoordinate2D coordinate = location.coordinate;
    
    //根据经纬度反向地理编译出地址信息
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
        
        if (error) {
            self.error(error);
            return ;
        }
        
        CLPlacemark *placemark = [placemarks firstObject];
        
        //针对数据库信息作处理以方便筛选
        NSString *provinceName = [placemark.administrativeArea stringByReplacingOccurrencesOfString:@"省" withString:@""];
        NSString *cityName = [placemark.locality stringByReplacingOccurrencesOfString:@"市" withString:@""];
        NSString *areaName = placemark.subLocality;

        //获取省市区ID
        [XNLocationTool inquireIDWithName:provinceName TableName:@"city" Result:^(NSString * _Nullable ID) {
            NSString *provinceID = ID;
            [XNLocationTool inquireIDWithName:cityName TableName:@"city" Result:^(NSString * _Nullable ID) {
                NSString *cityID = ID;
                [XNLocationTool inquireIDWithName:areaName TableName:@"city_zone" Result:^(NSString * _Nullable ID) {
                    NSString *areaID = ID;
                    
                    self.result(coordinate.longitude, coordinate.latitude, provinceName, provinceID, cityName, cityID, areaName, areaID);
                    
                }];
            }];
        }];

    }];
 
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
    self.error(error);
}

#pragma mark - 数据库查询操作
/**
 * 根据名称查询ID
 */
+ (void)inquireIDWithName:(NSString *)name TableName:(NSString *)tableName Result:(void (^)(NSString * _Nullable))result{
    NSBlockOperation *inquireID = [NSBlockOperation blockOperationWithBlock:^{
        FMDatabase *db = [XNLocationTool locationManager].db;
        [db open];
        if (![db open]) {
            result(nil);
        }

        NSString *cityID;

        
        
        
        if ([tableName isEqualToString:@"city"]) {
            
            FMResultSet *dbResult = [db executeQuery:[NSString stringWithFormat:@"select * from 'city' WHERE city_name LIKE '%@'",name]];

            while ([dbResult next]) {
                cityID = [NSString stringWithFormat:@"%d",[dbResult intForColumn:@"city_id"]];
            }
            
        } else {
            
            FMResultSet *dbResult = [db executeQuery:[NSString stringWithFormat:@"select * from 'city_zone' WHERE name LIKE '%@%%'",name]];
            
            while ([dbResult next]) {
                cityID = [NSString stringWithFormat:@"%d",[dbResult intForColumn:@"id"]];
            }
            
        }
        
        
        result(cityID);

    }];

    [[XNLocationTool locationManager].inquireLocationQueue addOperation:inquireID];
}

/**
 * 根据ID查询Name
 */
+ (void)inquireNameWithID:(NSString *)ID TableName:(NSString *)tableName Result:(void (^)(NSString * _Nullable Name))result{
    NSBlockOperation *inquireName = [NSBlockOperation blockOperationWithBlock:^{
        FMDatabase *db = [XNLocationTool locationManager].db;
        [db open];
        if (![db open]) {
            result(nil);
        }
        
        NSString *cityName;
        
        if ([tableName isEqualToString:@"city"]) {
            
            FMResultSet *dbResult = [db executeQuery:[NSString stringWithFormat:@"select * from 'city' WHERE city_id LIKE '%@'",ID]];
            
            while ([dbResult next]) {
                cityName = [NSString stringWithFormat:@"%d",[dbResult intForColumn:@"city_name"]];
            }
            
        } else {
            
            FMResultSet *dbResult = [db executeQuery:[NSString stringWithFormat:@"select * from 'city_zone' WHERE id LIKE '%@'",ID]];
            
            while ([dbResult next]) {
                cityName = [NSString stringWithFormat:@"%d",[dbResult intForColumn:@"city_name"]];
            }
            
        }
        
        
        result(cityName);
        
    }];
    
    [[XNLocationTool locationManager].inquireLocationQueue addOperation:inquireName];
}

/**
 * 根据市ID查询市下所有的区
 * @[@{@"ID":@"350211",@"Name":@"集美区"}]
 */
+ (void)inquireAllAreaInfoWithCityID:(NSString *)cityID Result:(nonnull void (^)(NSArray<NSDictionary<NSString *,NSString *> *> * _Nullable))result {
    NSBlockOperation *inquireAllAreaInfo = [NSBlockOperation blockOperationWithBlock:^{
        FMDatabase *db = [XNLocationTool locationManager].db;
        [db open];
        if (![db open]) {
            result(nil);
        }
        
        //1.根据cityID查询StandardCode
        NSString *cityStandardCode;
        FMResultSet *dbResult = [db executeQuery:[NSString stringWithFormat:@"select * from 'city' WHERE city_id = '%@'",cityID]];
        while ([dbResult next]) {
            cityStandardCode = [NSString stringWithFormat:@"%lld",[dbResult longLongIntForColumn:@"standard_code"]];
        }
        
        
        //2.根据市StandardCode查询辖区信息
        dbResult = [db executeQuery:[NSString stringWithFormat:@"select * from 'city_zone' WHERE pid = '%@' ORDER BY id ASC",cityStandardCode]];
        
        NSMutableArray <NSDictionary<NSString *,NSString *> *>*areaInfosArray = [[NSMutableArray alloc] initWithCapacity:[dbResult columnCount]];
        
        while ([dbResult next]) {
            NSDictionary *areaInfo = @{@"ID":[dbResult stringForColumn:@"id"],
                                       @"Name":[dbResult stringForColumn:@"name"]};
            [areaInfosArray addObject:areaInfo];
        }
        
        result(areaInfosArray);
        
    }];
    
    [[XNLocationTool locationManager].inquireLocationQueue addOperation:inquireAllAreaInfo];
}

/**
 * 根据省ID查询辖区下所有市
 * @[@{@"ID":@"10086",@"Name":@"福建"}]
 */
+ (void)inquireAllCityInfoWithProvinceID:(NSString *)provinceID Result:(nonnull void (^)(NSArray<NSDictionary<NSString *,NSString *> *> * _Nullable))result {
    NSBlockOperation *inquireAllCityInfo = [NSBlockOperation blockOperationWithBlock:^{
        FMDatabase *db = [XNLocationTool locationManager].db;
        [db open];
        if (![db open]) {
            result(nil);
        }
        
        FMResultSet *dbResult = [db executeQuery:[NSString stringWithFormat:@"select * from 'city' WHERE parent_id = '%@' ORDER BY city_id ASC",provinceID]];
        NSMutableArray <NSDictionary<NSString *,NSString *> *>*cityInfosArray = [[NSMutableArray alloc] initWithCapacity:[dbResult columnCount]];

        while ([dbResult next]) {
            NSDictionary *cityInfo = @{@"ID":[dbResult stringForColumn:@"city_id"],
                                       @"Name":[dbResult stringForColumn:@"city_name"]};
            [cityInfosArray addObject:cityInfo];
        }
        
        result(cityInfosArray);
        
    }];
    
    [[XNLocationTool locationManager].inquireLocationQueue addOperation:inquireAllCityInfo];
}


/**
 * 获取所有的省
 */
+ (void)inquireAllProvinceInfoResult:(void (^)(NSArray<NSDictionary<NSString *,NSString *> *> * _Nullable))result{
    NSBlockOperation *inquireAllProvinceInfo = [NSBlockOperation blockOperationWithBlock:^{
        FMDatabase *db = [XNLocationTool locationManager].db;
        [db open];
        if (![db open]) {
            result(nil);
        }
        
        FMResultSet *dbResult = [db executeQuery:[NSString stringWithFormat:@"select * from 'city' WHERE city_type = 1 ORDER BY city_id ASC"]];
        NSMutableArray <NSDictionary<NSString *,NSString *> *>*provinceInfosArray = [[NSMutableArray alloc] initWithCapacity:[dbResult columnCount]];
        
        while ([dbResult next]) {
            NSDictionary *cityInfo = @{@"ID":[dbResult stringForColumn:@"city_id"],
                                       @"Name":[dbResult stringForColumn:@"city_name"]};
            [provinceInfosArray addObject:cityInfo];
        }
        
        result(provinceInfosArray);
        
    }];
    
    [[XNLocationTool locationManager].inquireLocationQueue addOperation:inquireAllProvinceInfo];
}

@end
