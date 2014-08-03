//
//  ColorPickerImageView.m
//  ColorPicker
//
//  Created by markj on 3/6/09.
//  Copyright 2009 Mark Johnson. All rights reserved.
//

#import "ColorPickerImageView.h"
#import <QuartzCore/CoreAnimation.h>

@interface ColorPickerImageView (PrivateStuff)

- (UIColor*) getPixelColorWithTouch:(NSSet*)touches;

@end

@implementation ColorPickerImageView

@synthesize pickedColorDelegate = _pickedColorDelegate;


- (void)commonInit {
    self.userInteractionEnabled = YES;
    self.multipleTouchEnabled = NO;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        [self commonInit];
    }
    return self;
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [_pickedColorDelegate picker:self touchedColor:[self getPixelColorWithTouch:touches] inPoint:[[touches anyObject] locationInView:self]];
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    [_pickedColorDelegate picker:self touchedColor:[self getPixelColorWithTouch:touches] inPoint:[[touches anyObject] locationInView:self]];
}

- (void) touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event {
    
	UIColor *color = [self getPixelColorWithTouch:touches]; 
    if (color) {
        [_pickedColorDelegate picker:self pickedColor:color];
    }
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    [_pickedColorDelegate picker:self touchedColor:nil inPoint:[[touches anyObject] locationInView:self]];
}

- (UIColor*) getPixelColorWithTouch:(NSSet*)touches {
    
    // This will hold our color data
    unsigned char data[4];
    UIColor* color = nil;
    UITouch* touch = [touches anyObject];
    CGPoint  point = [touch locationInView:self]; //where image was tapped

    // For retina images scale is 2.0f
    point.x *= self.image.scale;
    point.y *= self.image.scale;
    
    // Create the bitmap context. We want pre-multiplied ARGB, 8-bits 
    // per component. Regardless of what the source image format is 
    // (CMYK, Grayscale, and so on) it will be converted over to the format
    // specified here by CGBitmapContextCreate.
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef cgctx = CGBitmapContextCreate(data,
                                               1.0f,    // width
                                               1.0f,    // height
                                               8,       // bits per component
                                               4.0f,    // bytesPerRow
                                               colorSpace,
                                               (CGBitmapInfo)kCGImageAlphaPremultipliedFirst);
    
    // Make sure to release colorspace
    CGColorSpaceRelease( colorSpace );

    if (cgctx == NULL) 
    { 
        // error creating context
        return nil;
    }
    
    // subImage contains only one pixel at the position we touched.
    CGImageRef subImage = CGImageCreateWithImageInRect(self.image.CGImage, 
                                                       CGRectMake(floor(point.x), floor(point.y), 1.0f, 1.0f)); 

    // Draw the image to the bitmap context. Once we draw, the memory 
    // allocated for the context for rendering will then contain the 
    // raw image data in the specified color space (ARGB).
    CGContextDrawImage(cgctx, CGRectMake(0.0f, 0.0f, 1.0f, 1.0f), subImage); 
    
    // If alpha is lower than a specified threshold it means
    // it's a transparent area and I should ignore it
    int alpha = data[0];
    if (alpha >= 220) {
        color = [UIColor colorWithRed:((CGFloat)data[1]/255.0f) 
                                green:((CGFloat)data[2]/255.0f)
                                 blue:((CGFloat)data[3]/255.0f) 
                                alpha:((CGFloat)alpha/255.0f)];
    }
    
    // Release the context
    CGContextRelease(cgctx); 
    
    // Release the created subimage
    CGImageRelease(subImage);
    
    return color;
}


@end
