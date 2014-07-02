//
//  MKResourceBuffer.m
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 9/25/12.
//  Copyright (c) 2012 Mark Kryzhanouski. All rights reserved.
//

#import "MKResourceBuffer.h"
#import "MKResourceUtility.h"

@implementation MKResourceBuffer
@synthesize dataFileName = _dataFileName;

+ (id)buffer {
    return [[self alloc] init];
}

- (id)init {
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)dealloc {
    [_outputStream close];
}

- (void)handleOutputStreamError {
    NSError* error = _outputStream.streamError;
    NSLog(@"Buffer error occured error: %@",error);//Error
    _outputStream = nil;
    _errorOccured = YES;
}

static NSUInteger maxLengthAllowedInMemory = 300 * 1024; // 300 * 1024 = 300 kb

- (NSOutputStream*)outputStreamForExpectedContentLength:(NSUInteger)expectedLength {
    if (_errorOccured) {
        return nil;
    }
    
    NSUInteger currLength = _length + expectedLength;
    
    if (currLength > maxLengthAllowedInMemory && self.dataFileName == nil) {
        NSData* inMemoryData = [_outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
        [_outputStream close];
        self.dataFileName = [MKTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"networkTemp%f",[NSDate timeIntervalSinceReferenceDate]]];
        _outputStream = [NSOutputStream outputStreamToFileAtPath:self.dataFileName append:NO];
        if (_outputStream.streamStatus == NSStreamStatusNotOpen) {
            [_outputStream open];
        }
        if ([inMemoryData length] > 0) {
            NSInteger writedButesLength = [_outputStream write:[inMemoryData bytes] maxLength:[inMemoryData length]];
            if (writedButesLength == -1) {
                [self handleOutputStreamError];
            }
        }
    } else if (_outputStream == nil) {
        _outputStream = [[NSOutputStream alloc] initToMemory];
        if (_outputStream.streamStatus == NSStreamStatusNotOpen) {
            [_outputStream open];
        }
    }
    
    return _outputStream;
}

- (void)appendData:(NSData*)data {
    NSUInteger expLength = [data length];
    NSOutputStream* output = [self outputStreamForExpectedContentLength:expLength];
    NSInteger writedButesLength = [output write:[data bytes] maxLength:expLength];
    if (writedButesLength == -1) {
        [self handleOutputStreamError];
    } else {
        _length += writedButesLength;
    }
}

- (NSUInteger)length {
    if (_errorOccured) {
        return 0;
    }
    return _length;
}

- (NSInputStream*)inputStream {
    if (_errorOccured) {
        return nil;
    }
    
    NSInputStream* inputStream = nil;
    if (self.dataFileName) { // in file stream
        [_outputStream close];
        inputStream = [NSInputStream inputStreamWithFileAtPath:self.dataFileName];
    } else {
        // In memory stream
        NSData* data = [_outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
        [_outputStream close];
        if (data) {
            inputStream = [NSInputStream inputStreamWithData:data];
        }
    }
    return inputStream;
}

- (NSData*)data {
    if (_errorOccured) {
        return nil;
    }
    
    NSData* data = nil;
    if (self.dataFileName) { // in file stream
        data = [NSData dataWithContentsOfFile:self.dataFileName];
    } else {
        // In memory stream
        data = [_outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
        [_outputStream close];
    }
    return data;
}

@end
