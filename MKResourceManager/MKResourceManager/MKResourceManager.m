//
//  MKResourceManager.m
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 7.12.10.
//  Copyright 2010 Mark Kryzhanouski. All rights reserved.
//

#import "MKResourceManager.h"
#import "MKResourceManager+Private.h"
#import "AESUtil.h"
#import "MKResource+Private.h"
#import "MKResourceUtility.h"
#import "MKResourceUtility+Private.h"
#import "MKCustomResource.h"

NSString* const MKMediaResourceSavedResourcesFileName           = @"ResourceInfo.plist";
NSUInteger const MKMediaResourceMaxConcurrentDownloadsCount     = 10;


@interface MKResourceManager () <NSURLSessionDelegate> {
    id<MKHTTPHandlerClientPrivate> _httpClient;
}
@property (nonatomic, strong) NSURLSession* URLSession;
@property (nonatomic, strong) CompletionHandlerType backgroundSessionCompletionHandler;
@property (nonatomic, strong) NSString* backgroundSessionIdentifier;
@end


@implementation MKResourceManager

@synthesize pathCache = _pathCache;

- (id)initWithKey:(NSString*)aKeyEncoding pathCache:(NSString*)path {
    return [self initWithKey:aKeyEncoding pathCache:path supportBackgroundLoading:YES];
}

- (id)initWithKey:(NSString*)aKeyEncoding pathCache:(NSString*)path supportBackgroundLoading:(BOOL)support
{
    self = [super init];
    if (self != nil) {
        _workDictionary = [[NSMutableDictionary alloc] init];
        _statusByURL = [[NSMutableDictionary alloc] init];
        _keyEncoding = [aKeyEncoding copy];
        _pathCache = [path copy];
        _customSchemesHandlers = [[NSMutableArray alloc] init];
        _suspendedResources = [[NSMutableArray alloc] init];
        _downloadResourcesQueue = [[NSMutableArray alloc] init];
		_suspended = YES;
        _saveResourceInfoQueue = dispatch_queue_create("MKResourceManager save resource info queue", NULL);
        _maxConcurrentDownloadsCount = MKMediaResourceMaxConcurrentDownloadsCount;
        
        NSURLSessionConfiguration *configObject = nil;
        if (support) {
            self.backgroundSessionIdentifier = [NSString stringWithFormat:@"%f",[NSDate timeIntervalSinceReferenceDate]];
            configObject = [NSURLSessionConfiguration backgroundSessionConfiguration:self.backgroundSessionIdentifier];
        }
        else {
            configObject = [NSURLSessionConfiguration defaultSessionConfiguration];
        }
        self.URLSession = [NSURLSession sessionWithConfiguration:configObject delegate:self delegateQueue:[NSOperationQueue mainQueue]];
        
        BOOL isDir = YES;
        NSFileManager* fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:_pathCache isDirectory:&isDir]) {
            [fileManager createDirectoryAtPath:_pathCache withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        [self restoreResources];
    }
    return self;
}

- (void)dealloc {
    [self suspend];
    for (MKResource* resource in [_statusByURL allValues]) {
        [resource setResourceManager:nil];
    }
}

- (void)setHttpClient:(id<MKHTTPHandlerClientPrivate>)client {
    _httpClient = client;
}

- (id<MKHTTPHandlerClientPrivate>)httpClient {
    return _httpClient;
}


- (void)suspend {
    _suspended = YES;
    for (NSURLSessionDownloadTask* downloadTask in [_workDictionary allValues]) {
        [downloadTask suspend];
//        MKResource* resource = [self resourceForNSURL:downloadTask.originalRequest.URL];
//        [self cancelDownloadResource:resource];
    }
}

- (void)resume {
    _suspended = NO;
    for (NSURLSessionDownloadTask* downloadTask in [_workDictionary allValues]) {
        [downloadTask resume];
    }
    for (MKResource* resource in _suspendedResources) {
        [self startDownloadResource:resource];
    }
    [_suspendedResources removeAllObjects];
}

