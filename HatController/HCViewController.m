//
//  HCViewController.m
//  HatController
//
//  Created by Gustavo Ambrozio on 8/1/14.
//  Copyright (c) 2014 Gustavo Ambrozio. All rights reserved.
//

#import "HCViewController.h"
#import "ColorPickerLens.h"

typedef enum {
    ConnectionStatusDisconnected = 0,
    ConnectionStatusScanning,
    ConnectionStatusConnected,
} ConnectionStatus;

typedef enum {
    HatCommandGetCount = 50,
    HatCommandResetCount,
    HatCommandSetColor,
    HatCommandChangeMode,
    HatCommandSetBrightness,
} HatCommand;

@interface HCViewController () {
    CBCentralManager    *cm;
    UARTPeripheral      *currentPeripheral;
    UIAlertView         *currentAlertView;
}

@property (nonatomic, assign) ConnectionStatus connectionStatus;
@property (weak, nonatomic) IBOutlet UIButton *btnConnect;
@property (weak, nonatomic) IBOutlet UILabel *lblStatus;
@property (weak, nonatomic) IBOutlet UITextField *txtBanner;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentMode;
@property (weak, nonatomic) IBOutlet ColorPickerImageView *pickerColor;
@property (weak, nonatomic) IBOutlet ColorPickerLens *pickerLens;
@property (weak, nonatomic) IBOutlet UILabel *lblBrightness;

@end

@implementation HCViewController

- (void)viewDidLoad{

    [super viewDidLoad];

    [self.view setAutoresizesSubviews:YES];

    cm = [[CBCentralManager alloc] initWithDelegate:self queue:nil];

    self.connectionStatus = ConnectionStatusDisconnected;

    [self didTapConnect:nil];
}

- (void)scanForPeripherals {

    //Look for available Bluetooth LE devices

    //skip scanning if UART is already connected
    NSArray *connectedPeripherals = [cm retrieveConnectedPeripheralsWithServices:@[UARTPeripheral.uartServiceUUID]];
    if ([connectedPeripherals count] > 0) {
        //connect to first peripheral in array
        [self connectPeripheral:[connectedPeripherals objectAtIndex:0]];
    }

    else {

        [cm scanForPeripheralsWithServices:@[UARTPeripheral.uartServiceUUID]
                                   options:@{CBCentralManagerScanOptionAllowDuplicatesKey: [NSNumber numberWithBool:NO]}];
    }

}


- (void)connectPeripheral:(CBPeripheral*)peripheral {

    //Connect Bluetooth LE device

    //Clear off any pending connections
    [cm cancelPeripheralConnection:peripheral];

    //Connect
    currentPeripheral = [[UARTPeripheral alloc] initWithPeripheral:peripheral delegate:self];
    [cm connectPeripheral:peripheral options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey: [NSNumber numberWithBool:YES]}];

}


- (void)disconnect {

    //Disconnect Bluetooth LE device

    self.connectionStatus = ConnectionStatusDisconnected;

    [cm cancelPeripheralConnection:currentPeripheral.peripheral];

}

- (IBAction)didTapConnect:(id)sender {
    self.connectionStatus = ConnectionStatusScanning;

    _btnConnect.enabled = NO;

    [self scanForPeripherals];

    currentAlertView = [[UIAlertView alloc] initWithTitle:@"Scanning …"
                                                  message:nil
                                                 delegate:self
                                        cancelButtonTitle:@"Cancel"
                                        otherButtonTitles:nil];

    [currentAlertView show];
}

- (IBAction)didTapSetText:(id)sender {
    [self sendText:_txtBanner.text];
    [_txtBanner resignFirstResponder];
    _txtBanner.text = @"";
}

- (IBAction)didTapPredefined:(UIButton *)sender {
    [self sendText:[sender titleForState:UIControlStateNormal]];
}

