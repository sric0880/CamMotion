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
#import "AccelerometerFilter.h"

@interface ViewController ()
{
    float scale;
    bool isFirstMotion;
    float originYaw;
    NSDate *lastDate;
    double speedx;
    double speedy;
    double speedz;
    double lastAcceX;
    double lastAcceY;
    double lastAcceZ;
    float sendDataArray[6];
    
    AccelerometerFilter *highPassFilter;
    AccelerometerFilter *lowPassFilter;
    
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
    speedx = speedy = speedz = 0;
    lastAcceX = lastAcceY = lastAcceZ = 0;
    
    highPassFilter = [[HighpassFilter alloc] initWithSampleRate:kUpdateFrequency cutoffFrequency:5.0];
    lowPassFilter = [[LowpassFilter alloc] initWithSampleRate:kUpdateFrequency cutoffFrequency:60.0];
    // Set the adaptive flag
    highPassFilter.adaptive = false;
    lowPassFilter.adaptive = false;
    
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
         
         if (isFirstMotion) {
             originYaw = attitude.yaw * factor;
             isFirstMotion = false;
             return;
         }
         
         sendDataArray[0] = attitude.roll * factor + 90;
         sendDataArray[1] = -attitude.yaw * factor + originYaw;
         sendDataArray[2] =  attitude.pitch * factor;
         
         //preview the curve of the acceleration data
         GraphViewController* gvc = (GraphViewController*)[self.tabBarController.viewControllers objectAtIndex:1];
         
         //update the globals for graph view
         double acceX = userAcceleration.x * G_Force;
         double acceY = userAcceleration.y * G_Force;
         double acceZ = userAcceleration.z * G_Force;
         
         //the acceleration graph for test
//       [gvc updateGraph:acceX y:acceY z:acceZ];
         
         //use low pass filter to smooth acceleration data
         [lowPassFilter addX:acceX y:acceY z:acceZ];
         acceX = lowPassFilter.x;
         acceY = lowPassFilter.y;
         acceZ = lowPassFilter.z;
         
         //calculate the speed.
         //refer to the link: http://stackoverflow.com/questions/6647314/how-can-i-find-distance-traveled-with-a-gyroscope-and-accelerometer
         NSDate* currentDate = [NSDate date];
         NSTimeInterval delta;
         if (lastDate==nil) {
             delta = 0;
         }else {
             delta = [currentDate timeIntervalSinceDate:lastDate];
         }
         lastDate = currentDate;
         speedx+=delta*(acceX+lastAcceX)/2;
         speedy+=delta*(acceY+lastAcceY)/2;
         speedz+=delta*(acceZ+lastAcceZ)/2;
         lastAcceX = acceX;
         lastAcceY = acceY;
         lastAcceZ = acceZ;
         
         //speed need to use high pass filter
         [highPassFilter addX:speedx y:speedy z:speedz];
         //preview the speed graph for test
         [gvc updateGraph:speedx y:speedy z:speedz];
         
         speedx = highPassFilter.x ;
         speedy = highPassFilter.y ;
         speedz = highPassFilter.z ;
         
         ////if speed is very small then assign it zero
         if (fabs(speedx) < 0.001) {
             speedx = 0;
         }
         if (fabs(speedy) < 0.001) {
             speedy = 0;
         }
         if (fabs(speedz) < 0.001) {
             speedz = 0;
         }
         
         //cast it to float for Unity3d
         sendDataArray[3] = speedx ;
         sendDataArray[4] = speedz ;
         sendDataArray[5] = speedy ;
         
         NSLog(@"%f, %f, %f", sendDataArray[3], sendDataArray[4], sendDataArray[5]);
         
         [outputStream write:(const uint8_t*)sendDataArray maxLength:sizeof(float)*6];
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