- (NSArray*)validateResources:(NSArray*)resources {
    NSMutableArray* validResources = [NSMutableArray array];
    NSString* pathToResource = nil;
    BOOL isDirectory = NO;
    BOOL fileExists = NO;
    
    for (MKResource* res in resources) {
        pathToResource = [self fullFilePath:[res.resourceURL absoluteString]];
        fileExists = [[NSFileManager defaultManager] fileExistsAtPath:pathToResource isDirectory:&isDirectory];
        
        if (!isDirectory && fileExists) {
            // now check for resource's expiration time; lastAccessDate should be earlier, so multiply by -1.0
            NSTimeInterval passedPeriod = [res.lastAccessDate timeIntervalSinceNow] * -1.0;
            if (res.expirationPeriod > 0.0 &&
                passedPeriod >= res.expirationPeriod) {
                // only resources with expiration period greater than 0.0 are cleaned;
                // this resource should be removed if passed period is greater than resource's expiration period
                [self removeResourceFromStorage:res];
            } else {
                [validResources addObject:res];
            }
        }
    }
    
    return [NSArray arrayWithArray:validResources];
}

- (void)restoreResources {
    NSString* resourceInfoPath = [self.pathCache stringByAppendingPathComponent:MKMediaResourceSavedResourcesFileName];
    
    NSData* data = [NSData dataWithContentsOfFile:resourceInfoPath];
    NSArray* restoredResources = data == nil ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    NSArray* validatedResources = [self validateResources:restoredResources];
    
    for (MKResource* resource in validatedResources) {
        [resource setResourceManager:self];
        [_statusByURL setObject:resource forKey:[resource.resourceURL absoluteString]];
    }
}

- (void)saveResourcesInfo {
    float minTimeIntervalBetweenSavings = 5; //In seconds
    
    double currentInterval = [NSDate timeIntervalSinceReferenceDate] - _lastTimeWhenResourceInfoSaved;
    if (currentInterval < minTimeIntervalBetweenSavings) {
        if (!_saveDalayed) {
            [self performSelector:@selector(saveResourcesInfo) withObject:nil afterDelay:minTimeIntervalBetweenSavings];
            _saveDalayed = YES;
        }
        return;
    }
    
    NSString* resourceInfoPath = [self.pathCache stringByAppendingPathComponent:MKMediaResourceSavedResourcesFileName];
    NSMutableArray* resourcesToSave = [NSMutableArray array];
    
    for (MKResource* resource in [_statusByURL allValues]) {
        if (resource.status == MKStatusDownloaded) {
            [resourcesToSave addObject:resource];
        }
    }
    
    dispatch_async(_saveResourceInfoQueue, ^{
        NSData* data = [NSKeyedArchiver archivedDataWithRootObject:resourcesToSave];
        BOOL achivresult = [data writeToFile:resourceInfoPath atomically:YES];
        if (!achivresult) {
            NSLog(@"%@: Fail to save Resource Info at path: %@", NSStringFromClass ([self class]), resourceInfoPath);//Error
        } else {
            // successfully saved; apply attributes
            NSURL* fileURL = [NSURL fileURLWithPath:resourceInfoPath];
            [MKResourceUtility markNonPurgeableNonBackedUpFileAtURL:fileURL];
        }
    });
    
    _lastTimeWhenResourceInfoSaved = [NSDate timeIntervalSinceReferenceDate];
    _saveDalayed = NO;
}

- (void)enqueueResource:(MKResource*)resource {
    [_downloadResourcesQueue addObject:resource];
    [self downloadResourceQueueChanged];
}

- (void)dequeueResource:(MKResource*)resource {
    [self downloadResourceQueueChanged];
}

- (void)downloadResourceQueueChanged {
    if ([[_workDictionary allValues] count] >= self.maxConcurrentDownloadsCount) {
        return;
    }
    
    MKResource* resource = nil;
    if ([_downloadResourcesQueue count] > 0) {
        resource = [_downloadResourcesQueue objectAtIndex:0];
        [_downloadResourcesQueue removeObject:resource];
    }
    
    if (resource == nil) {
        return;
    }
    
    if ([resource isKindOfClass:[MKCustomResource class]]) {
        [(MKCustomResource*)resource startCustomDownload];
    } else {
        NSMutableURLRequest *dataRequest = [NSMutableURLRequest requestWithURL:resource.resourceURL cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:60];

        NSURLSessionDownloadTask* downloadTask = [self.URLSession downloadTaskWithRequest:dataRequest];
        
        if (downloadTask == nil) {
            [resource didFinishDownloadMR:nil error:nil httpResponse:nil];
        } else {
            NSLog(@"Start loading url:%@", resource.resourceURL);//Info
        }
        
        [_workDictionary setObject:downloadTask forKey:[resource.resourceURL absoluteString]];
 
        [downloadTask resume];
        
        //        [[MKNetworkActivity sharedInstance] incrementLoadingItems];
    }
}

