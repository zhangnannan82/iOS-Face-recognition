//
//  ViewController.m
//  ZNFaceRecognition
//
//  Created by ZN on 2017/11/30.
//  Copyright © 2017年 ZN. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

#define arcRandom arc4random()%255/255.0
@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureMetadataOutputObjectsDelegate>

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
    
    CGFloat width = (self.view.frame.size.width - 100)/3;
    for (NSInteger i = 0; i < 3; i++) {
        UIButton *swithBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        swithBtn.frame = CGRectMake( 50 + width * i, self.view.frame.size.height - 130, 80, 80);
        swithBtn.backgroundColor = [UIColor colorWithRed:arcRandom green:arcRandom blue:arcRandom alpha:1.0];
        swithBtn.layer.masksToBounds = YES;
        swithBtn.layer.cornerRadius = 40;
        if (i == 0) {
            [swithBtn addTarget:self action:@selector(switchTorch:) forControlEvents:UIControlEventTouchUpInside];
        }
        else if (i == 1) {
            [swithBtn addTarget:self action:@selector(screenshot) forControlEvents:UIControlEventTouchUpInside];
        }
        else {
            [swithBtn addTarget:self action:@selector(switchCamera:) forControlEvents:UIControlEventTouchUpInside];
        }
        [self.view addSubview:swithBtn];
    }
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

#pragma mark --使用AVCaptureStillImageOutput捕获静态图片--
-(AVCaptureStillImageOutput *)stillImageOutput{
    if (_stillImageOutput == nil) {
        _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    }
    return _stillImageOutput;
}

#pragma mark --AVCaptureVideoOutput实时获取预览图像--
- (AVCaptureVideoDataOutput *)videoDataOutput{
    if (_videoDataOutput == nil) {
        _videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        //设置videoDataOutput的像素格式
        [_videoDataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        [_videoDataOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    }
    return _videoDataOutput;
}

#pragma mark -- AVCaptureMetadataOutput 识别二维码 & 人脸识别 --
-(AVCaptureMetadataOutput *)metadataOutput{
    if (_metadataOutput == nil) {
        _metadataOutput = [[AVCaptureMetadataOutput alloc]init];
        [_metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        //设置扫描区域
        _metadataOutput.rectOfInterest = self.view.bounds;
    }
    return _metadataOutput;
}

#pragma mark --协调输入和输出数据的会话--
//需要一个用来协调输入和输出数据的会话，然后把input添加到会话中
-(AVCaptureSession *)session{
    if (_session == nil) {
        _session = [[AVCaptureSession alloc] init];
        if ([_session canAddInput:self.input]) {
            [_session addInput:self.input];
        }
        //将stillImageOutput添加到session中-捕获静态图片
        if ([_session canAddOutput:self.stillImageOutput]) {
            [_session addOutput:self.stillImageOutput];
        }
        //实时帧图像
        if ([_session canAddOutput:self.videoDataOutput]) {
            [_session addOutput:self.videoDataOutput];
        }
        //二维码
        if ([_session canAddOutput:self.metadataOutput]) {
            [_session addOutput:self.metadataOutput];
            //设置扫码格式
//            self.metadataOutput.metadataObjectTypes = @[
//                                                        AVMetadataObjectTypeQRCode,
//                                                        AVMetadataObjectTypeEAN13Code,
//                                                        AVMetadataObjectTypeEAN8Code,
//                                                        AVMetadataObjectTypeCode128Code
//                                                        ];
            //人脸识别也是基于AVCaptureMetadataOutput实现的，跟二维码识别的区别在于，扫描类型：
            self.metadataOutput.metadataObjectTypes = @[AVMetadataObjectTypeFace];
        }
        //设定摄像头的尺寸为1080x1920
        [_session setSessionPreset:AVCaptureSessionPreset1920x1080];
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

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice *device in devices )
        if ( device.position == position ) return device;
    return nil;
}

#pragma mark -- 切换手电筒 --
-(void)switchTorch:(UIButton*)button{
    button.selected = !button.selected;
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (captureDeviceClass != nil) {
        if ([self.device hasTorch] && [self.device hasFlash]){
            [self.device lockForConfiguration:nil];
            if (button.selected) {
                [self.device setTorchMode:AVCaptureTorchModeOn];
            } else {
                [self.device setTorchMode:AVCaptureTorchModeOff];
            }
            [self.device unlockForConfiguration];
        }
    }
}

#pragma mark --拍照--
//AVCaptureStillImageOutput截取静态图片，会有快门声
-(void)screenshot {
    AVCaptureConnection * videoConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    if (!videoConnection) {
        NSLog(@"take photo failed!");
        return;
    }
    
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer == NULL) {
            return;
        }
        NSData * imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *image = [UIImage imageWithData:imageData];
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        if (status == PHAuthorizationStatusRestricted || status == PHAuthorizationStatusDenied)
        {
            // 无权限
            NSLog(@"相机权限受限");
        }
        else {
             [self saveImageToPhotoAlbum:image];
        }
    }];
}

