//
//  AESUtil.m
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 7.12.10.
//  Copyright 2010 Mark Kryzhanouski. All rights reserved.
//

#import "AESUtil.h"
#import <CommonCrypto/CommonCryptor.h>

@implementation AESUtil

+ (NSData*)decryptAES:(NSString*)aKey data:(NSData*)aData {
    if (aData == nil) {
        return nil;
    }
    
    NSMutableData* mutableData = [[NSMutableData alloc] initWithData:aData];
    char keyPointer[kCCKeySizeAES256 + 1];
    bzero (keyPointer, sizeof(keyPointer) );

    BOOL success = [aKey getCString:keyPointer maxLength:sizeof(keyPointer) encoding:NSUTF16StringEncoding];
    if (success || !success) {
        size_t numberOfEncryptedBytes = 0;
        
        NSUInteger dataLength = [mutableData length];
        
        size_t bufferSize = dataLength + kCCBlockSizeAES128;
        void* buffer_decrypt = malloc (bufferSize);
        if (buffer_decrypt != NULL) {
            NSMutableData* output_decrypt = nil;
            CCCryptorStatus cryptStatus = CCCrypt (kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                              keyPointer, kCCKeySizeAES256,
                                              NULL,
                                              [mutableData mutableBytes], [mutableData length],
                                              buffer_decrypt, bufferSize,
                                              &numberOfEncryptedBytes);
            
            output_decrypt = [NSMutableData dataWithBytesNoCopy:buffer_decrypt length:numberOfEncryptedBytes];
            if (cryptStatus == kCCSuccess) {
                return output_decrypt;
            }
        }
    }
    return NULL;
}

+ (NSData*)encryptAES:(NSString*)aKey data:(NSData*)aData {
    if (aData == nil) {
        return nil;
    }

    NSMutableData* mutableData = [[NSMutableData alloc] initWithData:aData];
    if (mutableData) {
        char keyPointer[kCCKeySizeAES256 + 1];
        bzero (keyPointer, sizeof(keyPointer) );
        
        BOOL success = [aKey getCString:keyPointer maxLength:sizeof(keyPointer) encoding:NSUTF16StringEncoding];
        if (success || !success) {
            size_t numberOfEncryptedBytes = 0;
            
            NSUInteger dataLength = [mutableData length];
            
            size_t bufferSize = dataLength + kCCBlockSizeAES128;
            void* buffer = malloc (bufferSize);
            
            if (buffer) {
                NSMutableData* outputData = nil;
                
                CCCryptorStatus cryptStatus = CCCrypt (kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                                  keyPointer, kCCKeySizeAES256,
                                                  NULL,
                                                  [mutableData mutableBytes], [mutableData length],
                                                  buffer, bufferSize,
                                                  &numberOfEncryptedBytes);
                
                outputData = [NSMutableData dataWithBytesNoCopy:buffer length:numberOfEncryptedBytes];
                if (cryptStatus == kCCSuccess) {
                    return outputData;
                }
            }
        }
    }
    return NULL;
}

@end
