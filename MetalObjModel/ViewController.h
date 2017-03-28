//
//  ViewController.h
//  MetalObjModel
//
//  Created by Ying Gaoxuan on 15/12/8.
//  Copyright © 2015年 Ying Gaoxuan. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MBERenderer.h"
#import "MBEMetalView.h"

#import <opencv2/videoio/cap_ios.h>

@class MBEMetalView;

@interface ViewController : UIViewController<MBEMetalViewDelegate,CvVideoCameraDelegate>

@property (nonatomic, strong) MBERenderer *renderer;
//@property (nonatomic, assign) NSTimeInterval lastMooTime;
//@property (nonatomic, assign) CGPoint angularVelocity;
//@property (nonatomic, assign) CGPoint angle;

@property (nonatomic, retain) IBOutlet MBEMetalView *metalView;

@property (weak, nonatomic) IBOutlet UIButton *start;
- (IBAction)startButtonPressed:(id)sender;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

