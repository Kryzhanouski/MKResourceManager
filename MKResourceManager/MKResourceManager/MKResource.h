//
//  MKResourceStatus.h
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 1/13/11.
//  Copyright 2011 Mark Kryzhanouski. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * MKStatus download status structure.
 */
typedef enum {
      /** The resource has not been downloaded yet.*/
    MKStatusNotDownloaded = 0,
      /** The resource has been downloaded.*/
    MKStatusDownloaded = 1,
      /** The resource is being downloaded.*/
    MKStatusInProgress = 2
} MKStatus;

@class MKResourceManager;

@protocol MKResourceStatusWatcher;

// ! MKResourceStatus contains all information about resource.
/**
 MKResourceStatus contains all information about resource
 */
@interface MKResource : NSObject<NSCoding> {
    NSMutableArray*             _watchers;
    NSMutableArray*             _completionHandlers;
    MKResourceManager*          _manager;
    MKStatus                   _status;
    NSURL*                      _resourceURL;
    NSString*                   _contentType;
    long long                   _expectedContentLength;
    float                       _progress;
    NSDate*                     _loadedDate;
    NSError*                    _lastError;
    NSTimeInterval              _expirationPeriod;
    NSDate*                     _lastAccessDate;
}

@property (nonatomic, readonly) MKStatus status;
@property (nonatomic, readonly) NSArray* watchers;
@property (nonatomic, readonly) NSURL* resourceURL;
@property (nonatomic, readonly) NSString* contentType;
@property (nonatomic, readonly) long long expectedContentLength;
@property (nonatomic, readonly) float progress;
@property (nonatomic, readonly) NSDate* loadedDate;
@property (nonatomic, readonly) NSError* lastError;
// Returns HTTP response from last download. The value is not persistent.
// It lives during application session in which resource was downloaded.
@property (nonatomic, readonly) NSHTTPURLResponse* lastResponse;
@property (nonatomic, assign)   NSTimeInterval expirationPeriod;
@property (nonatomic, readonly) MKResourceManager* manager;

/** Returns resource data.
 *  @return NSData object with content of resource. Returns nil if the resource has not been downloaded yet.
 */
- (NSData*)data;
- (NSData*)data:(NSError**)error;

/** Sets resource data and if data is not nil marks the corresponding resource as downloaded.
 *	@param data NSData object with content of resource
 */
- (void)setData:(NSData*)data;

/** Starts download of the resource.
 */
- (void)startDownload;

/** Cancels download of the resource.
 */
- (void)cancelDownload;

/** Adds watcher that will be notified when status changes.
 *  @param watcher watcher that will be notified. The watcher is not stronged.
 *  @see MKResourceStatusWatcher
 */
- (void)addWatcher:(id<MKResourceStatusWatcher>)watcher;

/** Removes watcher from notification.
 *  @param watcher watcher that will be removed from notification
 *  @see MKResourceStatusWatcher
 */
- (void)removeWatcher:(id<MKResourceStatusWatcher>)watcher;

/** Adds completion handler that will be notified when status changes.
 *  @param completion completion handler that will be invoked. The watcher is stronged. Will be removed automatically when download is completed
 */
- (void)addCompletionHandler:(void (^)(MKResource* resource, NSData* data, NSError* error))completion;

@end

// ! MKResourceStatusWatcher is protocol that should be implemented by resource watcher.
/**
 MKResourceStatusWatcher is protocol that should be implemented by resource watcher
 */
@protocol MKResourceStatusWatcher<NSObject>
@required
/** Notifies watcher about resource status change.
 *  @param resource The resource with changed status values.
 */
- (void)resourceStatusDidChange:(MKResource*)resource;

@optional

/** Notifies watcher about resource will start download.
 *  @param resource The resource for whitch download will start.
 *  @param request NSMutableURLRequest.
 */
- (void)resource:(MKResource*)resource willSendRequest:(NSMutableURLRequest*)request;

/** Notifies watcher about resource download progress change.
 *  @param resource The resource for whitch download progress changed.
 *  @param progress Number with float value between 0.0 and 1.0, inclusive, where 1.0 indicates the completion of the task.
 */
- (void)resource:(MKResource*)resource loadProgressChanged:(NSNumber*)progress;

/** Notifies watcher about resource download completed.
 *  @param resource The resource for whitch download progress changed.
 *  @param error If error object is nil that means download completed succefully.
 *			An error object containing details of why the connection failed to load the request successfully.
 */
- (void)resource:(MKResource*)resource loadCompletedWithError:(NSError*)error;

/** Notifies watcher about resource download canceled.
 *  @param resource The resource for whitch download canceled.
 */
- (void)resourceDidCancelDownload:(MKResource*)resource;

@end
