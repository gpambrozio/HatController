//
//  ColorPickerLens.m
//  PhotoScribe
//
//  Created by Gustavo Ambrozio on 25/3/11.
//  Copyright 2011 iBrazuca. All rights reserved.
//

#import "ColorPickerLens.h"


@implementation ColorPickerLens

@synthesize color = _color;

- (void)commonInit
{
    self.color = [UIColor clearColor];
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
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

- (void)setColor:(UIColor *)color
{
    if (![_color isEqual:color])
    {
        _color = color;
        [self setNeedsDisplay];
    }
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef c = UIGraphicsGetCurrentContext();
    
	CGContextSaveGState(c);
    
    CGFloat r = MIN(rect.size.width, rect.size.height) / 2.0f;
    
    CGContextSetShadow(c, CGSizeMake(2.0f, 2.0f), 0.5f);
    
    CGContextMoveToPoint(c, r, rect.size.height);
    CGContextAddArc(c, 
                    2.0f * r, rect.size.height,
                    r,
                    M_PI, M_PI + M_PI_4,
                    0);

    CGContextAddArc(c, 
                    r, rect.size.height - r * 1.7071067811865f,  // r + r * COS_45
                    r - 2.0f,                                   // radius
                    M_PI_4, M_PI_4+M_PI_2,                      // angles
                    1);
    
    CGContextAddArc(c, 
                    0.0f, rect.size.height,
                    r,
                    -M_PI_4, 0.0f,
                    0);
    
    [_color setFill];
    [[UIColor colorWithWhite:0.2f alpha:1.0f] setStroke];
    CGContextSetLineWidth(c, 2.0f);
    CGContextBeginTransparencyLayer(c, nil);
    CGContextDrawPath(c, kCGPathFillStroke);
    CGContextEndTransparencyLayer(c);
    
    CGContextRestoreGState(c);
}


@end