- (void)startDownloadResource:(MKResource*)resource {
    if (resource != nil) {
        if (_suspended) {
            [_suspendedResources addObject:resource];
        } else {
            resource.lastAccessDate = [NSDate date];
            [resource setLastError:nil];
            [resource setStatus:MKStatusInProgress];
            [self enqueueResource:resource];
        }
    }
}

- (void)cancelDownloadResource:(MKResource*)resource {
    if (resource != nil && resource.status == MKStatusInProgress) {
        resource.lastAccessDate = [NSDate distantPast];
        if ([resource isKindOfClass:[MKCustomResource class]]) {
            [(MKCustomResource*) resource cancelCustomDownload];
        } else {
            //            [[MKNetworkActivity sharedInstance] decrementLoadingItems];
            NSURLSessionDownloadTask* downloadTask = [_workDictionary objectForKey:[resource.resourceURL absoluteString]];
            [downloadTask cancel];
            [_workDictionary removeObjectForKey:[resource.resourceURL absoluteString]];
        }
        
        if (_suspended) {
            [_suspendedResources addObject:resource];
        } else {
            [resource setStatus:MKStatusNotDownloaded];
            [resource notifyDidCancelDownload];
            [self dequeueResource:resource];
        }
    }
}

//- (void)didFinishDownloadResource:(MKResource *)resource data:(NSData *)data error:(NSError *)error {
//    [self didFinishDownloadResource:resource data:data error:error httpResponse:nil];
//}
//
- (void)didFinishDownloadResource:(MKResource *)resource dataFileURL:(NSURL*)dataFileURL error:(NSError *)error httpResponse:(NSHTTPURLResponse*)httpResponse {
    [_workDictionary removeObjectForKey:[resource.resourceURL absoluteString]];
    if ([resource isKindOfClass:[MKCustomResource class]] == NO) {
        //        [[MKNetworkActivity sharedInstance] decrementLoadingItems];
    }
    
    if (_suspended || [error code] == 401) {
        [_suspendedResources addObject:resource];
    } else {
        if (error == nil) {
            resource.loadedDate = [NSDate date];
        }
        [resource setLastError:error];
        [resource setLastResponse:httpResponse];
        [self setDataFromFileAtURL:dataFileURL forResource:resource];
        [resource notifyDidFinishDownload:error];
        [self dequeueResource:resource];
    }
}

- (NSData*)dataForResource:(MKResource *)resource error:(NSError**)error {
    NSData* decryptedData = nil;
    
    if (_suspended == NO) {
        if (resource != nil &&
            resource.status == MKStatusDownloaded) {
            if ([self existMRinCache:[resource.resourceURL absoluteString]]) {
                NSMutableData* data = [self readMediaResourceFromCacheAtPath:[resource.resourceURL absoluteString]];
                //                decryptedData = [AESUtil decryptAES:_keyEncoding data:data];
                decryptedData = data;
                resource.lastAccessDate = [NSDate date];
            }
        }
    } else {
        if (error != NULL) {
            NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Access denied",NSLocalizedFailureReasonErrorKey, nil];
            *error = [NSError errorWithDomain:@"MKResourceManagerErrorDomain" code:60 userInfo:userInfo];
        }
    }
    
    return decryptedData;
}

- (void)setData:(NSData*)data forResource:(MKResource*)resource {
    NSURL* tempFileUrl = nil;
    if (data) {
        NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%f",[NSDate timeIntervalSinceReferenceDate]]];
        tempFileUrl = [NSURL fileURLWithPath:tempFile];
        [data writeToURL:tempFileUrl atomically:YES];
    }
    [self setDataFromFileAtURL:tempFileUrl forResource:resource];
}

