//
//  MKResourceStatus+Private.h
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 1/13/11.
//  Copyright 2011 Mark Kryzhanouski. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MKResource.h"

@class MKResourceManager;

@interface MKResource ()

@property (nonatomic, strong)   NSDate* lastAccessDate;

- (id)initWithResourceManager:(MKResourceManager*)manager andURL:(NSURL*)aURL;
- (void)setExpectedContentLength:(long long)expectedContentLength;
- (void)setDownloadedLength:(NSUInteger)downloadedLength;
- (void)notifyDidCancelDownload;
- (void)notifyDidFinishDownload:(NSError*)error;
- (void)notifyWillStartDownload:(NSMutableURLRequest*)request;
- (void)didFinishDownloadMR:(NSData*)data error:(NSError*)error;
- (void)didFinishDownloadMR:(NSData*)data error:(NSError*)error httpResponse:(NSHTTPURLResponse *)httpResponse;
- (void)setStatus:(MKStatus)newStatus;
- (void)setResourceManager:(MKResourceManager*)manager;
- (void)setLoadedDate:(NSDate*)date;
- (void)setLastError:(NSError*)error;
- (void)setLastResponse:(NSHTTPURLResponse*)httpResponse;
- (void)setContentType:(NSString*)contentType;

@end
