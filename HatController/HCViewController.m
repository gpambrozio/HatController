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
    HatCommandSetColor,
    HatCommandChangeMode,
    HatCommandSetBrightness,
    HatCommandSetCount,
} HatCommand;

typedef enum {
    AlertViewTagReset = 1,
} AlertViewTag;

@interface HCViewController ()

@property (nonatomic, assign) ConnectionStatus connectionStatus;

@property (nonatomic, strong) CBCentralManager *cm;
@property (nonatomic, strong) UARTPeripheral *currentPeripheral;

@property (nonatomic, strong) PTDBeanManager *beanManager;
@property (nonatomic, strong) PTDBean *bean;
@property (nonatomic, strong) NSMutableData *serialReceived;
@property (nonatomic, assign) BOOL notifyConnected;
@property (nonatomic, assign) BOOL notifyBatteryLow;

@property (nonatomic, assign) uint16_t count;

@property (weak, nonatomic) IBOutlet UIButton *btnConnect;
@property (weak, nonatomic) IBOutlet UILabel *lblStatus;
@property (weak, nonatomic) IBOutlet UILabel *lblError;
@property (weak, nonatomic) IBOutlet UITextField *txtBanner;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentMode;
@property (weak, nonatomic) IBOutlet ColorPickerImageView *pickerColor;
@property (weak, nonatomic) IBOutlet ColorPickerLens *pickerLens;
@property (weak, nonatomic) IBOutlet UILabel *lblBrightness;
@property (weak, nonatomic) IBOutlet UILabel *lblBattery;
@property (weak, nonatomic) IBOutlet UILabel *lblCount;
@property (weak, nonatomic) IBOutlet UILabel *lblAnalog;
@property (weak, nonatomic) IBOutlet UILabel *lblAverage;
@property (weak, nonatomic) IBOutlet UILabel *lblLoopNumber;
@property (weak, nonatomic) IBOutlet UILabel *lblNextPing;

@end

@implementation HCViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self.view setAutoresizesSubviews:YES];

    self.cm = [[CBCentralManager alloc] initWithDelegate:self queue:nil];

    self.connectionStatus = ConnectionStatusDisconnected;
    [self didTapConnect:nil];

    self.serialReceived = [[NSMutableData alloc] init];

    // instantiating the bean starts a scan. make sure you have you delegates implemented
    // to receive bean info
    self.notifyConnected = YES;
    self.notifyBatteryLow = YES;
    self.beanManager = [[PTDBeanManager alloc] initWithDelegate:self];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    if (self.bean) {
        [self.bean readBatteryVoltage];
        [self.bean readScratchBank:1];
    }
}

- (void)scanForPeripherals {
    //Look for available Bluetooth LE devices

    //skip scanning if UART is already connected
    NSArray *connectedPeripherals = [self.cm retrieveConnectedPeripheralsWithServices:@[UARTPeripheral.uartServiceUUID]];
    if ([connectedPeripherals count] > 0) {
        //connect to first peripheral in array
        [self connectPeripheral:[connectedPeripherals objectAtIndex:0]];
    }
    else {
        [self.cm scanForPeripheralsWithServices:@[UARTPeripheral.uartServiceUUID]
                                        options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@(NO)}];
    }
}

- (void)connectPeripheral:(CBPeripheral*)peripheral {
    //Connect Bluetooth LE device

    //Clear off any pending connections
    [self.cm cancelPeripheralConnection:peripheral];

    //Connect
    self.currentPeripheral = [[UARTPeripheral alloc] initWithPeripheral:peripheral
                                                               delegate:self];
    [self.cm connectPeripheral:peripheral
                       options:@{CBConnectPeripheralOptionNotifyOnDisconnectionKey:@(YES)}];

}

