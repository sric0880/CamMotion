//
//  GraphViewController.m
//  CameraControllerClient
//
//  Created by qiong on 15-2-13.
//  Copyright (c) 2015年 qiong. All rights reserved.
//

#import "GraphViewController.h"
#import "AccelerometerFilter.h"
#import "Global.h"

@interface GraphViewController()
{
    AccelerometerFilter *filter;
    bool useAdaptive;
}
@end

@implementation GraphViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    useAdaptive = false;
    [self changeFilter:[LowpassFilter class]];
    
    [self.graphView setIsAccessibilityElement:YES];
    [self.graphView setAccessibilityLabel:NSLocalizedString(@"Graph View", @"")];
    
    [self.filterGraphView setIsAccessibilityElement:YES];
    [self.filterGraphView setAccessibilityLabel:NSLocalizedString(@"Filted Graph View", @"")];
}

- (IBAction)filterChoose:(id)sender {
    if ([sender selectedSegmentIndex] == 0)
    {
        // Index 0 of the segment selects the lowpass filter
        [self changeFilter:[LowpassFilter class]];
    }
    else
    {
        // Index 1 of the segment selects the highpass filter
        [self changeFilter:[HighpassFilter class]];
    }
    
    // Inform accessibility clients that the filter has changed.
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

- (IBAction)typeChoose:(id)sender {
    // Index 1 is to use the adaptive filter, so if selected then set useAdaptive appropriately
    useAdaptive = [sender selectedSegmentIndex] == 1;
    // and update our filter and filterLabel
    filter.adaptive = useAdaptive;
    
    // Inform accessibility clients that the adaptive selection has changed.
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
}

- (void)changeFilter:(Class)filterClass
{
    // Ensure that the new filter class is different from the current one...
    if (filterClass != [filter class])
    {
        // And if it is, release the old one and create a new one.
        filter = [[filterClass alloc] initWithSampleRate:kUpdateFrequency cutoffFrequency:5.0];
        // Set the adaptive flag
        filter.adaptive = useAdaptive;
    }
}

- (void) updateGraph:(double)x y:(double)y z:(double)z;
{
    [filter addX:x y:y z:z];
    [self.graphView addX:x y:y z:z];
    [self.filterGraphView addX:filter.x y:filter.y z:filter.z];
}
@end