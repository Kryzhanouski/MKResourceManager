//
//  MKResourceUtility.h
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 5/15/12.
//  Copyright (c) 2013 Mark Kryzhanouski. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MKResourceUtility : NSObject {
}

+ (NSString*)URLEscapeUnicode:(NSString*)aString;
+ (NSString*)URLEncode:(NSString*)aString;
+ (NSString*)URLDecode:(NSString*)aString;
+ (NSString*)XMLEncode:(NSString*)aString;
+ (NSString*)JSONEncode:(NSString*)aString;
+ (NSString*)base64Encode:(NSData*)anInputData onSeparateLines:(BOOL)separateLines;
+ (NSData*)base64Decode:(NSString*)anInputString;
+ (NSString*)MD5HashForString:(NSString*)anInputString;

+ (NSString*)stringFromStream:(NSInputStream*)stream encoding:(NSStringEncoding)encoding;

@end

NSString* MKTemporaryDirectory(void);
