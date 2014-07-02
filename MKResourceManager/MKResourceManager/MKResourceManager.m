//
//  MKResourceManager.m
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 7.12.10.
//  Copyright 2010 Mark Kryzhanouski. All rights reserved.
//

#import "MKResourceManager.h"
#import "MKResourceManager+Private.h"
#import "MKResourceDownloadWork.h"
#import "AESUtil.h"
#import "MKResource+Private.h"
#import "MKResourceUtility.h"
#import "MKResourceUtility+Private.h"
#import "MKCustomResource.h"

static NSString* const MKMediaResourceSavedResourcesFileName = @"ResourceInfo.plist";
NSUInteger const MKMediaResourceMaxConcurrentDownloadsCount = 10;


@interface MKResourceManager () {
    id<MKHTTPHandlerClientPrivate> _httpClient;
}
@end


@implementation MKResourceManager

@synthesize pathCache = _pathCache;

- (id)initWithKey:(NSString*)aKeyEncoding pathCache:(NSString*)path {
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
//    dispatch_release(_saveResourceInfoQueue);
}

- (void)setHttpClient:(id<MKHTTPHandlerClientPrivate>)client {
    _httpClient = client;
}

- (id<MKHTTPHandlerClientPrivate>)httpClient {
    return _httpClient;
}


- (void)suspend {
    _suspended = YES;
    for (MKResourceDownloadWork* work in [_workDictionary allValues]) {
        [self cancelDownloadResource:[work resource]];
    }
}

- (void)resume {
    _suspended = NO;
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
    if ([[_workDictionary allValues] count] >= MKMediaResourceMaxConcurrentDownloadsCount) {
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
        MKResourceDownloadWork* work = [[MKResourceDownloadWork alloc] init];
        [_workDictionary setObject:work forKey:[resource.resourceURL absoluteString]];
        [work startDownloadWork:resource manager:self httpClient:_httpClient];
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
            MKResourceDownloadWork* work = (MKResourceDownloadWork*)[_workDictionary objectForKey:[resource.resourceURL absoluteString]];
            [work cancelLoading];
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

- (void)didFinishDownloadResource:(MKResource *)resource data:(NSData *)data error:(NSError *)error {
    [self didFinishDownloadResource:resource data:data error:error httpResponse:nil];
}

- (void)didFinishDownloadResource:(MKResource *)resource data:(NSData *)data error:(NSError *)error httpResponse:(NSHTTPURLResponse*)httpResponse {
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
        [self setData:data forResource:resource];
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
    if (resource != nil) {
        
        resource.lastAccessDate = [NSDate date];
        if (data == nil && [self existMRinCache:[resource.resourceURL absoluteString]] == NO) {
            [resource setStatus:MKStatusNotDownloaded];
        } else {
            if (data) {
                [self saveInCache:data atPath:[resource.resourceURL absoluteString]];
            }
            [resource setStatus:MKStatusDownloaded];
            [self saveResourcesInfo];
        }
    }
}

- (void)saveInCache:(NSData*)data atPath:(NSString*)stringURL {
    NSString* fullURLString = [self fullFilePath:stringURL];
    //    [[AESUtil encryptAES:_keyEncoding data:data] writeToFile:fullURLString atomically:YES];
    [data writeToFile:fullURLString atomically:YES];
    // also add attributes
    NSURL* fileURL = [NSURL fileURLWithPath:fullURLString];
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

@end
