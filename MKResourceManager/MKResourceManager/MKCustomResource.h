//
//  MKCustomResource.h
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 10/11/2011.
//  Copyright (c) 2011 Mark Kryzhanouski. All rights reserved.
//

#import "MKResource.h"

/** \defgroup CustomResourceDoxyGroup MKCustomResource
 MKCustomResource is a container class intended for subclassing in order to provide support for arbitrary download
 schemes. This should be done by creating a subclass of MKCustomResource and implementing designated methods.\n
 First of all, a custom subclass needs to be able to respond to a method \c canInitWithRequestURL: . This method is
 called by MKMediaResourceManager in order to determine which implementation to use. If no custom resource class
 can be found, or all custom implementations return \c NO for the provided URL, resource manager will attempt to use
 the default MKResource implementation.\n
 Second, custom implementation must override \c startCustomDownload and \c cancelCustomDownload . These methods are
 called by the manager when someone tries to access, explicitly start, or cancel a request. Consumers will not even
 know about the custom implementation, so they will use generic MKMediaResourceManager's methods like
 \c cancelDownloadResourceForNSURL: .\n
 Third, custom implementation should at appropriate moments call on self the following methods:
 - \c setExpectedContentLength:
 - \c setDownloadedLength:
 - \c setContentType:
 - \c didFinishDownloadMR:error: \n
 By calling those on self, subclass with tell its parent (MKCustomResource) to direct the provided info to the
 resource manager so that the manager can correctly notify listeners.
 */

@interface MKCustomResource : MKResource

// canInitWithRequestString: determines whether this particular subclass can handle
// particular requests
+ (BOOL)canInitWithRequestURL:(NSURL*)aURL;

// startCustomDownload is called by MKMediaResourceManager when someone requests
// this data to be downloaded. Implementation of this method should fetch and parse
// necessary the data.
- (void)startCustomDownload;

// cancelCustomDownload is called by MKMediaResourceManager when the resource
// needs to be canceled.
- (void)cancelCustomDownload;

/** The following four methods need to be called by the child on itself
 */

// Expected and Downloaded length allow root MKResource to correctly calculate
// download progress and notify watchers about it.
- (void)setExpectedContentLength:(long long)expectedContentLength;
- (void)setDownloadedLength:(NSUInteger)downloadedLength;

// Content type of the resource being downloaded
- (void)setContentType:(NSString*)contentType;

// Notifies root MKResource about completed download. Success/failure is deduced from the error
- (void)didFinishDownloadMR:(NSData*)data error:(NSError*)error;

@end
