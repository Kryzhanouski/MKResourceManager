//
//  MKResourceController.h
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 1/18/11.
//  Copyright 2011 Mark Kryzhanouski. All rights reserved.
//

#import "MKResource.h"

@interface MKResourcesController : MKResource<MKResourceStatusWatcher> {
    NSMutableArray*         _resources;
    NSMutableDictionary*    _progresByResource;
    NSExpression*           _sumExpression;
    NSExpression*           _averageExpression;
}

/** Adds resource to watch common progress.
 *  @param resource Resource to be added in common progress.
 */
- (void)addResource:(MKResource*)resource;

/** Removes resource from common progress.
 *  @param resource Resource to be removed from common progress.
 */
- (void)removeResource:(MKResource*)resource;

/** Returns the number of resources currently in the controller.
 *  @return The number of objects currently in the controller.
 */
- (NSUInteger)count;

/** Returns the resource located at index in the controller.
 *  @param index An index within the bounds of the nnumber of added resources.
 *  @return The resource located at index in the controller. Returns nil, if
 *	index is beyond the end of the array (that is, if index is greater than
 *	or equal to the value returned by count).
 */
- (MKResource*)resourceAtIndex:(NSUInteger)index;

/** Returns resource for specified resource URL.
 *	@param resourceURL Resource URL
 *  @return MKResource object with resource information.
 */
- (MKResource*)resourceForURL:(NSString*)resourceURL;

/** Returns the lowest index whose corresponding array value is equal to a given resource.
 *	@param resource A resource.
 *  @return The lowest index whose corresponding array value is equal to resource.
 *	If none of the objects in the array is equal to resource, returns NSNotFound.
 */
- (NSUInteger)indexOfResource:(MKResource*)resource;

/** Does nothing.
 *  @return Returns nil.
 */
- (NSData*)data;

/** Starts download all the added resources.
 */
- (void)startDownload;

/** Cancels download all the added resources.
 */
- (void)cancelDownload;

@end
