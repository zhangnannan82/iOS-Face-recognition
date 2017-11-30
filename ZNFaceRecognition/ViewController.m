//
//  ViewController.m
//  ZNFaceRecognition
//
//  Created by ZN on 2017/11/30.
//  Copyright © 2017年 ZN. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()

//硬件设备
@property (nonatomic, strong) AVCaptureDevice *device;
//输入流
@property (nonatomic, strong) AVCaptureDeviceInput *input;
//协调输入输出流的数据
@property (nonatomic, strong) AVCaptureSession *session;
//预览层
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

//输出流
//用于捕捉静态图片
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
//原始视频帧，用于获取实时图像以及视频录制
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
//用于二维码识别以及人脸识别
@property (nonatomic, strong) AVCaptureMetadataOutput *metadataOutput;

@end

@implementation ViewController

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self.session startRunning];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //把previewLayer添加到self.view.layer上
    [self.view.layer addSublayer:self.previewLayer];
    
    UIButton *swithBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    swithBtn.frame = CGRectMake(self.view.frame.size.width/2 - 40, self.view.frame.size.height - 130, 80, 80);
    swithBtn.backgroundColor = [UIColor whiteColor];
    swithBtn.layer.masksToBounds = YES;
    swithBtn.layer.cornerRadius = 40;
    [swithBtn addTarget:self action:@selector(switchCamera:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:swithBtn];
}

#pragma mark --获取硬件设备--
//device有很多属性可以调整(注意调整device属性的时候需要上锁, 调整完再解锁)：
-(AVCaptureDevice *)device{
    if (_device == nil) {
        _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if ([_device lockForConfiguration:nil]) {
            //自动闪光灯
            if ([_device isFlashModeSupported:AVCaptureFlashModeAuto]) {
                [_device setFlashMode:AVCaptureFlashModeAuto];
            }
            //自动白平衡
            if ([_device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
                [_device setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
            }
            //自动对焦
            if ([_device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                [_device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            }
            //自动曝光
            if ([_device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
                [_device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            }
            [_device unlockForConfiguration];
        }
    }
    return _device;
}

#pragma mark --获取硬件的输入流--
//创建输入流的时候，会弹出alert向用户获取相机权限
-(AVCaptureDeviceInput *)input{
    if (_input == nil) {
        _input = [[AVCaptureDeviceInput alloc] initWithDevice:self.device error:nil];
    }
    return _input;
}

#pragma mark --协调输入和输出数据的会话--
//需要一个用来协调输入和输出数据的会话，然后把input添加到会话中
-(AVCaptureSession *)session{
    if (_session == nil) {
        _session = [[AVCaptureSession alloc] init];
        if ([_session canAddInput:self.input]) {
            [_session addInput:self.input];
        }
    }
    return _session;
}

#pragma mark --预览图像的层--
-(AVCaptureVideoPreviewLayer *)previewLayer{
    if (_previewLayer == nil) {
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
        _previewLayer.frame = self.view.layer.bounds;
    }
    return _previewLayer;
}

#pragma mark - 切换前后摄像头 -
-(void)switchCamera:(UIButton *)button {
    button.selected = !button.selected;
    NSUInteger cameraCount = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
    if (cameraCount > 1) {
        AVCaptureDevice *newCamera = nil;
        AVCaptureDeviceInput *newInput = nil;
        AVCaptureDevicePosition position = [[self.input device] position];
        if (position == AVCaptureDevicePositionFront){
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
        }else {
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
        }
        newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil];
        if (newInput != nil) {
            [self.session beginConfiguration];
            [self.session removeInput:self.input];
            if ([self.session canAddInput:newInput]) {
                [self.session addInput:newInput];
                self.input = newInput;
            }else {
                [self.session addInput:self.input];
            }
            [self.session commitConfiguration];
        }
    }
}

-(AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice *device in devices )
        if ( device.position == position ) return device;
    return nil;
}




- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


@end
