//
//  GraphViewController.h
//  CameraControllerClient
//
//  Created by qiong on 15-2-13.
//  Copyright (c) 2015年 qiong. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GraphView.h"

@interface GraphViewController : UIViewController
@property (weak, nonatomic) IBOutlet GraphView *graphView;
@property (weak, nonatomic) IBOutlet GraphView *filterGraphView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *filterPass;
@property (weak, nonatomic) IBOutlet UISegmentedControl *filterType;
- (IBAction)filterChoose:(id)sender;
- (IBAction)typeChoose:(id)sender;
- (void) updateGraph:(double)x y:(double)y z:(double)z;

@end
