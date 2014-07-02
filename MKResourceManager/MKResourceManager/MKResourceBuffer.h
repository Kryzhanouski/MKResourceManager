//
//  MKResourceBuffer.h
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 9/25/12.
//  Copyright (c) 2012 Mark Kryzhanouski. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MKResourceBuffer : NSObject {
@private
    BOOL                _errorOccured;
    NSUInteger          _length;
    NSOutputStream*     _outputStream;
}

@property (nonatomic, strong) NSString* dataFileName;

+ (id)buffer;
- (void)appendData:(NSData*)data;
- (NSUInteger)length;
- (NSInputStream*)inputStream;
- (NSData*)data;

@end