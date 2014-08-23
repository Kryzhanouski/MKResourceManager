//
//  MediaResourceDownloadWork.h
//  MKResourceManager
//
//  Created by Mark on 7.12.10.
//  Copyright 2010 Mark. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MKResourceManager.h"
#import "MKResourceBuffer.h"

@protocol MKHTTPHandlerClientPrivate;

@class MKResource;

@interface MKResourceDownloadWork : NSObject {
    MKResourceManager*          __weak _manager;
    MKResourceBuffer*                          _urlData;
    NSInteger                           _statusCode;
    NSURLConnection*                    _theConnection;
    MKResource*                        _resource;
}
@property (nonatomic, strong) MKResourceBuffer* urlData;
@property (nonatomic, strong) MKResource* resource;

- (void)startDownloadWork:(MKResource*)aResource manager:(MKResourceManager * )aManager httpClient:(id<MKHTTPHandlerClientPrivate>)httpClient;
- (void)cancelLoading;

@end
