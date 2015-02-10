//
//  ViewController.m
//  CameraControllerClient
//
//  Created by qiong on 15-2-9.
//  Copyright (c) 2015年 qiong. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
            

@end

@implementation ViewController

- (void)initNetworkCommunication:(NSString*)IPAddress {
    if (_inputStream == nil && _outputStream == nil) {
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)IPAddress, 8009, &readStream, &writeStream);
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
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (IBAction)BtnConnectClicked:(id)sender {
    [self initNetworkCommunication: _textFieldIPAddress.text];
}

- (IBAction)BtnSendMsg:(id)sender {
    NSString *response  = [NSString stringWithFormat:@"iam:%@", _textFieldIPAddress.text];
    NSData *data = [[NSData alloc] initWithData:[response dataUsingEncoding:NSASCIIStringEncoding]];
    [_outputStream write:[data bytes] maxLength:[data length]];
}

-(void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    NSString *event;
    switch (streamEvent) {
        case NSStreamEventNone:
            event = @"NSStreamEventNone";
            break;
        case NSStreamEventOpenCompleted:
            _labelToast.text = @"Connect successfully";
            event = @"NSStreamEventOpenCompleted";
            break;
        case NSStreamEventErrorOccurred:
            _labelToast.text = @"Can not connect to the host!";
            event = @"NSStreamEventErrorOccurred";
            [self printErrorInfo:theStream];
            [self close];
            break;
        case NSStreamEventHasBytesAvailable:
            event = @"NSStreamEventHasBytesAvailable";
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
            break;
        case NSStreamEventHasSpaceAvailable:
            event = @"NSStreamEventHasSpaceAvailable";
            break;
        case NSStreamEventEndEncountered:
            event = @"NSStreamEventEndEncountered";
            [self printErrorInfo:theStream];
            break;
        default:
            [self close];
            event = @"Unknown";
            break;
    }
    NSLog(@"event: %@",event);
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
    _outputStream = nil;
}
@end
