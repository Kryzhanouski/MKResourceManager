//
//  AESUtil.h
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 7.12.10.
//  Copyright 2010 Mark Kryzhanouski. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AESUtil : NSObject {
}

+ (NSData*)decryptAES:(NSString*)key data:(NSData*)data;
+ (NSData*)encryptAES:(NSString*)key data:(NSData*)data;

@end
