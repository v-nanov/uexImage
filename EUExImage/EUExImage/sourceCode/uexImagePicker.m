//
//  uexImagePicker.m
//  EUExImage
//
//  Created by CeriNo on 15/9/29.
//  Copyright © 2015年 AppCan. All rights reserved.
//

#import "uexImagePicker.h"
#import "EUExImage.h"
#import "uexImageAlbumPickerController.h"
#import <CoreLocation/CoreLocation.h>
#import "MBProgressHUD.h"
#import <Photos/Photos.h>
@interface uexImagePicker()<uexImagePhotoPickerDelegate>
//@property (nonatomic,strong)QBImagePickerController *picker;
@property uexImageAlbumPickerModel *model;
@property UINavigationController *picker;
@end

@implementation uexImagePicker
-(instancetype)initWithEUExImage:(EUExImage *)EUExImage{
    self=[super init];
    if(self){
        self.EUExImage=EUExImage;
        [self setDafaultConfig];
    }
    return self;
}

-(void)open{
    uexImageAlbumPickerModel *model =[[uexImageAlbumPickerModel alloc]init];
    self.model=model;
    self.model.delegate=self;
    _model.minimumSelectedNumber=self.min;
    _model.maximumSelectedNumber=self.max;
    uexImageAlbumPickerController *albumPickerController =[[uexImageAlbumPickerController alloc]initWithModel:self.model];
    self.picker=[[UINavigationController alloc]initWithRootViewController:albumPickerController];
    [self.EUExImage presentViewController:self.picker animated:YES];
    
}




-(void)clean{
    self.picker=nil;
    self.model=nil;
    [self setDafaultConfig];
}


-(void)setDafaultConfig{

    self.quality=0.5;
    self.usePng=NO;
    self.min=1;
    self.max=0;
    self.picker=nil;
    self.detailedInfo=NO;
}


#pragma mark - uexImagePhotoPickerDelegate
-(void)uexImageAlbumPickerModelDidCancelPickingAction:(uexImageAlbumPickerModel *)model{
    [self.EUExImage dismissViewController:self.picker Animated:YES completion:^{
        [self.EUExImage callbackJsonWithName:@"onPickerClosed" Object:@{cUexImageCallbackIsCancelledKey:@(YES)}];
        
        [self clean];
    }];
}

-(void)uexImageAlbumPickerModel:(uexImageAlbumPickerModel *)model didFinishPickingAction:(NSArray<ALAsset *> *)assets{
    UEXIMAGE_ASYNC_DO_IN_GLOBAL_QUEUE(^{
        UEXIMAGE_ASYNC_DO_IN_MAIN_QUEUE(^{[MBProgressHUD showHUDAddedTo:self.picker.view animated:YES];});
        
        NSMutableDictionary *dict=[NSMutableDictionary dictionary];
        [dict setValue:@(NO) forKey:cUexImageCallbackIsCancelledKey];
        NSMutableArray *dataArray =[NSMutableArray array];
        NSMutableArray *detailedInfoArray=nil;
        if(self.detailedInfo){
            detailedInfoArray=[NSMutableArray array];
        }
        
        for(ALAsset * asset in assets){
            ALAssetRepresentation *representation = [asset defaultRepresentation];
            UIImage * assetImage =[UIImage imageWithCGImage:[representation fullResolutionImage] scale:representation.scale orientation:(UIImageOrientation)representation.orientation];
            NSString * imagePath =[self.EUExImage saveImage:assetImage quality:self.quality usePng:self.usePng];
            if(imagePath){
                [dataArray addObject:imagePath];
                if(detailedInfoArray){
                    NSMutableDictionary *info=[NSMutableDictionary dictionary];
                    [info setValue:imagePath forKey:@"localPath"];
                    [info setValue:@((int)[[asset valueForProperty:ALAssetPropertyDate] timeIntervalSince1970]) forKey:@"timestamp"];
                    CLLocation *location=[asset valueForProperty:ALAssetPropertyLocation];
                    if(location){
                        [info setValue:@(location.coordinate.latitude) forKey:@"latitude"];
                        [info setValue:@(location.coordinate.longitude) forKey:@"longitude"];
                        [info setValue:@(location.altitude) forKey:@"altitude"];
                    }
                    
                    //不丢失exif
                    Byte *buffer = (Byte*)malloc(representation.size);
                    NSUInteger buffered = [representation getBytes:buffer fromOffset:0.0 length:representation.size error:nil];
                    NSData *imgData = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
                    CGImageSourceRef imgSource = CGImageSourceCreateWithData((CFDataRef)imgData, nil);
                    CFDictionaryRef imageInfo = CGImageSourceCopyPropertiesAtIndex(imgSource, 0, NULL);
                    NSDictionary *imageInDict = CFBridgingRelease(imageInfo);
                    if([imageInDict objectForKey:@"{Exif}"]){
                        NSDictionary *Exif = [imageInDict objectForKey:@"{Exif}"];
                        [info setValue:[Exif objectForKey:@"LensMake"] forKey:@"make"];
                        [info setValue:[Exif objectForKey:@"LensModel"] forKey:@"model"];
                        [info setValue:[Exif objectForKey:@"ExposureTime"] forKey:@"exposureTime"];
//                        [info setValue:[Exif objectForKey:@"ISOSpeedRatings"] forKey:@"iso"];
                        [info setValue:[Exif objectForKey:@"FocalLength"] forKey:@"focalLength"];
                        [info setValue:[Exif objectForKey:@"WhiteBalance"] forKey:@"whiteBalance"];
                        [info setValue:[Exif objectForKey:@"ApertureValue"] forKey:@"aperture"];
                        [info setValue:[Exif objectForKey:@"Flash"] forKey:@"flash"];
                        
                        NSArray *iso = [Exif objectForKey:@"ISOSpeedRatings"];
                        if(iso && [iso isKindOfClass:[NSArray class]]){
                            [info setValue:iso[0] forKey:@"iso"];
                        }
                    }
//                    NSLog(@"--imageInfo:%@",imageInfo);
                    
                    [detailedInfoArray addObject:info];
                }
                
                
                
            }
            
        }
        [dict setValue:dataArray forKey:cUexImageCallbackDataKey];
        if(detailedInfoArray){
            [dict setValue:detailedInfoArray forKey:@"detailedImageInfo"];
        }
        UEXIMAGE_ASYNC_DO_IN_MAIN_QUEUE(^{[MBProgressHUD hideHUDForView:self.picker.view animated:YES];});
        [self.EUExImage dismissViewController:self.picker Animated:YES completion:^{
            [self.EUExImage callbackJsonWithName:@"onPickerClosed" Object:dict];
            [self clean];
        }];
        
        
        
    });
}


@end