- (void)setDataFromFileAtURL:(NSURL*)dataFileURL forResource:(MKResource*)resource {
    if (resource != nil) {
        
        resource.lastAccessDate = [NSDate date];
        if (dataFileURL == nil && [self existMRinCache:[resource.resourceURL absoluteString]] == NO) {
            [resource setStatus:MKStatusNotDownloaded];
        } else {
            if (dataFileURL) {
                [self saveInCacheDataFromFileAtURL:dataFileURL atPath:[resource.resourceURL absoluteString]];
            }
            [resource setStatus:MKStatusDownloaded];
            [self saveResourcesInfo];
        }
    }
}

- (void)saveInCacheDataFromFileAtURL:(NSURL*)dataFileURL atPath:(NSString*)stringURL {
    NSString* fullURLString = [self fullFilePath:stringURL];
    NSURL* fileURL = [NSURL fileURLWithPath:fullURLString];
    //    [[AESUtil encryptAES:_keyEncoding data:data] writeToFile:fullURLString atomically:YES];
    
    NSError *err = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager moveItemAtURL:dataFileURL toURL:fileURL error: &err]) {
        /* Store some reference to the new URL */
    } else {
        /* Handle the error. */
    }
    // also add attributes
    [MKResourceUtility markNonPurgeableNonBackedUpFileAtURL:fileURL];
}

- (NSMutableData*)readMediaResourceFromCacheAtPath:(NSString*)stringURL {
    return [NSMutableData dataWithData:[NSData dataWithContentsOfFile:[self fullFilePath:stringURL]]];
}

- (BOOL)existMRinCache:(NSString*)stringURL {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self fullFilePath:stringURL]];
}

// Method used for backward compotibiliti with previous AccessLibrary versions naming scheme
- (NSString*)oldNameFromURLString:(NSString*)stringURL {
    NSString* nameFromUrl = [stringURL stringByReplacingOccurrencesOfString:@"/" withString:@""];
    nameFromUrl = [nameFromUrl stringByReplacingOccurrencesOfString:@":" withString:@""];
    return nameFromUrl;
}

- (NSString*)oldFullFilePath:(NSString*)stringURL {
    NSString* fileName = [self oldNameFromURLString:stringURL];
    return [_pathCache stringByAppendingPathComponent:fileName];
}

- (NSString*)nameFromURLString:(NSString*)stringURL {
    NSString* nameFromUrl = [MKResourceUtility MD5HashForString:stringURL];
    return nameFromUrl;
}

- (NSString*)fullFilePath:(NSString*)stringURL {
    NSString* fileName = [self nameFromURLString:stringURL];
    return [_pathCache stringByAppendingPathComponent:fileName];
}

- (MKResource*)tryToFindAndMigrateResourceInCacheWithOldNamingSchemeForNSURL:(NSURL*)aURL {
    
    NSString* urlAbsoluteString = [aURL absoluteString];
    BOOL isDirectory = NO;
    BOOL exists = NO;
    MKResource* findedResource = nil;
    
    NSString* oldPathToResource = [self oldFullFilePath:urlAbsoluteString];
    exists = [[NSFileManager defaultManager] fileExistsAtPath:oldPathToResource isDirectory:&isDirectory];
    
    if (!isDirectory && exists) {
        findedResource = [[MKResource alloc] initWithResourceManager:self andURL:aURL];
        [_statusByURL setObject:findedResource forKey:urlAbsoluteString];
        NSString* newPathToResource = [self fullFilePath:urlAbsoluteString];
        [[NSFileManager defaultManager] copyItemAtPath:oldPathToResource toPath:newPathToResource error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:oldPathToResource error:nil];
    }
    return findedResource;
}

- (MKResource*)resourceForNSURL:(NSURL*)aURL {
    if (aURL == nil) {
        return nil;
    }
    
    MKResource* resource = [_statusByURL objectForKey:[aURL absoluteString]];
    
    //need to find resources with old naming scheme
    if (resource == nil) {
        resource = [self tryToFindAndMigrateResourceInCacheWithOldNamingSchemeForNSURL:aURL];
    }
    
    if (resource == nil) {
        BOOL customHandlerFound = NO;
        Class handlerClass = Nil;
        for (Class customClass in _customSchemesHandlers) {
            customHandlerFound = [customClass canInitWithRequestURL:aURL];
            if (customHandlerFound) {
                handlerClass = customClass;
                break;
            }
        }
        if (!customHandlerFound) {
            handlerClass = [MKResource class];
        }
        resource = [[handlerClass alloc] initWithResourceManager:self andURL:aURL];
        [_statusByURL setObject:resource forKey:[aURL absoluteString]];
    }
    
    resource.lastAccessDate = [NSDate date];
    
    return resource;
}

