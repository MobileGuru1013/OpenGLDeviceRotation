//
//  ViewController.m
//  OpenGLDeviceRotation
//
//  Created by Mobile Guru on 12/6/15.
//  Copyright © 2015 Mobile Guru. All rights reserved.
//

#import "ViewController.h"
#import "GLView.h"
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKEffects.h>

@interface ViewController ()

@property (nonatomic)                         GLuint       vertexPositionLocation;
@property (nonatomic)                         GLuint       vertexColorLocation;
@property (nonatomic)                         GLuint       projectionLocation;
@property (nonatomic)                         EAGLContext *context;
@property (nonatomic)                         GLuint       renderBuffer;
@property (nonatomic)                         GLuint       frameBuffer;
@property (nonatomic, getter=isTransitioning) BOOL         transitioning;
@property (nonatomic)                         NSInteger    transitionFrame;

@end

#define DEBUG_OUTPUT 0


@implementation ViewController

#pragma mark - ViewController Lifetime

- (void)viewDidLoad
{
    [super viewDidLoad];

#if DEBUG_OUTPUT
    printf("viewDidLoad\n\n");
#endif

    // Create a context
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    [self setContext:context];
    [EAGLContext setCurrentContext:context];

    [self createBuffers];
    [self compileShaders];
    [self setupDisplayLink];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

#if DEBUG_OUTPUT
    printf("viewWillLayoutSubviews()\n");
    printf("  Before:\n");
    [self printGLInfo];
#endif

    // Delete the old buffer, and create a new one at the current size/orientation
    GLuint renderbuffer = [self renderBuffer];
    glDeleteRenderbuffers(1, &renderbuffer);

    glGenRenderbuffers(1, &renderbuffer);
    [self setRenderBuffer:renderbuffer];
    glBindRenderbuffer(GL_RENDERBUFFER, renderbuffer);
    [[self context] renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)[self view].layer];

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderbuffer);

#if DEBUG_OUTPUT
    printf("  After:\n");
    [self printGLInfo];
    printf("\n");
#endif
}

- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

#if DEBUG_OUTPUT
    printf("viewWillTransitionToSize:([%.2f, %.2f])\n", size.width, size.height);
    [self printGLInfo];
    printf("\n");
#endif

    [self setTransitioning:YES];
    [self setTransitionFrame:0];
    [coordinator animateAlongsideTransition:nil
                                 completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
#if DEBUG_OUTPUT
                                     printf("viewWillTransitionToSize completion\n");
                                     [self printGLInfo];
                                     printf("\n");
#endif
                                     [self setTransitioning:NO];
                                 }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - OpenGL Setup


- (void)createBuffers
{
    GLuint renderbuffer;
    glGenRenderbuffers(1, &renderbuffer);
    [self setRenderBuffer:renderbuffer];
    glBindRenderbuffer(GL_RENDERBUFFER, renderbuffer);
    [[self context] renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)[self view].layer];

    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    [self setFrameBuffer:framebuffer];
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderbuffer);
}

- (void)compileShaders
{
    // Read vertex shader source
    NSString *vertexShaderSource = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"VertexShader"
                                                                                                      ofType:@"vsh"]
                                                             encoding:NSUTF8StringEncoding
                                                                error:nil];
    const char *vertexShaderSourceCString = [vertexShaderSource cStringUsingEncoding:NSUTF8StringEncoding];

    // Create and compile vertex shader
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderSourceCString, NULL);
    glCompileShader(vertexShader);

    // Read fragment shader source
    NSString *fragmentShaderSource = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"FragmentShader"
                                                                                                        ofType:@"fsh"]
                                                               encoding:NSUTF8StringEncoding
                                                                  error:nil];
    const char *fragmentShaderSourceCString = [fragmentShaderSource cStringUsingEncoding:NSUTF8StringEncoding];

    // Create and compile fragment shader
    GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSourceCString, NULL);
    glCompileShader(fragmentShader);

    // Create and link program
    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    glLinkProgram(program);

    // Use program
    glUseProgram(program);

    // Get shader locations
    GLuint vertexPositionLocation = glGetAttribLocation(program, "vertex_position");
    [self setVertexPositionLocation:vertexPositionLocation];
    glEnableVertexAttribArray([self vertexPositionLocation]);

    GLuint vertexColorLocation = glGetAttribLocation(program, "vertex_color");
    [self setVertexColorLocation:vertexColorLocation];
    glEnableVertexAttribArray([self vertexColorLocation]);

    GLuint projectionLocation = glGetUniformLocation(program, "projection_matrix");
    [self setProjectionLocation:projectionLocation];
}

- (void)setupDisplayLink
{
    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self
                                                             selector:@selector(render:)];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop]
                      forMode:NSDefaultRunLoopMode];
}

