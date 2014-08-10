//
//  HCViewController.h
//  HatController
//
//  Created by Gustavo Ambrozio on 8/1/14.
//  Copyright (c) 2014 Gustavo Ambrozio. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import <UIKit/UIKit.h>

#import "ColorPickerImageView.h"
#import "PTDBeanManager.h"
#import "UARTPeripheral.h"

@interface HCViewController : UIViewController <CBCentralManagerDelegate, UARTPeripheralDelegate, ColorPickerImageViewDelegate, PTDBeanDelegate, PTDBeanManagerDelegate>

@end