- (IBAction)didTapConnect:(id)sender {
    if (self.connectionStatus == ConnectionStatusDisconnected) {
        self.connectionStatus = ConnectionStatusScanning;
        [_btnConnect setTitle:@"Cancel" forState:UIControlStateNormal];

        [self scanForPeripherals];
    } else if (_connectionStatus == ConnectionStatusConnected) {
        self.connectionStatus = ConnectionStatusDisconnected;
        [_btnConnect setTitle:@"Connect" forState:UIControlStateNormal];

        [self.cm cancelPeripheralConnection:self.currentPeripheral.peripheral];
    } else if (_connectionStatus == ConnectionStatusScanning){
        self.connectionStatus = ConnectionStatusDisconnected;
        [_btnConnect setTitle:@"Connect" forState:UIControlStateNormal];

        [self.cm stopScan];
    }
}

- (IBAction)didTapSetText:(id)sender {
    [self sendText:_txtBanner.text];
    [_txtBanner resignFirstResponder];
    _txtBanner.text = @"";
}

- (IBAction)didTapPredefined:(UIButton *)sender {
    [self sendText:[sender titleForState:UIControlStateNormal]];
}

- (IBAction)didTapReset:(id)sender {
    UIAlertView *view = [[UIAlertView alloc] initWithTitle:@"Are you sure"
                                                   message:@"Sure you want to reset the count?"
                                                  delegate:self
                                         cancelButtonTitle:@"Cancel"
                                         otherButtonTitles:@"YEP!", nil];
    view.tag = AlertViewTagReset;
    [view show];
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
        [self.currentPeripheral writeRawData:newData];
    } else {
        _lblError.text = @"Need to connect first!";
    }
}

- (void)sendNotification:(NSString *)notificationText {
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertAction = @"Cool!";
    notification.alertBody = notificationText;
    notification.applicationIconBadgeNumber = _count;
    notification.soundName = UILocalNotificationDefaultSoundName;
    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
}

- (void)setStatus:(NSString *)status sendNotification:(BOOL)sendNotification {
    _lblError.text = status;
    NSLog(@"Status changed: %@", status);
    if (sendNotification) {
        [self sendNotification:status];
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

    [self.cm stopScan];

    [self connectPeripheral:peripheral];
}

- (void) centralManager:(CBCentralManager*)central
   didConnectPeripheral:(CBPeripheral*)peripheral {

    if ([self.currentPeripheral.peripheral isEqual:peripheral]) {

        if(peripheral.services) {
            NSLog(@"Did connect to existing peripheral %@", peripheral.name);
            [self.currentPeripheral peripheral:peripheral didDiscoverServices:nil]; //already discovered services, DO NOT re-discover. Just pass along the peripheral.
        }

        else {
            NSLog(@"Did connect peripheral %@", peripheral.name);
            [self.currentPeripheral didConnect];
        }
    }
}

- (void) centralManager:(CBCentralManager*)central
didDisconnectPeripheral:(CBPeripheral*)peripheral
                  error:(NSError*)error {

    NSLog(@"Did disconnect peripheral %@", peripheral.name);

    //respond to disconnected
    [self peripheralDidDisconnect];

    if ([self.currentPeripheral.peripheral isEqual:peripheral])
    {
        [self.currentPeripheral didDisconnect];
    }
}

#pragma mark UARTPeripheralDelegate

- (void)didReadHardwareRevisionString:(NSString*)string {

    //Once hardware revision string is read, connection to Bluefruit is complete

    NSLog(@"Connected! HW Revision: %@", string);

    //Bail if we aren't in the process of connecting
    if (self.connectionStatus != ConnectionStatusScanning) {
        return;
    }

    self.connectionStatus = ConnectionStatusConnected;
    [_btnConnect setTitle:@"Disconnect" forState:UIControlStateNormal];
}

- (void)uartDidEncounterError:(NSString*)error {
    //Display error alert
    _lblError.text = [NSString stringWithFormat:@"UART error: %@", error];
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
    if (self.connectionStatus == ConnectionStatusScanning) {
        _lblError.text = @"Peripheral disconnected";
    }

    //display disconnect alert
    _lblError.text = @"BLE peripheral has disconnected";

    self.connectionStatus = ConnectionStatusDisconnected;
    [_btnConnect setTitle:@"Connect" forState:UIControlStateNormal];

    //make reconnection available after short delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _btnConnect.enabled = YES;
    });
}

