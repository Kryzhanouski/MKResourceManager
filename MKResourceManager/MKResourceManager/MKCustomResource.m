//
//  MKCustomResource.m
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 10/11/2011.
//  Copyright (c) 2011 Mark Kryzhanouski. All rights reserved.
//

#import "MKCustomResource.h"
#import "MKResource+Private.h"

@implementation MKCustomResource

+ (BOOL)canInitWithRequestURL:(NSURL*)anURL {
    [self doesNotRecognizeSelector:_cmd];
    return NO;
}

- (void)setExpectedContentLength:(long long)expectedContentLength {
    [super setExpectedContentLength:expectedContentLength];
}

- (void)startCustomDownload {
    [self doesNotRecognizeSelector:_cmd];
}

- (void)cancelCustomDownload {
    [self doesNotRecognizeSelector:_cmd];
}

- (void)setDownloadedLength:(NSUInteger)downloadedLength {
    [super setDownloadedLength:downloadedLength];
}

- (void)didFinishDownloadMR:(NSData*)data error:(NSError*)error {
    [self didFinishDownloadMR:data error:error httpResponse:nil];
}

- (void)didFinishDownloadMR:(NSData*)data error:(NSError*)error httpResponse:(NSHTTPURLResponse *)httpResponse {
    [super didFinishDownloadMR:data error:error httpResponse:httpResponse];
}

- (void)setContentType:(NSString*)contentType {
    [super setContentType:contentType];
}

@end
