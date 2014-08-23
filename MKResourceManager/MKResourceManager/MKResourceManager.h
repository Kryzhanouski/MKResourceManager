//
//  MKResourceManager.h
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 7.12.10.
//  Copyright 2010 Mark Kryzhanouski. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MKResource.h"

#define MKRESOURCEMANAGER_EXTERN		extern

/**
 \defgroup MediaResourcesDoxyGroup Fetching Media Resources
 The MKResourceManager class enables you to perform many generic file operations
 and provides an abstraction from the underlying file system.\n
 There are a lot of cases when sending a request in order to receive data either simply does not work, or proves to be an overly complicated approach.
 Resource manager has been introduced in order to facilitate that. Primary aim of the resource manager is to handle binary files.
 If there is a direct URL to a resource on the backend, that data can be fetched by simply calling \c downloadResourceForNSURL: on the manager.
 This method returns a wrapper object, which can report resource's status, progress, content type, binary data (if status is Complete), etc. Once a
 resource is fetched from backend, it is client's responsibility to remove it from storage. However, MKResource allows to set expiration time which,
 if set to a positive valie, will be used to determine when the resource's data needs to be cleaned up from disk. Expiration time accepts NSTimeInterval
 value and is compared to the date when resource was last accessed (not when it was created or its data was downloaded).\n
 Media resource manager uses \c NSURLConnection to fetch data. This approach is not always suitable, so a subclassing mechanism has been developed.
 See \ref CustomResourceDoxyGroup "Using custom resources" section for explanation.\n
 Using MKResourceManager:
 @code
 MKResourceManager* resManager = [[MKResourceManager alloc] initWithKey:@"resManager" pathCache:dirPath];
 NSString *resourceURLString = ...    // string to generate URL
 NSURL *resourceURL = [NSURL URLWithString:resourceURLString];
 MKResource *aResource = [resManager resourceForNSURL:resourceURL];
 [aResource startDownload];
 @endcode
 */

typedef void (^CompletionHandlerType)();


@interface MKResourceManager : NSObject {
    NSMutableDictionary*    _workDictionary;
    NSMutableDictionary*    _statusByURL;
    NSString*               _keyEncoding;
    NSString*               _pathCache;
    NSMutableArray*         _customSchemesHandlers;
    NSMutableArray*         _suspendedResources;
    NSMutableArray*         _downloadResourcesQueue;
    BOOL                    _suspended;
    NSTimeInterval          _lastTimeWhenResourceInfoSaved;
    BOOL                    _saveDalayed;
    dispatch_queue_t        _saveResourceInfoQueue;
}

@property (nonatomic, readonly) NSString* pathCache;
@property (nonatomic, readonly, strong) NSString* backgroundSessionIdentifier;
;

/**
 * Sets/gets the maximum number of concurrent downloads that the receiver can execute.
 * Default value is 10
 */
@property (nonatomic, assign) NSUInteger maxConcurrentDownloadsCount;

- (id)initWithKey:(NSString*)aKeyEncoding pathCache:(NSString*)path;

/** Returns resource for specified resource URL.
 *	@param aURL Resource URL
 *  @return MKResource object with resource information.
 */
- (MKResource*)resourceForNSURL:(NSURL*)aURL;

/** Forces download resource if it is not downloaded yet.
 *	@param aURL Resource URL
 *  @return MKResource object with resource information.
 */
- (MKResource*)downloadResourceForNSURL:(NSURL*)aURL;

/** Cancels resource download if it is in progress.
 *	@param aURL Resource URL
 *  @return MKResource object with resource information.
 */
- (MKResource*)cancelDownloadResourceForNSURL:(NSURL*)aURL;

/** Returns resource data if it has been downloaded.
 *	@param aURL Resource URL
 *  @return NSData object with content of resource. Returns nil if the resource has not been downloaded yet.
 */
- (NSData*)dataForResourceForNSURL:(NSURL*)aURL;
- (NSData *)dataForResourceForNSURL:(NSURL *)aURL error:(NSError**)error;

- (NSURL*)pathForResource:(MKResource*)resource;

/** Sets resource data and if data is not nil marks the corresponding resource as downloaded.
 *	@param data NSData object with content of resource
 *	@param aURL Resource URL
 */
- (void)setData:(NSData*)data forResourceForNSURL:(NSURL*)aURL;

/** Removes resource data from files storage.
 *	@param aURL Resource URL
 *  @return Return YES if resource binary data is succefully removed.
 */
- (BOOL)removeResourceForNSURL:(NSURL*)aURL;

/** Removes resource watcher from all resources.
 *	@param resourceWatcher Watcher that will be removed from notifications
 */
- (void)removeWatcherFromAllResources:(id<MKResourceStatusWatcher>)resourceWatcher;

/** Registers a new class which will be responsible for handling requests sent via arbitrary schemes
 *  @param aClass Custom resource class (subclass of MKCustomResource) which will handle fetching
 *      and parsing data for some scheme
 */
- (void)registerCustomResourceClass:(Class)aClass;

/**
 * Suspends all active downloads
 */
- (void)suspend;

/**
 * Resumes all suspended downloads
 */
- (void)resume;

/**
 * In app delegate methods for iOS background downloads use this method to set completion handler for
 * session with identifier equal to MKResourceManager.backgroundSessionIdentifier.
 * Example:
 - (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier completionHandler:(void (^)())completionHandler
 {
    MKResourceManager* resourceManager = self.context.mediaResourceManager;
    if ([resourceManager.backgroundSessionIdentifier isEqualToString:identifier]) {
        [resourceManager addCompletionHandler:completionHandler];
    }
 }
 */
- (void)addCompletionHandler:(CompletionHandlerType)handler;

@end


