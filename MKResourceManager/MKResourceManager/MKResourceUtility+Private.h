
#import <Foundation/Foundation.h>

@interface MKResourceUtility (Private)

+ (NSString*)acceptType;
+ (NSString*)contentType;
+ (NSString*)requestGet;
+ (NSString*)entityNameFromType:(NSString*)aType;
+ (NSString*)entityNameFromURL:(NSString*)aURL;
+ (NSString*)propertyName:(NSString*)aRawProperty;
+ (NSInteger)reverseFindRequiredString:(NSString*)aSourceString withinSource:(NSString*)aFindString;
+ (NSString*)entitySetFromURL:(NSString*)aURL;
+ (NSString*)entitySetNameWithEntityIDFromURL:(NSString*)aURL;
+ (NSString*)unescapedEntitySetNameWithEntityIDFromURL:(NSString*)aURL;
+ (NSString*)unescapedEntityIDWithBracesFromURL:(NSString*)aURL;
+ (void)writeLine:(NSString*)aLine inStream:(NSMutableString*)aStream;
+ (BOOL)HTTPSuccessCode:(NSNumber*)anHTTPCode;
+ (NSString*)createURI:(NSString*)aBaseURI requestURI:(NSString*)aRequestURI;
+ (NSString*)timeInISO8601;
+ (BOOL)isAbsoluteURL:(NSString*)aURL;
+ (NSMutableDictionary*)createHeaders:(NSString*)aMethodType eTag:(NSString*)anETag oDataServiceVersion:(NSString*)dataServiceVersion;

// takes a path to a file and marks it as non-purgeable, non-backed up so that the OS does not accidentally remove it
+ (void)markNonPurgeableNonBackedUpFileAtURL:(NSURL*)aURL;

@end
