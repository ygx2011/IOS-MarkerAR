//
//  ViewController.m
//  MetalObjModel
//
//  Created by Ying Gaoxuan on 15/12/8.
//  Copyright © 2015年 Ying Gaoxuan. All rights reserved.
//

#import "ViewController.h"

#import <opencv2/opencv.hpp>
#import <opencv2/imgproc/types_c.h>
#import <opencv2/videoio/cap_ios.h>
#include <iostream>

#include "MarkerRecognizer.h"

using namespace std;
using namespace cv;

Point3f corners_3d[] =
{
    Point3f(-0.35f, -0.35f, 0),
    Point3f(-0.35f,  0.35f, 0),
    Point3f( 0.35f,  0.35f, 0),
    Point3f( 0.35f, -0.35f, 0)
};

float f_x = 640.0f;
float f_y = 640.0f;
float c_x = 320.0f;
float c_y = 240.0f;

float camera_matrix[] =
{
    f_x, 0.0f, c_x,
    0.0f, f_y, c_y,
    0.0f, 0.0f, 1.0f
};

float dist_coeff[] = {0.0f, 0.0f, 0.0f, 0.0f};
vector<Point3f> m_corners_3d = vector<Point3f>(corners_3d, corners_3d + 4);
Mat m_camera_matrix = Mat(3, 3, CV_32FC1, camera_matrix).clone();
Mat m_dist_coeff = Mat(1, 4, CV_32FC1, dist_coeff).clone();

@interface ViewController ()
{
    MBEMetalView *metalView;
    CvVideoCamera* videoCamera;
    
    MarkerRecognizer m_recognizer;
    float m_projection_matrix[16];
    float m_model_view_matrix[16];
}

@end

@implementation ViewController

@synthesize metalView;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.image = [UIImage imageNamed:@"icon.jpg"];
    
    self->videoCamera = [[CvVideoCamera alloc] initWithParentView:self.imageView];
    self->videoCamera.delegate = self;
    self->videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionBack;
    self->videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
    self->videoCamera.defaultFPS = 30;
    self->videoCamera.grayscaleMode = NO;
    
    self.renderer = [MBERenderer new];
    self.metalView.delegate = self;
    
    [metalView setBackgroundColor:[UIColor clearColor]];
    
}

- (void)drawInView:(MBEMetalView *)view
{
    
}

- (IBAction)startButtonPressed:(id)sender
{
    [self->videoCamera start];
}

- (void)processImage:(cv::Mat &)image
{
    Mat imgTemp_gray;
    cvtColor(image, imgTemp_gray, CV_BGRA2GRAY);
    m_recognizer.update(imgTemp_gray, 100);
    vector<Marker>& markers = m_recognizer.getMarkers();
    
    m_recognizer.drawToImage(image, Scalar(0,255,0,255), 2);
    
    Mat r, t;
    for (int i = 0; i < markers.size(); ++i)
    {
        markers[i].estimateTransformToCamera(m_corners_3d, m_camera_matrix, m_dist_coeff, r, t);
        
        self.renderer.qw = (sqrt(1.0 + r.at<double>(0,0) + r.at<double>(1,1) + r.at<double>(2,2)) / 2.0);
        self.renderer.qx = -(r.at<double>(2,1) - r.at<double>(1,2)) / (4*self.renderer.qw) ;
        self.renderer.qy = (r.at<double>(0,2) - r.at<double>(2,0)) / (4*self.renderer.qw) ;
        self.renderer.qz = -(r.at<double>(1,0) - r.at<double>(0,1)) / (4*self.renderer.qw) ;
        self.renderer.t0 = -t.at<double>(0);
        self.renderer.t1 = t.at<double>(1);
        self.renderer.t2 = -t.at<double>(2);
        
        [self.renderer drawInView:metalView];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
