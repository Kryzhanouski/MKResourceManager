//
//  MKMediaResourceManager+Private.h
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 1/14/11.
//  Copyright 2011 Mark Kryzhanouski. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import "MKHTTPHandlerClientPrivate.h"

@interface MKResourceManager ()

//- (void)setHttpClient:(id<MKHTTPHandlerClientPrivate>)client;
//- (id<MKHTTPHandlerClientPrivate>)httpClient;
- (void)startDownloadResource:(MKResource*)resource;
- (void)cancelDownloadResource:(MKResource*)resource;
- (NSData*)dataForResource:(MKResource *)resource error:(NSError**)error;
- (void)setData:(NSData*)data forResource:(MKResource*)resource;
- (void)didFinishDownloadResource:(MKResource *)resource data:(NSData *)data error:(NSError *)error httpResponse:(NSHTTPURLResponse*)httpResponse;
- (void)restoreResources;
- (BOOL)existMRinCache:(NSString*)stringURL;
- (NSString*)nameFromURLString:(NSString*)stringURL;
- (NSMutableData*)readMediaResourceFromCacheAtPath:(NSString*)stringURL;
- (NSString*)fullFilePath:(NSString*)stringURL;
- (void)saveInCache:(NSData*)data atPath:(NSString*)stringURL;
- (BOOL)removeResourceFromStorage:(MKResource*)aResource;

@end
