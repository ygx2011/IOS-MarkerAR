//@import Foundation;
//@import Metal;
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#import "MBEMesh.h"

@class MBEOBJGroup;

@interface MBEOBJMesh : MBEMesh

- (instancetype)initWithGroup:(MBEOBJGroup *)group device:(id<MTLDevice>)device;

@end
