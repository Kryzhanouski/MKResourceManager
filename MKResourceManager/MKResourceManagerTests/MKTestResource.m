//
//  MKTestResource.m
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 11/11/2011.
//  Copyright (c) 2011 Mark Kryzhanouski. All rights reserved.
//

#import "MKTestResource.h"

@implementation MKTestResource

+ (BOOL)canInitWithRequestURL:(NSURL*)aURL {
    NSString* absString = [aURL absoluteString];
    if ([absString isEqualToString:@"MKTestResource"] ||
        [absString isEqualToString:@"MKTestResourceFakeRun"]) {
        return YES;
    } else {
        return NO;
    }
}

- (void)startCustomDownload {
    NSString* fakeRunString = @"MKTestResourceFakeRun";
    NSString* absString = [self.resourceURL absoluteString];
    if ([absString isEqualToString:fakeRunString]) {
          // push this test to Downloaded state
        NSData* sampleData = [fakeRunString dataUsingEncoding:NSUTF8StringEncoding];
        [self didFinishDownloadMR:sampleData error:nil];
    }
}

- (void)cancelCustomDownload {
}

@end