- (IBAction)didChangeMode:(UISegmentedControl *)sender {
    Byte mode = (Byte)sender.selectedSegmentIndex;
    [self sendCommand:HatCommandChangeMode extraData:[NSData dataWithBytes:&mode length:1]];
}

- (IBAction)sliderBrightness:(UISlider *)sender {
    Byte brightness = (Byte)roundf(sender.value);
    [self sendCommand:HatCommandSetBrightness extraData:[NSData dataWithBytes:&brightness length:1]];
}
- (IBAction)sliderBrightnessChanged:(UISlider *)sender {
    _lblBrightness.text = [NSString stringWithFormat:@"%.0f", roundf(sender.value)];
}

-(void)setConnectionStatus:(ConnectionStatus)connectionStatus {
    _connectionStatus = connectionStatus;
    switch (_connectionStatus) {
        case ConnectionStatusConnected:
            _lblStatus.text = @"Connected";
            break;

        case ConnectionStatusDisconnected:
            _lblStatus.text = @"Disconnected";
            break;

        case ConnectionStatusScanning:
            _lblStatus.text = @"Scanning";
            break;

        default:
            break;
    }
}

- (void)sendText:(NSString *)text {
    text = text.uppercaseString;
    NSUInteger length = [text lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    Byte *data = malloc(1 + length);
    *data = (Byte)length;
    [text getBytes:data+1
         maxLength:length
        usedLength:nil
          encoding:NSUTF8StringEncoding
           options:0
             range:NSMakeRange(0, text.length)
    remainingRange:nil];
    [self sendData:[NSData dataWithBytesNoCopy:data
                                        length:length+1
                                  freeWhenDone:YES]];
    _segmentMode.selectedSegmentIndex = 1;
}

- (void)sendCommand:(HatCommand)command extraData:(NSData *)extraData {
    NSUInteger length = extraData.length;
    Byte *data = malloc(1 + length);
    *data = (Byte)command;
    [extraData getBytes:data+1 length:length];
    [self sendData:[NSData dataWithBytesNoCopy:data
                                        length:length+1
                                  freeWhenDone:YES]];
}

- (void)sendData:(NSData*)newData {
    if (_connectionStatus == ConnectionStatusConnected) {
        //Output data to UART peripheral
        [currentPeripheral writeRawData:newData];
    } else {
        [[[UIAlertView alloc] initWithTitle:@"Not Connected"
                                    message:@"Need to connect first!"
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }
}

#pragma mark CBCentralManagerDelegate


- (void) centralManagerDidUpdateState:(CBCentralManager*)central {

    if (central.state == CBCentralManagerStatePoweredOn) {

        //respond to powered on
    }

    else if (central.state == CBCentralManagerStatePoweredOff) {

        //respond to powered off
    }

}


- (void) centralManager:(CBCentralManager*)central
  didDiscoverPeripheral:(CBPeripheral*)peripheral
      advertisementData:(NSDictionary*)advertisementData
                   RSSI:(NSNumber*)RSSI {

    NSLog(@"Did discover peripheral %@", peripheral.name);

    [cm stopScan];

    [self connectPeripheral:peripheral];
}


- (void) centralManager:(CBCentralManager*)central
   didConnectPeripheral:(CBPeripheral*)peripheral {

    if ([currentPeripheral.peripheral isEqual:peripheral]) {

        if(peripheral.services) {
            NSLog(@"Did connect to existing peripheral %@", peripheral.name);
            [currentPeripheral peripheral:peripheral didDiscoverServices:nil]; //already discovered services, DO NOT re-discover. Just pass along the peripheral.
        }

        else {
            NSLog(@"Did connect peripheral %@", peripheral.name);
            [currentPeripheral didConnect];
        }
    }
}


- (void) centralManager:(CBCentralManager*)central
didDisconnectPeripheral:(CBPeripheral*)peripheral
                  error:(NSError*)error {

    NSLog(@"Did disconnect peripheral %@", peripheral.name);

    //respond to disconnected
    [self peripheralDidDisconnect];

    if ([currentPeripheral.peripheral isEqual:peripheral])
    {
        [currentPeripheral didDisconnect];
    }
}


#pragma mark UARTPeripheralDelegate


- (void)didReadHardwareRevisionString:(NSString*)string {

    //Once hardware revision string is read, connection to Bluefruit is complete

    NSLog(@"Connected! HW Revision: %@", string);

    //Bail if we aren't in the process of connecting
    if (currentAlertView == nil){
        return;
    }

    self.connectionStatus = ConnectionStatusConnected;

    //Dismiss Alert view & update main view
    [currentAlertView dismissWithClickedButtonIndex:-1 animated:NO];
    currentAlertView = nil;
}


- (void)uartDidEncounterError:(NSString*)error {

    //Dismiss "scanning …" alert view if shown
    [currentAlertView dismissWithClickedButtonIndex:0 animated:NO];

    //Display error alert
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Error"
                                                   message:error
                                                  delegate:nil
                                         cancelButtonTitle:@"OK"
                                         otherButtonTitles:nil];

    [alert show];

}


- (void)didReceiveData:(NSData*)newData {

    //Data incoming from UART peripheral, forward to current view controller

    //Debug
    //    NSString *hexString = [newData hexRepresentationWithSpaces:YES];
    //    NSLog(@"Received: %@", newData);

    if (_connectionStatus == ConnectionStatusConnected || _connectionStatus == ConnectionStatusScanning) {

        // TODO

    }
}


- (void)peripheralDidDisconnect {

    //respond to device disconnecting

    //if we were in the process of scanning/connecting, dismiss alert
    if (currentAlertView != nil) {
        [self uartDidEncounterError:@"Peripheral disconnected"];
    }

    //display disconnect alert
    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"Disconnected"
                                                   message:@"BLE peripheral has disconnected"
                                                  delegate:nil
                                         cancelButtonTitle:@"OK"
                                         otherButtonTitles: nil];

    [alert show];

    self.connectionStatus = ConnectionStatusDisconnected;

    //make reconnection available after short delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _btnConnect.enabled = YES;
    });
}