#pragma mark UIAlertView delegate methods

- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    switch (alertView.tag) {
        case AlertViewTagReset:
            if (buttonIndex == 1) {
                [self.bean sendSerialString:@"r"];
            }
            break;

        default:
            break;
    }
}

#pragma mark - ColorPickerImageViewDelegate

- (void)picker:(ColorPickerImageView*)picker pickedColor:(UIColor*)color {
    [UIView animateWithDuration:0.5
                     animations:^{
                         _pickerLens.alpha = 0.0;
                     }];

    Byte rgb[3];
    CGFloat r, g, b, a;
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

#pragma mark - BeanManagerDelegate Callbacks

- (void)beanManagerDidUpdateState:(PTDBeanManager *)manager {
    if (self.beanManager.state == BeanManagerState_PoweredOn) {
        [self.beanManager startScanningForBeans_error:nil];
    } else if (self.beanManager.state == BeanManagerState_PoweredOff) {
        _lblError.text = @"Turn on bluetooth to continue";
    }
}

- (void)BeanManager:(PTDBeanManager*)beanManager didDiscoverBean:(PTDBean*)bean error:(NSError*)error{
    [self.beanManager connectToBean:bean error:nil];
}

- (void)BeanManager:(PTDBeanManager*)beanManager didConnectToBean:(PTDBean*)bean error:(NSError*)error{
    if (error) {
        [self setStatus:[NSString stringWithFormat:@"Bean error: %@", error] sendNotification:NO];
        return;
    }

    [self.beanManager stopScanningForBeans_error:&error];
    if (error) {
        [self setStatus:[NSString stringWithFormat:@"Bean error: %@", error] sendNotification:NO];
        return;
    }
    self.bean = bean;
    self.bean.delegate = self;
    [self.bean readBatteryVoltage];
    [self.bean readScratchBank:1];
    [self setStatus:@"Bean connected!" sendNotification:self.notifyConnected];
    self.notifyConnected = NO;
}

- (void)BeanManager:(PTDBeanManager*)beanManager didDisconnectBean:(PTDBean*)bean error:(NSError*)error{
    self.bean = nil;
    [self.beanManager startScanningForBeans_error:nil];
    [self setStatus:[NSString stringWithFormat:@"Bean disconnected: %@", error] sendNotification:NO];
    __block UIBackgroundTaskIdentifier taskIdentifier = UIBackgroundTaskInvalid;
    void(^expirationHandler)() = ^{
        if (taskIdentifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:taskIdentifier];
            taskIdentifier = UIBackgroundTaskInvalid;
        }
    };

    taskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:expirationHandler];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.bean == nil) {
            [self sendNotification:[NSString stringWithFormat:@"Bean disconnected: %@", error]];
            self.notifyConnected = YES;
        }
        expirationHandler();
    });
}

#pragma mark BeanDelegate

-(void)bean:(PTDBean*)device error:(NSError*)error {
    [self setStatus:[NSString stringWithFormat:@"Bean error: %@", error] sendNotification:NO];
}

-(void)bean:(PTDBean*)device receivedMessage:(NSData*)data {

}

-(void)bean:(PTDBean*)bean didUpdateAccelerationAxes:(PTDAcceleration)acceleration {

}

-(void)bean:(PTDBean *)bean didUpdateLoopbackPayload:(NSData *)payload {

}

-(void)bean:(PTDBean *)bean didUpdateLedColor:(UIColor *)color {

}

-(void)bean:(PTDBean *)bean didUpdatePairingPin:(UInt16)pinCode {

}

-(void)bean:(PTDBean *)bean didUpdateTemperature:(NSNumber *)degrees_celsius {

}

-(void)bean:(PTDBean*)bean didUpdateRadioConfig:(PTDBeanRadioConfig*)config {

}