- (void)render:(CADisplayLink *)displayLink
{
    GLView *glView = (GLView *)[self view];

    // Set the viewport
    glViewport(0, 0, [glView bounds].size.width, [glView bounds].size.height);

    // Compute the projection matrix
    GLKMatrix4 projectionMatrix;
    GLfloat    ratio = [glView bounds].size.width/[glView bounds].size.height;

#if DEBUG_OUTPUT
    static CFTimeInterval startTime;
    if ([self isTransitioning]) {
        CFTimeInterval current;
        if ([self transitionFrame] == 0) {
            printf("\n\n");
            startTime = [displayLink timestamp];
            current = 0;
        }
        else {
            current = [displayLink timestamp] - startTime;
        }
        printf("render %d (%.2f) :\n", (int)[self transitionFrame], current);
        [self setTransitionFrame:[self transitionFrame] + 1];
        [self printGLInfo];
        printf("\n");
    }
#endif

#define NAIVE_RENDER 0

#if NAIVE_RENDER

    // Set the projection to match the dimensions of the GL view.
    if (ratio <= 1) {
        projectionMatrix = GLKMatrix4MakeOrtho(-1, 1, -1 / ratio, 1 / ratio, 0, 100);
    }
    else {
        projectionMatrix = GLKMatrix4MakeOrtho(-1 * ratio, 1 * ratio, -1, 1, 0, 100);
    }

#else
    
#define CONSTANT_SIZE_RENDER 1

    if ([self isTransitioning]) {
#if CONSTANT_SIZE_RENDER
        // Set the projection to match the dimensions of the GL view.
        if (ratio <= 1) {
            projectionMatrix = GLKMatrix4MakeOrtho(-1, 1, -1/ratio, 1/ratio, 0, 100);
        }
        else {
            projectionMatrix = GLKMatrix4MakeOrtho(-1*ratio, 1*ratio, -1, 1, 0, 100);
        }

        // Adjust the projection matrix to keep a constant size of displayed
        // square.
        CGSize     presentationLayerBoundsSize = [[[[self view] layer] presentationLayer] bounds].size;
        GLfloat    widthRatio                  = [glView bounds].size.width  / presentationLayerBoundsSize.width;
        GLfloat    heightRatio                 = [glView bounds].size.height / presentationLayerBoundsSize.height;
        GLKMatrix4 scaleMatrix                 = GLKMatrix4MakeScale(widthRatio, heightRatio, 1);

        projectionMatrix = GLKMatrix4Multiply(projectionMatrix, scaleMatrix);
#else
        // Just use the presentation layer size for the projection matrix.
        // Size of the rendered square will change during the orientation
        // change.
        CGSize  presentationLayerBoundsSize = [[[[self view] layer] presentationLayer] bounds].size;
        CGFloat presentationLayerRatio      = presentationLayerBoundsSize.width / presentationLayerBoundsSize.height;
        GLfloat ratio                       = presentationLayerRatio;
        if (ratio <= 1) {
            projectionMatrix = GLKMatrix4MakeOrtho(-1, 1, -1 / ratio, 1 / ratio, 0, 100);
        }
        else {
            projectionMatrix = GLKMatrix4MakeOrtho(-1 * ratio, 1 * ratio, -1, 1, 0, 100);
        }
#endif

    }
    else {
        // Non-transition projection matrix.
        if (ratio <= 1) {
            projectionMatrix = GLKMatrix4MakeOrtho(-1, 1, -1 / ratio, 1 / ratio, 0, 100);
        }
        else {
            projectionMatrix = GLKMatrix4MakeOrtho(-1 * ratio, 1 * ratio, -1, 1, 0, 100);
        }
    }
#endif

    // Set projection matrix
    glUniformMatrix4fv([self projectionLocation], 1, 0, (const float *)&projectionMatrix);

    // Clear
    glClearColor(0.5, 0.5, 0.5, 1);
    glClear(GL_COLOR_BUFFER_BIT);

    // Define geometry
    GLfloat square[] = {
        -0.5, -0.5,
         0.5, -0.5,
        -0.5,  0.5,
         0.5,  0.5
    };

    GLfloat squareColors[] = {
        0.0, 0.0,  1.0, 1.0,
        1.0, 1.0,  1.0, 1.0,
        1.0, 1.0,  1.0, 1.0,
        1.0, 1.0,  1.0, 1.0
    };

    // Draw
    glVertexAttribPointer([self vertexPositionLocation], 2, GL_FLOAT, GL_FALSE, 0, square);
    glVertexAttribPointer([self vertexColorLocation],    4, GL_FLOAT, GL_FALSE, 0, squareColors);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    // Present renderbuffer
    [[self context] presentRenderbuffer:GL_RENDERBUFFER];

    // Debugging: snap an image of the GL view
//    if ([self isTransitioning]) {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [self screenshot];
//        });
//    }
}

#pragma mark - Debug Methods

- (void)printGLInfo
{
    CGSize viewBoundsSize              = [[self view] bounds].size;
    CGSize layerBoundsSize             = [[[self view] layer] bounds].size;
    CGSize presentationLayerBoundsSize = [[[[self view] layer] presentationLayer] bounds].size;

    GLint  backingWidth;
    GLint  backingHeight;
    GLint  viewport[4];

    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH,  &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    glGetIntegerv(GL_VIEWPORT, viewport);

    printf("     viewBoundsSize              : [%.2f, %.2f]\n",     viewBoundsSize.width,              viewBoundsSize.height);
    printf("     layerBoundsSize             : [%.2f, %.2f]\n",     layerBoundsSize.width,             layerBoundsSize.height);
    printf("     presentationLayerBoundsSize : [%.2f, %.2f]\n",     presentationLayerBoundsSize.width, presentationLayerBoundsSize.height);
    printf("     backingWidth & height       : [%d %d]\n",          backingWidth,                      backingHeight);
    printf("     viewport                    : [%d, %d, %d, %d]\n", viewport[0], viewport[1], viewport[2], viewport[3]);
}

- (UIImage *)screenshot
{
    // http://stackoverflow.com/questions/2200736/how-to-take-a-screenshot-programmatically

    CGSize size = CGSizeMake([[self view] bounds].size.width, [[self view] bounds].size.height);

    UIGraphicsBeginImageContextWithOptions(size, NO, [[UIScreen mainScreen] scale]);

    CGRect rect = CGRectMake(0, 0,
                             [[self view] bounds].size.width,
                             [[self view] bounds].size.height);
    [[self view] drawViewHierarchyInRect:rect afterScreenUpdates:YES];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    });

    return image;
}

@end