#pragma mark --保存照片到系统相册--
- (void)saveImageToPhotoAlbum:(UIImage *)image
{
    NSMutableArray *imageIds = [NSMutableArray array];
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        //写入图片到相册
        PHAssetChangeRequest *req = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        //记录本地标识，等待完成后取到相册中的图片对象
        [imageIds addObject:req.placeholderForCreatedAsset.localIdentifier];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        NSLog(@"success = %d, error = %@", success, error);
        if (success)
        {
            //成功后取相册中的图片对象
            __block PHAsset *imageAsset = nil;
            PHFetchResult *result = [PHAsset fetchAssetsWithLocalIdentifiers:imageIds options:nil];
            [result enumerateObjectsUsingBlock:^(PHAsset * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                imageAsset = obj;
                *stop = YES;
            }];
            if (imageAsset)
            {
                //加载图片数据
                [[PHImageManager defaultManager] requestImageDataForAsset:imageAsset
                                                                  options:nil
                                                            resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
                                                                NSLog(@"imageData = %@", imageData);
                                                            }];
            }
        }
    }];
}

#pragma mark -- AVCaptureVideoDataOutputSampleBufferDelegate 实时帧图像--
//AVCaptureVideoDataOutput获取实时图像，这个代理方法的回调频率很快，几乎与手机屏幕的刷新频率一样快
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    //设置一下视频的方向,否则默认是倒序的
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    UIImage *largeImage = [self imageFromSampleBuffer:sampleBuffer];
    NSLog(@"largeImage:%@",largeImage);
    //从中间截取出512x512的图片传给第三方SDK做进一步业务处理：
    //smallImage = [largeImage imageCompressTargetSize:CGSizeMake(512.0f, 512.0f)];
}

#pragma mark -- CMSampleBufferRef转NSImage --
-(UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    // 为媒体数据设置一个CMSampleBuffer的Core Video图像缓存对象
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // 锁定pixel buffer的基地址
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    // 得到pixel buffer的基地址
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // 得到pixel buffer的行字节数
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // 得到pixel buffer的宽和高
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    // 创建一个依赖于设备的RGB颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    // 用抽样缓存的数据创建一个位图格式的图形上下文（graphics context）对象
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // 根据这个位图context中的像素数据创建一个Quartz image对象
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // 解锁pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    // 释放context和颜色空间
    CGContextRelease(context); CGColorSpaceRelease(colorSpace);
    // 用Quartz image创建一个UIImage对象image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    // 释放Quartz image对象
    CGImageRelease(quartzImage);
    return (image);
}

#pragma mark -- AVCaptureMetadataOutputObjectsDelegate 二维码扫描 & 人脸识别 --
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection{
    //人脸识别
    if (metadataObjects.count>0) {
        [self.session stopRunning];
        AVMetadataMachineReadableCodeObject *metadataObject = [metadataObjects objectAtIndex :0];
        if (metadataObject.type == AVMetadataObjectTypeFace) {
            AVMetadataObject *objec = [self.previewLayer transformedMetadataObjectForMetadataObject:metadataObject];
            NSLog(@"人脸识别：%@",objec);
        }
    }
#pragma mark--二维码--
//    if (metadataObjects.count>0) {
//        [self.session stopRunning];
//        AVMetadataMachineReadableCodeObject *metadataObject = [metadataObjects objectAtIndex :0];
//        NSLog(@"二维码内容 ：%@",metadataObject.stringValue);
//    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


@end