-(void)bean:(PTDBean *)bean didUpdateScratchNumber:(NSNumber *)number withValue:(NSData *)data {
    Byte *bytes = (Byte *)data.bytes;
    switch (number.intValue) {
        case 1:     // count
        {
            _count = bytes[0] + (bytes[1] << 8);
            uint16_t sensorValue = bytes[2] + (bytes[3] << 8);
            uint32_t sensorHistoryAvg = bytes[4] + (bytes[5] << 8) + (bytes[6] << 16) + (bytes[7] << 24);
            uint32_t loopCount = bytes[8] + (bytes[9] << 8) + (bytes[10] << 16) + (bytes[11] << 24);
            uint32_t nextPing = bytes[12] + (bytes[13] << 8) + (bytes[14] << 16) + (bytes[15] << 24);
            [UIApplication sharedApplication].applicationIconBadgeNumber = _count;
            _lblCount.text = [NSString stringWithFormat:@"%d", _count];
            _lblAnalog.text = [NSString stringWithFormat:@"%d", sensorValue];
            _lblAverage.text = [NSString stringWithFormat:@"%d", sensorHistoryAvg];
            _lblLoopNumber.text = [NSString stringWithFormat:@"%d", loopCount];
            _lblNextPing.text = [NSString stringWithFormat:@"%d", nextPing];
            if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self.bean readScratchBank:1];
                });
            }
            break;
        }

        default:
            break;
    }
}

- (void)beanDidUpdateBatteryVoltage:(PTDBean *)bean error:(NSError *)error {
    _lblBattery.text = [NSString stringWithFormat:@"%.2fV", bean.batteryVoltage.doubleValue];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.bean readBatteryVoltage];
    });
    if (bean.batteryVoltage.doubleValue < 2.10) {
        [self setStatus:[NSString stringWithFormat:@"Battery low: %.2fV", bean.batteryVoltage.doubleValue] sendNotification:self.notifyBatteryLow];
        self.notifyBatteryLow = NO;
    } else if (bean.batteryVoltage.doubleValue >= 2.50) {
        self.notifyBatteryLow = YES;
    }
}

- (void)bean:(PTDBean *)bean serialDataReceived:(NSData *)data {
    [self.serialReceived appendData:data];
    NSString *serialString = [[NSString alloc] initWithData:self.serialReceived encoding:NSUTF8StringEncoding];
    NSUInteger location;
    while ((location = [serialString rangeOfString:@"\r\n"].location) != NSNotFound) {
        NSString *substring = [serialString substringToIndex:location];
        NSLog(@"Received serial %@", substring);

        serialString = [serialString substringFromIndex:location + 2];
        NSArray *tokens = [substring componentsSeparatedByString:@":"];
        if (tokens.count == 2) {
            if ([tokens[0] isEqualToString:@"count"]) {
                _count = [tokens[1] integerValue];
                [UIApplication sharedApplication].applicationIconBadgeNumber = _count;
                [self sendCommand:HatCommandSetCount extraData:[NSData dataWithBytes:&_count length:sizeof(_count)]];

                _lblCount.text = [NSString stringWithFormat:@"%d", _count];

                [self sendNotification:[NSString stringWithFormat:@"%d hugs served and counting!", _count]];
            }

            else if ([tokens[0] isEqualToString:@"battery"]) {
                [self.bean readBatteryVoltage];
            }

            else if ([tokens[0] isEqualToString:@"ping"]) {
                [self setStatus:[NSString stringWithFormat:@"Got ping %@", tokens[1]] sendNotification:NO];
            }
        }
    }
    location = [self.serialReceived rangeOfData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]
                                        options:NSDataSearchBackwards
                                          range:NSMakeRange(0, self.serialReceived.length)].location;
    if (location != NSNotFound) {
        [self.serialReceived replaceBytesInRange:NSMakeRange(0, location + 2)
                                       withBytes:nil
                                          length:0];
    }
}

@end
