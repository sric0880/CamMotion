//
//  ViewController.m
//  CameraControllerClient
//
//  Created by qiong on 15-2-9.
//  Copyright (c) 2015年 qiong. All rights reserved.
//

#import "ViewController.h"



@interface ViewController ()
@property float scale;
@end

static float const factor = 180/M_PI;

@implementation ViewController

- (void)initNetworkCommunication:(NSString*)IPAddress withPort:(UInt32)Port {
    if (_inputStream == nil && _outputStream == nil) {
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)IPAddress, Port, &readStream, &writeStream);
        _inputStream = (__bridge NSInputStream *)readStream;
        _outputStream = (__bridge NSOutputStream *)writeStream;
        
        [_inputStream setDelegate:self];
        [_outputStream setDelegate:self];
        
        [_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        [_inputStream open];
        [_outputStream open];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.scale = 1.0f;
    UIPinchGestureRecognizer *pgr = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinch:)];
    [pgr setDelegate:self];
    [self.view addGestureRecognizer:pgr];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated {
     [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(updateDeviceMotion) userInfo:nil repeats:YES];
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.deviceMotionUpdateInterval = 1.0f/60.0f;
//    [self.motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryCorrectedZVertical];
    [self.motionManager startDeviceMotionUpdates];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if(self.motionManager != nil) {
        [self.motionManager stopDeviceMotionUpdates];
        self.motionManager = nil;
    }
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
        if (theStream == _inputStream) {
            NSMutableData *input = [[NSMutableData alloc] init];
            uint8_t buffer[1024];
            NSInteger len;
            while([_inputStream hasBytesAvailable])
            {
                len = [_inputStream read:buffer maxLength:sizeof(buffer)];
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
    [_outputStream close];
    [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [_outputStream setDelegate:nil];
    _outputStream = nil;
    [_inputStream close];
    [_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [_inputStream setDelegate:nil];
    _inputStream = nil;
    NSLog(@"Connection closed.");
}

-(void)updateDeviceMotion
{
    if (_outputStream == nil) {
        return;
    }
    CMDeviceMotion *deviceMotion = self.motionManager.deviceMotion;
    if(deviceMotion == nil)
    {
        return;
    }
    
    CMAttitude *attitude = deviceMotion.attitude;
    
    CMAcceleration userAcceleration = deviceMotion.userAcceleration;
    NSMutableData * data = [NSMutableData dataWithCapacity:0];
    
    float roll = attitude.roll * factor + 90;
    [data appendBytes:&roll length:sizeof(float)];
    float pitch = -attitude.yaw * factor ;
    [data appendBytes:&pitch length:sizeof(float)];
    float yaw =  attitude.pitch * factor;
    [data appendBytes:&yaw length:sizeof(float)];
    float accX = userAcceleration.x;
    [data appendBytes:&accX length:sizeof(float)];
    float accY = userAcceleration.y;
    [data appendBytes:&accY length:sizeof(float)];
    float accZ = userAcceleration.z;
    [data appendBytes:&accZ length:sizeof(float)];
    
    [_outputStream write:[data bytes] maxLength:[data length]];
    
//    NSLog(@"Attitude: %f, %f, %f; Accel: %f, %f, %f", roll, pitch, yaw, accX, accY, accZ);
}

-(void)pinch:(id)sender
{
    self.scale = [(UIPinchGestureRecognizer*)sender scale];
//    NSLog(@"scale: %f", self.scale);
}
@end
