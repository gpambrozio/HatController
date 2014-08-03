//
//  ColorPickerImageView.h
//  ColorPicker
//
//  Created by markj on 3/6/09.
//  Copyright 2009 Mark Johnson. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ColorPickerImageView;

@protocol ColorPickerImageViewDelegate

- (void)picker:(ColorPickerImageView*)picker pickedColor:(UIColor*)color;
- (void)picker:(ColorPickerImageView*)picker touchedColor:(UIColor*)color inPoint:(CGPoint)point;

@end

@interface ColorPickerImageView : UIImageView

@property (nonatomic, weak) IBOutlet id<ColorPickerImageViewDelegate> pickedColorDelegate;

@end
