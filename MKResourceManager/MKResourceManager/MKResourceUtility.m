//
//  MKResourceUtility.h
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 3/9/11.
//  Copyright (c) 2013 Mark Kryzhanouski. All rights reserved.
//

#import <objc/message.h>
#import <CommonCrypto/CommonDigest.h>

#import "MKResourceUtility.h"
#import "MKResourceUtility+Private.h"

// non-purgeable, non-backed up attributes
#import <sys/xattr.h>

#define BASE64_SIZE 4
#define BINARY_SIZE 3
#define INPUT_LINE_LENGTH ((64 / 4) * 3)
#define OUTPUT_LINE_LENGTH 64

static unsigned char encodingTable[64] = {
    'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T',
    'U','V','W','X','Y','Z','a','b','c','d','e','f','g','h','i','j','k','l','m','n',
    'o','p','q','r','s','t','u','v','w','x','y','z','0','1','2','3','4','5','6','7',
    '8','9','+','/'
};

static unsigned char Base64DecodeArray[256] = {
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
    65, 65, 65, 65, 65, 65, 65, 62, 65, 65, 65, 63, 52, 53, 54, 55, 56, 57,
    58, 59, 60, 61, 65, 65, 65, 65, 65, 65, 65,  0,  1,  2,  3,  4,  5,  6,
    7,  8,  9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
    25, 65, 65, 65, 65, 65, 65, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36,
    37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 65, 65, 65,
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
    65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65, 65,
    65, 65, 65, 65,
};

@implementation MKResourceUtility

/**
 * Escape unicode symbols in URL Format
 */
+ (NSString*)URLEscapeUnicode:(NSString*)aString {
    aString = (NSString*)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes (
        NULL,
        (CFStringRef)aString,
        NULL,
        NULL,
        kCFStringEncodingUTF8));

    return aString;
}

/**
 * Encode string in URL Format
 */
+ (NSString*)URLEncode:(NSString*)aString {
    aString = (NSString*)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes (
        NULL,
        (CFStringRef)aString,
        NULL,
        (CFStringRef)@"'@&/?%#+",
        kCFStringEncodingUTF8));

    return aString;
}

/**
 * Decode URL String
 */
+ (NSString*)URLDecode:(NSString*)aString {
    aString = (NSString*)CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapes (kCFAllocatorDefault,
                                                                     (CFStringRef)aString,
                                                                     CFSTR ("")));

    return aString;
}

