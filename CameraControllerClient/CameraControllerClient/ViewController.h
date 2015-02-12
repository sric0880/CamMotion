//
//  ViewController.h
//  CameraControllerClient
//
//  Created by qiong on 15-2-9.
//  Copyright (c) 2015年 qiong. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>

@interface ViewController : UIViewController <NSStreamDelegate,UIGestureRecognizerDelegate>

- (IBAction)BtnConnectClicked:(id)sender;
@property (weak, nonatomic) IBOutlet UILabel *labelToast;
@property (weak, nonatomic) IBOutlet UITextField *textFieldIPAddress;
@property (weak, nonatomic) IBOutlet UITextField *textFieldPort;
@property (nonatomic, retain) NSInputStream *inputStream;
@property (nonatomic, retain) NSOutputStream *outputStream;
@property (nonatomic, retain) CMMotionManager* motionManager;
@end