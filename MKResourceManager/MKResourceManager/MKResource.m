//
//  MKResourceStatus.m
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 1/13/11.
//  Copyright 2011 Mark Kryzhanouski. All rights reserved.
//

#import "MKResource.h"
#import "MKResource+Private.h"
#import "MKResourceManager.h"
#import "MKResourceManager+Private.h"


@interface MKResource ()
@end

@implementation MKResource
@synthesize status                  = _status;
@synthesize resourceURL             = _resourceURL;
@synthesize contentType             = _contentType;
@synthesize expectedContentLength   = _expectedContentLength;
@synthesize progress                = _progress;
@synthesize loadedDate              = _loadedDate;
@synthesize lastError               = _lastError;
@synthesize lastResponse            = _lastResponse;
@synthesize expirationPeriod        = _expirationPeriod;
@synthesize lastAccessDate          = _lastAccessDate;
@synthesize manager                 = _manager;

- (id)initWithResourceManager:(MKResourceManager*)manager andURL:(NSURL*)aURL {
    self = [super init];
    if (self != nil) {
        _watchers = [[NSMutableArray alloc] init];
        _completionHandlers = [[NSMutableArray alloc] init];
        _manager = manager;
        _resourceURL = [aURL copy];
        _expectedContentLength = 0;
        _progress = 0.0f;
        _expirationPeriod = -1.0;
        _lastAccessDate = [NSDate date];
    }
    return self;
}

#pragma mark -
#pragma mark implement NSCoding protocol
- (void)encodeWithCoder:(NSCoder*)aCoder {
    if ([aCoder isKindOfClass:[NSKeyedArchiver class]]) {
        NSKeyedArchiver* coder = (NSKeyedArchiver*)aCoder;
        [coder encodeInteger:_status forKey:@"status_"];
        [coder encodeObject:_resourceURL forKey:@"resourceURL_"];
        [coder encodeObject:[NSNumber numberWithLongLong:_expectedContentLength] forKey:@"expectedContentLength_"];
        [coder encodeObject:_loadedDate forKey:@"loadedDate_"];
        [coder encodeObject:_contentType forKey:@"contentType_"];
        [coder encodeDouble:_expirationPeriod forKey:@"expirationPeriod_"];
        [coder encodeObject:_lastAccessDate forKey:@"lastAccessDate_"];
    }
}

- (id)initWithCoder:(NSCoder*)aDecoder {
    self = [super init];
    if ([aDecoder isKindOfClass:[NSKeyedUnarchiver class]]) {
        NSKeyedUnarchiver* decoder = (NSKeyedUnarchiver*)aDecoder;
        _status = (MKStatus)[decoder decodeIntegerForKey:@"status_"];
        _resourceURL = [decoder decodeObjectForKey:@"resourceURL_"];
        _contentType = [decoder decodeObjectForKey:@"contentType_"];
        _expectedContentLength = [[decoder decodeObjectForKey:@"expectedContentLength_"] longLongValue];
        _loadedDate = [decoder decodeObjectForKey:@"loadedDate_"];
        _watchers = [[NSMutableArray alloc] init];
        _progress = 0.0f;
        _expirationPeriod = [decoder decodeDoubleForKey:@"expirationPeriod_"];
        _lastAccessDate = [decoder decodeObjectForKey:@"lastAccessDate_"];

        if (_status == MKStatusDownloaded) {
            _progress = 1.0f;
        }
    }
    return self;
}

#pragma mark end

- (void)setResourceManager:(MKResourceManager*)manager {
    _manager = manager;
}

- (void)setLoadedDate:(NSDate*)date {
    _loadedDate = date;

      // make sure that our last access date is at least as recent as loaded date
    self.lastAccessDate = _loadedDate;
}

- (void)setLastError:(NSError*)error {
    _lastError = error;
}

- (void)setLastResponse:(NSHTTPURLResponse*)httpResponse {
    _lastResponse = httpResponse;
}

- (void)setLastAccessDate:(NSDate*)lastAccessDate {
      // we shouldn't let to just change the last access date,
      // so the new value is always compared to the previous, and more recent is used
    NSDate* laterDate = nil;
    if (lastAccessDate != nil) {
        laterDate = [lastAccessDate laterDate:_lastAccessDate];
    }

    if (_lastAccessDate != laterDate) {
        _lastAccessDate = laterDate;
    }
}

- (NSData*)data {
    return [self data:nil];
}

- (NSData*)data:(NSError**)error {
	return [_manager dataForResource:self error:error];
}

- (void)setData:(NSData*)data {
    [_manager setData:data forResource:self];
}

- (void)startDownload {
    [_manager startDownloadResource:self];
}

- (void)cancelDownload {
    [_manager cancelDownloadResource:self];

    id<MKResourceStatusWatcher> watcher = nil;
    NSArray* watchers = [_watchers copy];
    for (NSValue* nonRetainedWacher in watchers) {
        watcher = (id<MKResourceStatusWatcher>)[nonRetainedWacher pointerValue];
        if ([watcher respondsToSelector:@selector(resourceDidCancelDownload:)]) {
            [watcher resourceDidCancelDownload:self];
        }
    }

    for (void (^completionHandler)(MKResource* resource, NSData* data, NSError* error) in _completionHandlers) {
        completionHandler(self, nil, nil);
    }
    [_completionHandlers removeAllObjects];
}

