//
//  XNViewController.m
//  XNLocationTool
//
//  Created by yexiannan on 07/08/2019.
//  Copyright (c) 2019 yexiannan. All rights reserved.
//

#import "XNViewController.h"
#import "XNLocationTool.h"

@interface XNViewController ()

@end

@implementation XNViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [[XNLocationTool locationManager] getLocationResult:^(double longitude, double latitude, NSString * _Nonnull provinceName, NSString * _Nonnull provinceID, NSString * _Nonnull cityName, NSString * _Nonnull cityID, NSString * _Nullable areaName, NSString * _Nullable areaID) {
        NSLog(@"longitude = %lf, latitude = %lf, provinceName = %@, provinceID = %@, cityName = %@, cityID = %@, areaName = %@, areaID = %@,",longitude,latitude,provinceName,provinceID,cityName,cityID,areaName,areaID);

    } Error:^(NSError * _Nonnull error) {
        NSLog(@"error = %@",error);
    }];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end