#pragma mark UIAlertView delegate methods


- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{

    //the only button in our alert views is cancel, no need to check button index

    if (_connectionStatus == ConnectionStatusConnected) {
        [self disconnect];
    }
    else if (_connectionStatus == ConnectionStatusScanning){
        [cm stopScan];
    }

    self.connectionStatus = ConnectionStatusDisconnected;

    currentAlertView = nil;

    _btnConnect.enabled = YES;

    //alert dismisses automatically @ return
}

#pragma mark - ColorPickerImageViewDelegate

- (void)picker:(ColorPickerImageView*)picker pickedColor:(UIColor*)color {
    [UIView animateWithDuration:0.5
                     animations:^{
                         _pickerLens.alpha = 0.0;
                     }];

    Byte rgb[3];
    float r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    rgb[0] = (Byte)(r * 255.0);
    rgb[1] = (Byte)(g * 255.0);
    rgb[2] = (Byte)(b * 255.0);
    [self sendCommand:HatCommandSetColor extraData:[NSData dataWithBytes:rgb length:3]];
}

- (void)picker:(ColorPickerImageView*)picker touchedColor:(UIColor*)color inPoint:(CGPoint)point {
    if (color) {
        if (_pickerLens.alpha == 0.0f)
            [UIView animateWithDuration:0.2
                             animations:^{
                                 _pickerLens.alpha = 1.0;
                             }];

        point = [self.view convertPoint:point fromView:picker];
        _pickerLens.frame = CGRectMake(point.x - _pickerLens.frame.size.width / 2.0f,
                                       point.y - _pickerLens.frame.size.height,
                                       _pickerLens.frame.size.width,
                                       _pickerLens.frame.size.height);
        _pickerLens.color = color;
    } else {
        [UIView animateWithDuration:0.2
                         animations:^{
                             _pickerLens.alpha = 0.0;
                         }];
    }
}

@end
