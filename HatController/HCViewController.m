//
//  HCViewController.m
//  HatController
//
//  Created by Gustavo Ambrozio on 8/1/14.
//  Copyright (c) 2014 Gustavo Ambrozio. All rights reserved.
//

#import "HCViewController.h"


typedef enum {
    ConnectionStatusDisconnected = 0,
    ConnectionStatusScanning,
    ConnectionStatusConnected,
} ConnectionStatus;

@interface HCViewController () {
    CBCentralManager    *cm;
    UARTPeripheral      *currentPeripheral;
    UIAlertView         *currentAlertView;
}

@property (nonatomic, assign) ConnectionStatus connectionStatus;
@property (weak, nonatomic) IBOutlet UIButton *btnConnect;

@end

@implementation HCViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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

    _connectionStatus = ConnectionStatusDisconnected;

    [cm cancelPeripheralConnection:currentPeripheral.peripheral];

}

- (IBAction)didTapConnect:(id)sender {
    _connectionStatus = ConnectionStatusScanning;

    _btnConnect.enabled = NO;

    [self scanForPeripherals];

    currentAlertView = [[UIAlertView alloc]initWithTitle:@"Scanning …"
                                                 message:nil
                                                delegate:self
                                       cancelButtonTitle:@"Cancel"
                                       otherButtonTitles:nil];

    [currentAlertView show];
    
}

#pragma mark CBCentralManagerDelegate


- (void) centralManagerDidUpdateState:(CBCentralManager*)central {

    if (central.state == CBCentralManagerStatePoweredOn){

        //respond to powered on
    }

    else if (central.state == CBCentralManagerStatePoweredOff){

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

    NSLog(@"HW Revision: %@", string);

    //Bail if we aren't in the process of connecting
    if (currentAlertView == nil){
        return;
    }

    _connectionStatus = ConnectionStatusConnected;

    //Dismiss Alert view & update main view
    [currentAlertView dismissWithClickedButtonIndex:-1 animated:NO];

    NSLog(@"CONNECTED WITH NO CONNECTION MODE SET!");

    currentAlertView = nil;
}


- (void)uartDidEncounterError:(NSString*)error {

    //Dismiss "scanning …" alert view if shown
    if (currentAlertView != nil) {
        [currentAlertView dismissWithClickedButtonIndex:0 animated:NO];
    }

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

    _connectionStatus = ConnectionStatusDisconnected;

    //make reconnection available after short delay
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _btnConnect.enabled = YES;
    });
}


@end
