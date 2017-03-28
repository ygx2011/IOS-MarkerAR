//@import UIKit;
//@import Metal;
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>

@interface MBETextureLoader : NSObject

+ (instancetype)sharedTextureLoader;

- (id<MTLTexture>)texture2DWithImageNamed:(NSString *)imageName
                                mipmapped:(BOOL)mipmapped
                             commandQueue:(id<MTLCommandQueue>)queue;

@end