- (MKResource*)downloadResourceForNSURL:(NSURL*)aURL {
    MKResource* resource = [self resourceForNSURL:aURL];
    
    [self startDownloadResource:resource];
    
    return resource;
}

- (MKResource*)cancelDownloadResourceForNSURL:(NSURL*)aURL {
    MKResource* resource = [self resourceForNSURL:aURL];
    
    [self cancelDownloadResource:resource];
    
    return resource;
}

- (NSData*)dataForResourceForNSURL:(NSURL*)aURL {
    return [self dataForResourceForNSURL:aURL error:nil];
}

- (NSData *)dataForResourceForNSURL:(NSURL *)aURL error:(NSError**)error {
    MKResource* resource = [self resourceForNSURL:aURL];
	NSData* data = [self dataForResource:resource error:error];
    return data;
}

- (NSURL*)pathForResource:(MKResource*)resource {
    return [NSURL fileURLWithPath:[self fullFilePath:[resource.resourceURL absoluteString]]];
}

- (void)setData:(NSData*)data forResourceForNSURL:(NSURL*)aURL {
    MKResource* resource = [self resourceForNSURL:aURL];
    [self setData:data forResource:resource];
}

- (BOOL)removeResourceForNSURL:(NSURL*)aURL {
    BOOL result = YES;
    MKResource* resource = [self resourceForNSURL:aURL];
    
    if (resource.status == MKStatusDownloaded) {
        result = [self removeResourceFromStorage:resource];
    }
    
    return result;
}

- (BOOL)removeResourceFromStorage:(MKResource*)aResource {
    BOOL result = NO;
    NSError* error = nil;
    NSString* pathToResource = [self fullFilePath:[aResource.resourceURL absoluteString]];
    [[NSFileManager defaultManager] removeItemAtPath:pathToResource error:&error];
    
    if (error != nil) {
        result = NO;
        NSLog(@"%@: Fail to remove file at path: %@, %@", NSStringFromClass ([self class]), pathToResource, [error localizedDescription]);//Error
    } else {
        result = YES;
        [aResource setStatus:MKStatusNotDownloaded];
    }
    return result;
}

- (void)removeWatcherFromAllResources:(id<MKResourceStatusWatcher>)resourceWatcher {
    for (MKResource* resource in [_statusByURL allValues]) {
        [resource removeWatcher:resourceWatcher];
    }
}

- (void)registerCustomResourceClass:(Class)aClass {
    if (![_customSchemesHandlers containsObject:aClass]) {
        [_customSchemesHandlers addObject:aClass];
    }
}

#pragma mark - Implement NSURLSessionDelegate
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session
{
    NSLog(@"Background URL session %@ finished events.\n", session);
    
    if (session.configuration.identifier)
        [self callCompletionHandlerForSession:session.configuration.identifier];
}

- (void)addCompletionHandler:(CompletionHandlerType)handler forSession:(NSString *)identifier
{
    if (self.backgroundSessionCompletionHandler != NULL) {
        NSLog(@"Error: Got multiple handlers for a single session identifier.  This should not happen.\n");
    }
    
    self.backgroundSessionCompletionHandler = handler;
}

