//
//  UARTPeripheral.m
//  nRF UART
//
//  Created by Ole Morten on 1/12/13.
//  Copyright (c) 2013 Nordic Semiconductor. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "UARTPeripheral.h"
#import "CBUUID+StringExtraction.h"

@interface UARTPeripheral ()

@property CBService *uartService;
@property CBCharacteristic *rxCharacteristic;
@property CBCharacteristic *txCharacteristic;

@end

@implementation UARTPeripheral

#pragma mark - UUID Retrieval


+ (CBUUID*)uartServiceUUID {
    
    return [CBUUID UUIDWithString:@"6e400001-b5a3-f393-e0a9-e50e24dcca9e"];
}


+ (CBUUID*)txCharacteristicUUID {
    
    return [CBUUID UUIDWithString:@"6e400002-b5a3-f393-e0a9-e50e24dcca9e"];
}


+ (CBUUID*)rxCharacteristicUUID {
    
    return [CBUUID UUIDWithString:@"6e400003-b5a3-f393-e0a9-e50e24dcca9e"];
}


+ (CBUUID*)deviceInformationServiceUUID {
    
    return [CBUUID UUIDWithString:@"180A"];
}


+ (CBUUID*)hardwareRevisionStringUUID {
    
    return [CBUUID UUIDWithString:@"2A27"];
}


#pragma mark - Utility methods


- (UARTPeripheral*)initWithPeripheral:(CBPeripheral*)peripheral
                             delegate:(id<UARTPeripheralDelegate>) delegate {
    
    if (self = [super init]) {
        self.peripheral = peripheral;
        self.peripheral.delegate = self;
        self.delegate = delegate;
    }
    return self;
}


- (void)didConnect {
    
    //Respond to peripheral connection
    
    if (_peripheral.services) {
        NSLog(@"Skipping service discovery for %@", _peripheral.name);
        [self peripheral:_peripheral didDiscoverServices:nil]; //already discovered services, DO NOT re-discover. Just pass along the peripheral.
        return;
    }
    
    NSLog(@"Starting service discovery for %@", _peripheral.name);
    
    [_peripheral discoverServices:@[self.class.uartServiceUUID, self.class.deviceInformationServiceUUID]];
}


- (void)didDisconnect {
    
    //Respond to peripheral disconnection
    
}


- (void)writeString:(NSString*)string {
    
    //Send string to peripheral
    
    NSData *data = [NSData dataWithBytes:string.UTF8String length:string.length];
    
    [self writeRawData:data];
}


- (void)writeRawData:(NSData*)data {
    
    //Send data to peripheral
    
    if ((self.txCharacteristic.properties & CBCharacteristicPropertyWriteWithoutResponse)) {
        
        [self.peripheral writeValue:data forCharacteristic:self.txCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }
    else if ((self.txCharacteristic.properties & CBCharacteristicPropertyWrite)) {
        [self.peripheral writeValue:data forCharacteristic:self.txCharacteristic type:CBCharacteristicWriteWithResponse];
    }
    else {
        NSLog(@"No write property on TX characteristic, %d.", (int)self.txCharacteristic.properties);
    }
    
}


- (BOOL)compareID:(CBUUID*)firstID toID:(CBUUID*)secondID {
    
    return ([[firstID representativeString] compare:[secondID representativeString]] == NSOrderedSame);
}


- (void)setupPeripheralForUse:(CBPeripheral*)peripheral {
    
    NSLog(@"Set up peripheral for use");
    
    for (CBService *s in peripheral.services) {
        
        for (CBCharacteristic *c in [s characteristics]) {
            
            if ([self compareID:c.UUID toID:self.class.rxCharacteristicUUID]) {
                
                NSLog(@"Found RX characteristic");
                self.rxCharacteristic = c;
                
                [self.peripheral setNotifyValue:YES forCharacteristic:self.rxCharacteristic];
            }
            
            else if ([self compareID:c.UUID toID:self.class.txCharacteristicUUID]) {
                
                NSLog(@"Found TX characteristic");
                self.txCharacteristic = c;
            }
            
            else if ([self compareID:c.UUID toID:self.class.hardwareRevisionStringUUID]) {
                
                NSLog(@"Found Hardware Revision String characteristic");
                [self.peripheral readValueForCharacteristic:c];
                
                //Once hardware revision string is read connection will be complete …
                
            }
            
        }

    }
    
}


#pragma mark - CBPeripheral Delegate methods


- (void)peripheral:(CBPeripheral*)peripheral didDiscoverServices:(NSError*)error {
    
    //Respond to finding a new service on peripheral
    
    NSLog(@"Did Discover Services");
    
    if (!error) {
        
        for (CBService *s in [peripheral services]){
            
            if (s.characteristics){
                [self peripheral:peripheral didDiscoverCharacteristicsForService:s error:nil]; //already discovered characteristic before, DO NOT do it again
            }
            
            else if ([self compareID:s.UUID toID:self.class.uartServiceUUID]){
                
                NSLog(@"Found correct service");
                
                self.uartService = s;
                
                [self.peripheral discoverCharacteristics:@[self.class.txCharacteristicUUID, self.class.rxCharacteristicUUID] forService:self.uartService];
            }
            
            else if ([self compareID:s.UUID toID:self.class.deviceInformationServiceUUID]){
                
                [self.peripheral discoverCharacteristics:@[self.class.hardwareRevisionStringUUID] forService:s];
            }
        }
    }
    
    else{
        
        NSLog(@"Error discovering services");
        
        [_delegate uartDidEncounterError:@"Error discovering services"];
        
        return;
    }
    
}


- (void)peripheral:(CBPeripheral*)peripheral
didDiscoverCharacteristicsForService:(CBService*)service error:(NSError*)error {
    
    //Respond to finding a new characteristic on service
    
    if (!error) {
        
        CBService *s = [peripheral.services objectAtIndex:(peripheral.services.count - 1)];
        if ([self compareID:service.UUID toID:s.UUID]) {
            
            //last service discovered
            NSLog(@"Found all characteristics");
            
            [self setupPeripheralForUse:peripheral];
            
        }
        
    }
    
    else {
        
        NSLog(@"Error discovering characteristics: %@", error.description);
        
        [_delegate uartDidEncounterError:@"Error discovering characteristics"];
        
        return;
    }
    
}


- (void)peripheral:(CBPeripheral*)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic*)characteristic error:(NSError*)error {
    
    //Respond to value change on peripheral
    
    if (!error) {
        if (characteristic == self.rxCharacteristic) {
            
            NSLog(@"Received: %@", [characteristic value]);
            
            [self.delegate didReceiveData:[characteristic value]];
        }
        
        else if ([self compareID:characteristic.UUID toID:self.class.hardwareRevisionStringUUID]) {
            
            NSString *hwRevision = @"";
            const uint8_t *bytes = characteristic.value.bytes;
            for (int i = 0; i < characteristic.value.length; i++) {
                
                hwRevision = [hwRevision stringByAppendingFormat:@"0x%x, ", bytes[i]];
            }
            
            [self.delegate didReadHardwareRevisionString:[hwRevision substringToIndex:hwRevision.length-2]];
        }
    }
    
    else {
        
        NSLog(@"Error receiving notification for characteristic %@: %@", characteristic.description, error.description);
        
        [_delegate uartDidEncounterError:@"Error receiving notification for characteristic"];
        
        return;
    }
    
}

@end
