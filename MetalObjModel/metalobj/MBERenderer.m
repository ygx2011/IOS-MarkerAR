#import "MBERenderer.h"
#import "MBEMathUtilities.h"
#import "MBEOBJModel.h"
#import "MBEOBJMesh.h"
#import "MBETypes.h"
#import "MBETextureLoader.h"

@import Metal;
@import QuartzCore.CAMetalLayer;
@import simd;

static const NSInteger MBEInFlightBufferCount = 3;

@interface MBERenderer ()
@property (strong) id<MTLDevice> device;
@property (strong) id<MTLTexture> diffuseTexture;
@property (strong) MBEMesh *mesh;
@property (strong) id<MTLBuffer> uniformBuffer;
@property (strong) id<MTLCommandQueue> commandQueue;
@property (strong) id<MTLRenderPipelineState> renderPipelineState;
@property (strong) id<MTLDepthStencilState> depthStencilState;
@property (strong) id<MTLSamplerState> samplerState;
@property (strong) dispatch_semaphore_t displaySemaphore;
@property (assign) NSInteger bufferIndex;
@end

@implementation MBERenderer

- (instancetype)init
{
    if ((self = [super init]))
    {
        _device = MTLCreateSystemDefaultDevice();
        _displaySemaphore = dispatch_semaphore_create(MBEInFlightBufferCount);
        [self makePipeline];
        [self makeResources];
    }

    return self;
}

- (void)makePipeline
{
    self.commandQueue = [self.device newCommandQueue];

    id<MTLLibrary> library = [self.device newDefaultLibrary];

    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"vertex_project"];
    pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"fragment_texture"];
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;

    MTLDepthStencilDescriptor *depthStencilDescriptor = [MTLDepthStencilDescriptor new];
    depthStencilDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    depthStencilDescriptor.depthWriteEnabled = YES;
    self.depthStencilState = [self.device newDepthStencilStateWithDescriptor:depthStencilDescriptor];

    NSError *error = nil;
    self.renderPipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor
                                                                           error:&error];

    if (!self.renderPipelineState)
    {
        NSLog(@"Error occurred when creating render pipeline state: %@", error);
    }

    self.commandQueue = [self.device newCommandQueue];
}

- (void)makeResources
{
    // load texture
    MBETextureLoader *textureLoader = [MBETextureLoader new];
    _diffuseTexture = [textureLoader texture2DWithImageNamed:@"ram" mipmapped:YES commandQueue:_commandQueue];

    // load model
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"ram" withExtension:@"obj"];
    MBEOBJModel *model = [[MBEOBJModel alloc] initWithContentsOfURL:modelURL generateNormals:YES];
    MBEOBJGroup *group = [model groupForName:@"ram"];
    _mesh = [[MBEOBJMesh alloc] initWithGroup:group device:_device];

    // create uniform storage
    _uniformBuffer = [self.device newBufferWithLength:sizeof(MBEUniforms) * MBEInFlightBufferCount
                                              options:MTLResourceOptionCPUCacheModeDefault];
    [_uniformBuffer setLabel:@"Uniforms"];

    // create sampler state
    MTLSamplerDescriptor *samplerDesc = [MTLSamplerDescriptor new];
    samplerDesc.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDesc.tAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
    samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDesc.mipFilter = MTLSamplerMipFilterLinear;
    _samplerState = [_device newSamplerStateWithDescriptor:samplerDesc];
}

- (void)updateUniformsForView:(MBEMetalView *)view duration:(NSTimeInterval)duration
{
    float qw = self.qw; float qx = self.qx; float qy = self.qy; float qz = self.qz;
    
    vector_float4 r1 = { 1 - 2*qy*qy - 2*qz*qz, (2*qx*qy + 2*qz*qw), (2*qx*qz - 2*qy*qw), 0 };
    vector_float4 r2 = { (2*qx*qy - 2*qz*qw), 1 - 2*qx*qx - 2*qz*qz, (2*qy*qz + 2*qx*qw), 0 };
    vector_float4 r3 = { (2*qx*qz + 2*qy*qw), (2*qy*qz - 2*qx*qw), 1 - 2*qx*qx - 2*qy*qy, 0 };
    vector_float4 r4 = { self.t0, self.t1, self.t2, 1 };
    const matrix_float4x4 modelMatrix = {r1, r2, r3, r4};
    
    const vector_float3 cameraTranslation = { 0, 0, 0 };
    const matrix_float4x4 viewMatrix = matrix_float4x4_translation(cameraTranslation);
    
    float f_x = 640.0f;
    float f_y = 640.0f;
    float c_x = 320.0f;
    float c_y = 240.0f;
    
    float width = 640.0;
    float height = 480.0;
    float far_plane = 100.0;
    float near_plane = 0.01;
    vector_float4 p1 = { 2*f_x/width, 0.0f, 0.0f, 0.0f };
    vector_float4 p2 = { 0.0f, 2*f_y/height, 0.0f, 0.0f };
    vector_float4 p3 = { 1.0f - 2*c_x/width, 2*c_y/height - 1.0f, -(far_plane + near_plane)/(far_plane - near_plane), -1.0f };
    vector_float4 p4 = { 0.0f, 0.0f, -2.0f*far_plane*near_plane/(far_plane - near_plane), 0.0f };
    const matrix_float4x4 projectionMatrix = {p1, p2, p3, p4};

    MBEUniforms uniforms;
    uniforms.modelViewMatrix = matrix_multiply(viewMatrix, modelMatrix);
    uniforms.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, uniforms.modelViewMatrix);
    uniforms.normalMatrix = matrix_float4x4_extract_linear(uniforms.modelViewMatrix);

    const NSUInteger uniformBufferOffset = sizeof(MBEUniforms) * self.bufferIndex;
    memcpy([self.uniformBuffer contents] + uniformBufferOffset, &uniforms, sizeof(uniforms));
}

- (void)drawInView:(MBEMetalView *)view
{
    if (view.currentDrawable)
    {
        dispatch_semaphore_wait(self.displaySemaphore, DISPATCH_TIME_FOREVER);

        view.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);

        [self updateUniformsForView:view duration:view.frameDuration];

        id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];

        MTLRenderPassDescriptor *passDescriptor = [view currentRenderPassDescriptor];

        id<MTLRenderCommandEncoder> renderPass = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
        [renderPass setRenderPipelineState:self.renderPipelineState];
        [renderPass setDepthStencilState:self.depthStencilState];
        [renderPass setFrontFacingWinding:MTLWindingCounterClockwise];
        [renderPass setCullMode:MTLCullModeBack];

        const NSUInteger uniformBufferOffset = sizeof(MBEUniforms) * self.bufferIndex;

        [renderPass setVertexBuffer:self.mesh.vertexBuffer offset:0 atIndex:0];
        [renderPass setVertexBuffer:self.uniformBuffer offset:uniformBufferOffset atIndex:1];

        [renderPass setFragmentTexture:self.diffuseTexture atIndex:0];
        [renderPass setFragmentSamplerState:self.samplerState atIndex:0];

        [renderPass drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                               indexCount:[self.mesh.indexBuffer length] / sizeof(MBEIndex)
                                indexType:MBEIndexType
                              indexBuffer:self.mesh.indexBuffer
                        indexBufferOffset:0];

        [renderPass endEncoding];

        [commandBuffer presentDrawable:view.currentDrawable];

        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
            self.bufferIndex = (self.bufferIndex + 1) % MBEInFlightBufferCount;
            dispatch_semaphore_signal(self.displaySemaphore);
        }];
        
        [commandBuffer commit];
    }
}

@end