- (void)callCompletionHandlerForSession:(NSString *)identifier
{
    if (self.backgroundSessionCompletionHandler != NULL) {
        self.backgroundSessionCompletionHandler();
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    if (downloadTask.state == NSURLSessionTaskStateSuspended) {
        return;
    }
    
    MKResource* resource = [self resourceForNSURL:downloadTask.originalRequest.URL];

    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)downloadTask.response;
    
    NSInteger statusCode = [httpResponse statusCode];

    if ((statusCode / 100) == 2) {
        // status 200, OK
        [self didFinishDownloadResource:resource dataFileURL:location error:downloadTask.error httpResponse:httpResponse];
        NSLog(@"Finish download data, url=%@", resource.resourceURL);
    } else {
        // !OK
        NSError *mediaError = [self formattedErrorForHTTPError:downloadTask.error httpResponse:httpResponse dataFileUrl:location];
        NSLog(@"Error download data, url=%@: %@", resource.resourceURL, mediaError);//Error
        [self didFinishDownloadResource:resource dataFileURL:nil error:mediaError httpResponse:httpResponse];
        //        if (self.httpClient) {
        //			[self.httpClient request:self.urlRequest didFailWithError:mediaError responce:self.urlResponse];
        //        }
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)downloadTask.response;
    
    NSInteger statusCode = [httpResponse statusCode];
    NSDictionary* dict = [httpResponse allHeaderFields];
//    NSLog(@"response headers = %@ with status code: %ld", dict, (long)statusCode);//Info
    
    NSString* contentType = [dict objectForKey:@"Content-Type"];
    if (contentType == nil || [contentType isEqualToString:@""]) {
        contentType = httpResponse.MIMEType;
    }
    
    MKResource* resource = [self resourceForNSURL:downloadTask.originalRequest.URL];
    
    [resource setContentType:contentType];
    
    [resource setExpectedContentLength:totalBytesExpectedToWrite];
    
    long code = statusCode / 100;
    if (code == 2) {
        [resource setDownloadedLength:totalBytesWritten];
    }

}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error) {
        MKResource* resource = [self resourceForNSURL:task.originalRequest.URL];
        NSLog(@"Error download data, url=%@: %@", resource.resourceURL, [error localizedDescription]);//Error
        NSError *mediaError = [self formattedErrorForHTTPError:error httpResponse:(NSHTTPURLResponse*)task.response dataFileUrl:nil];
        [self didFinishDownloadResource:resource dataFileURL:nil error:mediaError httpResponse:(NSHTTPURLResponse*)task.response];
        //    if (self.httpClient) {
        //        [self.httpClient request:self.urlRequest didFailWithError:mediaError responce:self.urlResponse];
        //    }
    }
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler
{
    NSLog(@"authentication required %@ ",[challenge failureResponse]);//Info
    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *) [challenge failureResponse];
    [[challenge sender] cancelAuthenticationChallenge:challenge];
	NSURL *remoteURL = [httpResponse URL];
#pragma unused(remoteURL)
    //    PostAuthenticationFaultForURLwithCredential(remoteURL, nil);
}

- (NSError*)formattedErrorForHTTPError:(NSError*)httpError httpResponse:(NSHTTPURLResponse*)response dataFileUrl:(NSURL*)dataFileUrl {
    NSUInteger httpStatusCode = [response statusCode];
    NSDictionary* httpResponseHeaders = [response allHeaderFields];
	
	if ((httpStatusCode / 100) != 2) {
		NSDictionary* theUserInfo = [httpError userInfo];
        
		if (httpResponseHeaders) {
			NSMutableDictionary* theMutableUserInfo = nil;
			if (theUserInfo != nil) {
				theMutableUserInfo = [NSMutableDictionary dictionaryWithDictionary:theUserInfo];
            } else {
				theMutableUserInfo = [NSMutableDictionary dictionary];
			}
			
			[theMutableUserInfo setObject:[NSDictionary dictionaryWithDictionary:httpResponseHeaders] forKey:@"MKHTTPResponceHeadersErrorKey"];
            
            NSData* httpResponseData = [[NSData alloc] initWithContentsOfURL:dataFileUrl];
            if (httpResponseData != nil) {
                NSString* dataStr = [[NSString alloc] initWithData:httpResponseData encoding:NSUTF8StringEncoding];
                [theMutableUserInfo setObject:dataStr forKey:NSLocalizedFailureReasonErrorKey];
            }
            
			theUserInfo = theMutableUserInfo;
		}
		
		if (httpStatusCode == 401) {
			httpError = [NSError errorWithDomain:@"MKAuthenticationErrorDomain" code:httpStatusCode userInfo:theUserInfo];
		} else {
			httpError = [NSError errorWithDomain:NSURLErrorDomain code:httpStatusCode userInfo:theUserInfo];
		}
	}
	
	return httpError;
}

@end
