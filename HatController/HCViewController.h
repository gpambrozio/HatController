//
//  HCViewController.h
//  HatController
//
//  Created by Gustavo Ambrozio on 8/1/14.
//  Copyright (c) 2014 Gustavo Ambrozio. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import <UIKit/UIKit.h>

#import "UARTPeripheral.h"
#import "ColorPickerImageView.h"

@interface HCViewController : UIViewController <CBCentralManagerDelegate, UARTPeripheralDelegate, ColorPickerImageViewDelegate>

@end
