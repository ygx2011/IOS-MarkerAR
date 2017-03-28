#import "MBEMetalView.h"

@interface MBERenderer : NSObject <MBEMetalViewDelegate>

@property (nonatomic, assign) float qw;
@property (nonatomic, assign) float qx;
@property (nonatomic, assign) float qy;
@property (nonatomic, assign) float qz;

@property (nonatomic, assign) float t0;
@property (nonatomic, assign) float t1;
@property (nonatomic, assign) float t2;

@end