- (void)addWatcher:(id<MKResourceStatusWatcher>)watcher {
    NSValue* nonRetainedWatcher = [NSValue valueWithNonretainedObject:watcher];
    if (![_watchers containsObject:nonRetainedWatcher]) {
        [_watchers addObject:nonRetainedWatcher];
    }
}

- (void)removeWatcher:(id<MKResourceStatusWatcher>)watcher {
    NSValue* nonRetainedWatcher = [NSValue valueWithNonretainedObject:watcher];
    [_watchers removeObject:nonRetainedWatcher];
}

- (void)addCompletionHandler:(void (^)(MKResource* resource, NSData* data, NSError* error))completion {
    if (completion != NULL) {
        id blockCopy = [completion copy];
        [_completionHandlers addObject:blockCopy];
    }
}

- (NSArray*)watchers {
    return [NSArray arrayWithArray:_watchers];
}

- (void)setStatus:(MKStatus)newStatus {
    if (self.status == newStatus) {
        return;
    }

    _status = newStatus;

    if (_status == MKStatusNotDownloaded) {
        _progress = 0.0f;
        _expectedContentLength = 0;
        self.loadedDate = nil;
    }

    if (_status == MKStatusDownloaded) {
		_progress = 1.0f;
	}
	
    id<MKResourceStatusWatcher> watcher = nil;
    NSArray* watchers = [_watchers copy];
    for (NSValue* nonRetainedWacher in watchers) {
        watcher = (id<MKResourceStatusWatcher>)[nonRetainedWacher pointerValue];
        [watcher resourceStatusDidChange:self];
    }
}

- (void)setExpectedContentLength:(long long)expectedContentLength {
    _expectedContentLength = expectedContentLength;
}

- (void)setContentType:(NSString*)contentType {
    if (_contentType != contentType) {
        _contentType = [contentType copy];
    }
}

- (void)setDownloadedLength:(NSUInteger)downloadedLength {
    float progress = 0;

    if (_expectedContentLength != 0) {
        progress = downloadedLength / (double)_expectedContentLength;
    }

    _progress = progress;

    NSNumber* progressObj = [NSNumber numberWithFloat:progress];

    id<MKResourceStatusWatcher> watcher = nil;
    NSArray* watchers = [_watchers copy];
    for (NSValue* nonRetainedWacher in watchers) {
        watcher = (id<MKResourceStatusWatcher>)[nonRetainedWacher pointerValue];
        if ([watcher respondsToSelector:@selector(resource:loadProgressChanged:)]) {
            [watcher resource:self loadProgressChanged:progressObj];
        }
    }
}

- (void)notifyDidCancelDownload {
    
	id<MKResourceStatusWatcher> watcher = nil;
    NSArray* watchers = [_watchers copy];
	for (NSValue *nonRetainedWacher in watchers) {
		watcher = (id<MKResourceStatusWatcher>)[nonRetainedWacher pointerValue];
		if ([watcher respondsToSelector:@selector(resourceDidCancelDownload:)]) {
			[watcher resourceDidCancelDownload:self];
		}
	}
    
    for (void (^completionHandler)(MKResource* resource, NSData* data, NSError* error) in _completionHandlers) {
        completionHandler(self, nil, nil);
    }
    [_completionHandlers removeAllObjects];

}

- (void)notifyDidFinishDownload:(NSError*)error {

    id<MKResourceStatusWatcher> watcher = nil;
    NSArray* watchers = [_watchers copy];
    for (NSValue* nonRetainedWacher in watchers) {
        watcher = (id<MKResourceStatusWatcher>)[nonRetainedWacher pointerValue];
        if ([watcher respondsToSelector:@selector(resource:loadCompletedWithError:)]) {
            [watcher resource:self loadCompletedWithError:error];
        }
    }

    for (void (^completionHandler)(MKResource* resource, NSData* data, NSError* error) in _completionHandlers) {
        completionHandler(self, [self data], [self lastError]);
    }
    [_completionHandlers removeAllObjects];
}

- (void)notifyWillStartDownload:(NSMutableURLRequest*)request {
    
    id<MKResourceStatusWatcher> watcher = nil;
    NSArray* watchers = [_watchers copy];
    for (NSValue* nonRetainedWacher in watchers) {
        watcher = (id<MKResourceStatusWatcher>)[nonRetainedWacher pointerValue];
        if ([watcher respondsToSelector:@selector(resource:willSendRequest:)]) {
            [watcher resource:self willSendRequest:request];
        }
    }
}

- (void)didFinishDownloadMR:(NSData*)data error:(NSError*)error {
    [self didFinishDownloadMR:data error:error httpResponse:nil];
}

- (void)didFinishDownloadMR:(NSData*)data error:(NSError*)error httpResponse:(NSHTTPURLResponse *)httpResponse {
	[_manager didFinishDownloadResource:self data:data error:error httpResponse:(NSHTTPURLResponse *)httpResponse];
}

@end