+ (NSString*)XMLEncode:(NSString*)aString {
    return [[[[[aString stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"]
                stringByReplacingOccurrencesOfString:@"'" withString:@"&#39;"]
               stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"]
             stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"]
            stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
}

+ (NSString*)JSONEncode:(NSString*)aString {
    return [[[aString stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]
              stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
            stringByReplacingOccurrencesOfString:@"/" withString:@"\\/"];
}

/**
 * Encode string in base64
 */
+ (NSString*)base64Encode:(NSData*)anInputData onSeparateLines:(BOOL)aSeparateLines {
    const unsigned char* bytes = [anInputData bytes];
    unsigned int lineLength = 0;
    unsigned long ixtext = 0;
    NSMutableString* encodedString = [NSMutableString stringWithCapacity:[anInputData length]];
    unsigned long textLength = [anInputData length];
    long ctremaining = 0;
    unsigned char inbuf[3], outputBuffer[4];
    short counter = 0;
    short charsonline = 0, ctcopy = 0;
    unsigned long ix = 0;

    while (YES) {
        ctremaining = textLength - ixtext;
        if (ctremaining <= 0) {
            break;
        }

        for (counter = 0; counter < 3; counter++) {
            ix = ixtext + counter;
            if (ix < textLength) {
                inbuf[counter] = bytes[ix];
            } else {          inbuf [counter] = 0; }
        }

        outputBuffer [0] = (inbuf [0] & 0xFC) >> 2;
        outputBuffer [1] = ((inbuf [0] & 0x03) << 4) | ((inbuf [1] & 0xF0) >> 4);
        outputBuffer [2] = ((inbuf [1] & 0x0F) << 2) | ((inbuf [2] & 0xC0) >> 6);
        outputBuffer [3] = inbuf [2] & 0x3F;
        ctcopy = 4;

        switch (ctremaining) {
            case 1:
                ctcopy = 2;
                break;
            case 2:
                ctcopy = 3;
                break;
        }

        for (counter = 0; counter < ctcopy; counter++)
            [encodedString appendFormat:@"%c", encodingTable[outputBuffer[counter]]];

        for (counter = ctcopy; counter < 4; counter++)
            [encodedString appendFormat:@"%c",'='];

        ixtext += 3;
        charsonline += 4;

        if (lineLength > 0) {
            if (charsonline >= lineLength) {
                charsonline = 0;
                [encodedString appendString:@"\n"];
            }
        }
    }

    return encodedString;
}

/**
 * Decode base64 string
 */
+ (NSData*)base64Decode:(NSString*)anInputString {
    if ([anInputString length] <= 0) {
        return nil;
    }

    const char* inputBuffer = [anInputString cStringUsingEncoding:NSASCIIStringEncoding];
    NSUInteger length = [anInputString length];    
    size_t outBufLength = ((length + BASE64_SIZE - 1) / BASE64_SIZE) * BINARY_SIZE;

    NSData* data = nil;
    unsigned char* outputBuffer = (unsigned char*)malloc (outBufLength);
    if (outputBuffer != NULL) {
        size_t i = 0;
        size_t outlength = 0;
        while (i < length) {
            unsigned char tempBuffer[BASE64_SIZE] = {}; // {0,0,0,0}
            size_t index = 0;
            while (i < length) {
                unsigned char decodeValue = Base64DecodeArray[inputBuffer[i++]];
                
                if (decodeValue != 65) {
                    tempBuffer[index++] = decodeValue;
                    
                    if (index == BASE64_SIZE) {
                        break;
                    }
                }
            }
            
            outputBuffer[outlength] = (tempBuffer[0] << 2) | (tempBuffer[1] >> 4);
            outputBuffer[outlength + 1] = (tempBuffer[1] << 4) | (tempBuffer[2] >> 2);
            outputBuffer[outlength + 2] = (tempBuffer[2] << 6) | tempBuffer[3];
            
            outlength += index - 1;
        }
        
        if (outlength > 0) {
            data = [[NSData alloc] initWithBytes:outputBuffer length:outlength];
        }
    }
    free (outputBuffer);

    return data;
}

+ (NSString*)MD5HashForString:(NSString*)anInputString {
    const char* cString = [anInputString UTF8String];

    unsigned char chars[CC_MD5_DIGEST_LENGTH];

    CC_MD5 (cString, (unsigned int)strlen(cString), chars);

    return [NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            chars[0], chars[1],
            chars[2], chars[3],
            chars[4], chars[5],
            chars[6], chars[7],
            chars[8], chars[9],
            chars[10], chars[11],
            chars[12], chars[13],
            chars[14], chars[15]
    ];
}

#pragma mark - non-purgeable, non-backed up attributes
+ (void)markNonPurgeableNonBackedUpFileAtURL:(NSURL*)anURL {
    u_int8_t b = 1;
    setxattr ([[anURL path] fileSystemRepresentation], "com.apple.MobileBackup", &b, 1, 0, 0);
}

+ (NSString*)stringFromStream:(NSInputStream*)aStream encoding:(NSStringEncoding)anEncoding {
    NSMutableData* data = nil;
    if (aStream.streamStatus == NSStreamStatusNotOpen) {
        [aStream open];
    }
    while ([aStream hasBytesAvailable]) {
        if (!data) {
            data = [NSMutableData new];
        }
        uint8_t buffer[1024];
        unsigned long length = 0;
        length = [aStream read:buffer maxLength:1024];
        if (length) {
            [data appendBytes:(const void*)buffer length:length];
        }
    }

    NSString* string = nil;
    if (data) {
        string = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:anEncoding];
    }
    [aStream close];

    return string;
}

@end


NSString* MKTemporaryDirectory(void) {
    static NSString* const MKTempFolderName = @"MKResoureManagerTempFolder";
    static BOOL previousTempDirectoryWasCleaned = NO;
    static NSString* currentTemporaryDirectory = nil;
    static dispatch_once_t pred;

    if (previousTempDirectoryWasCleaned && currentTemporaryDirectory) {
        return currentTemporaryDirectory;
    }

    dispatch_once(&pred, ^{
        NSFileManager* ioManager = [NSFileManager defaultManager];
        NSString* trTempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:MKTempFolderName];
        BOOL fileExists = [ioManager fileExistsAtPath:trTempDir];
        NSError* error = nil;
        if (!fileExists) {
            [ioManager createDirectoryAtPath:trTempDir
                 withIntermediateDirectories:YES
                                  attributes:nil
                                       error:&error];
            
            if (error != nil) {
                NSLog(@"ERROR: MKTemporaryDirectory: cannot create temp folders base at path: '%@'",trTempDir);
            }
        } else if (previousTempDirectoryWasCleaned == NO) {
            NSArray* items = [ioManager contentsOfDirectoryAtPath:trTempDir error:&error];
            if (error != nil) {
                NSLog (@"ERROR: MKTemporaryDirectory: cannot clean temp folders base at path: '%@' because of an error %@", trTempDir, error);
            }
            for (NSString* item in items) {
                NSString* itemPath = [trTempDir stringByAppendingPathComponent:item];
                [ioManager removeItemAtPath:itemPath error:&error];
                if (error != nil) {
                    NSLog (@"ERROR: MKTemporaryDirectory: cannot clean temp folders base at path: '%@' because of an error %@", itemPath, error);
                }
            }
        }
        previousTempDirectoryWasCleaned = YES;
        
        if (currentTemporaryDirectory) {
            currentTemporaryDirectory = nil;
        }
        
        NSString* currentTempDir = [trTempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%f",[NSDate timeIntervalSinceReferenceDate]]];
        BOOL created = [ioManager createDirectoryAtPath:currentTempDir
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:&error];
        if (created) {
            currentTemporaryDirectory = currentTempDir;
        }
    });

    return currentTemporaryDirectory;
}
