//
//  ViewController.m
//  CameraControllerClient
//
//  Created by qiong on 15-2-9.
//  Copyright (c) 2015年 qiong. All rights reserved.
//

#import "ViewController.h"
#import "GraphViewController.h"
#import "Global.h"

@interface ViewController ()
{
    float scale;
    bool isFirstMotion;
    float originYaw;
    
    NSInputStream *inputStream;
    NSOutputStream *outputStream;
    CMMotionManager* motionManager;
}

//@property (nonatomic, retain) NSInputStream *inputStream;
//@property (nonatomic, retain) NSOutputStream *outputStream;
//@property (nonatomic, retain) CMMotionManager* motionManager;

@end

static float const factor = 180/M_PI;

@implementation ViewController

- (void)initNetworkCommunication:(NSString*)IPAddress withPort:(UInt32)Port {
    if (inputStream == nil && outputStream == nil) {
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)IPAddress, Port, &readStream, &writeStream);
        inputStream = (__bridge NSInputStream *)readStream;
        outputStream = (__bridge NSOutputStream *)writeStream;
        
        [inputStream setDelegate:self];
        [outputStream setDelegate:self];
        
        [inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        [inputStream open];
        [outputStream open];
        
        isFirstMotion = true;
        originYaw = 0.0f;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    scale = 1.0f;
    UIPinchGestureRecognizer *pgr = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinch:)];
    [pgr setDelegate:self];
    [self.view addGestureRecognizer:pgr];
    
    motionManager = [[CMMotionManager alloc] init];
    motionManager.deviceMotionUpdateInterval = 1/kUpdateFrequency;
//    [self.motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical];
    [motionManager startDeviceMotionUpdates];
    [motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *deviceMotion, NSError *error)
     {
         if (outputStream == nil) {
             return;
         }
         if(deviceMotion == nil)
         {
             return;
         }
         
         CMAttitude *attitude = deviceMotion.attitude;
         
         CMAcceleration userAcceleration = deviceMotion.userAcceleration;
         NSMutableData * data = [NSMutableData dataWithCapacity:0];
         
         if (isFirstMotion) {
             originYaw = attitude.yaw * factor;
             isFirstMotion = false;
             return;
         }
         
         float roll = attitude.roll * factor + 90;
         [data appendBytes:&roll length:sizeof(float)];
         float pitch = -attitude.yaw * factor + originYaw;
         [data appendBytes:&pitch length:sizeof(float)];
         float yaw =  attitude.pitch * factor;
         [data appendBytes:&yaw length:sizeof(float)];
         
         //update the globals for graph view
         double acceX = userAcceleration.x * G_Force;
         double acceY = userAcceleration.y * G_Force;
         double acceZ = userAcceleration.z * G_Force;
         
         GraphViewController* gvc = (GraphViewController*)[self.tabBarController.viewControllers objectAtIndex:1];
         [gvc updateGraph:acceX y:acceY z:acceZ];
         
         float accX = acceX;
         [data appendBytes:&accX length:sizeof(float)];
         float accY = acceY;
         [data appendBytes:&accY length:sizeof(float)];
         float accZ = acceZ;
         [data appendBytes:&accZ length:sizeof(float)];
         
         [outputStream write:[data bytes] maxLength:[data length]];
         
         NSLog(@"Attitude: %f, %f, %f; Accel: %f, %f, %f", roll, pitch, yaw, accX, accY, accZ);
     }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)BtnConnectClicked:(id)sender {
    [self initNetworkCommunication: _textFieldIPAddress.text withPort:(UInt32)[_textFieldPort.text intValue]];
}

-(void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    if (streamEvent == NSStreamEventOpenCompleted) {
        _labelToast.text = @"Connect successfully";
    }else if(streamEvent == NSStreamEventErrorOccurred) {
       _labelToast.text = @"Can not connect to the host!";
        [self printErrorInfo:theStream];
        [self close];
    }else if(streamEvent == NSStreamEventHasBytesAvailable) {
        if (theStream == inputStream) {
            NSMutableData *input = [[NSMutableData alloc] init];
            uint8_t buffer[1024];
            NSInteger len;
            while([inputStream hasBytesAvailable])
            {
                len = [inputStream read:buffer maxLength:sizeof(buffer)];
                if (len > 0)
                {
                    [input appendBytes:buffer length:len];
                }
            }
            NSString *resultstring = [[NSString alloc] initWithData:input encoding:NSUTF8StringEncoding];
            NSLog(@"Received: %@",resultstring);
        }
    }else if(streamEvent == NSStreamEventNone || streamEvent == NSStreamEventHasSpaceAvailable || streamEvent == NSStreamEventEndEncountered) {
        //egnore
    }else{
        [self close];
    }
}

-(void)printErrorInfo:(NSStream *)theStream
{
    NSLog(@"Error:%ld, %@",(long)[[theStream streamError] code], [[theStream streamError] localizedDescription]);
}

-(void)close
{
    [outputStream close];
    [outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [outputStream setDelegate:nil];
    outputStream = nil;
    [inputStream close];
    [inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [inputStream setDelegate:nil];
    inputStream = nil;
    NSLog(@"Connection closed.");
}

-(void)pinch:(id)sender
{
    scale = [(UIPinchGestureRecognizer*)sender scale];
//    NSLog(@"scale: %f", self.scale);
}
@end
