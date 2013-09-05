//
//  MKResourceController.m
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 1/18/11.
//  Copyright 2011 Mark Kryzhanouski. All rights reserved.
//

#import "MKResourcesController.h"
#import "MKResource+Private.h"

@implementation MKResourcesController

- (id)init {
    self = [super initWithResourceManager:nil andURL:nil];
    if (self != nil) {
        _resources = [[NSMutableArray alloc] init];
        _progresByResource = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc {
    for (MKResource* resource in _resources) {
        [resource removeWatcher:self];
    }
}

/** Does nothing.
 *  @return Returns nil.
 */
- (NSData*)data {
    return nil;
}

/** Starts download all the added resources.
 */
- (void)startDownload {
    for (MKResource* resource in _resources) {
        [resource startDownload];
    }
}

/** Cancels download all the added resources.
 */
- (void)cancelDownload {
    for (MKResource* resource in _resources) {
        [resource cancelDownload];
    }
}

- (void)addResource:(MKResource*)resource {
    if (resource == nil) {
        return;
    }
    [resource addWatcher:self];
    [_resources addObject:resource];

    float progress = resource.status == MKStatusDownloaded ? 1.0f : 0.0f;

    [_progresByResource setObject:[NSNumber numberWithFloat:progress] forKey:[NSValue valueWithPointer:(__bridge const void *)(resource)]];
}

- (void)removeResource:(MKResource*)resource {
    [resource removeWatcher:self];
    [_resources removeObject:resource];
    [_progresByResource removeObjectForKey:[NSValue valueWithPointer:(__bridge const void *)(resource)]];
}

- (NSUInteger)count {
    return [_resources count];
}

- (MKResource*)resourceAtIndex:(NSUInteger)index {
    NSUInteger count = [self count];

    if (index >= count) {
        return nil;
    }

    return (MKResource*)[_resources objectAtIndex:index];
}

- (MKResource*)resourceForURL:(NSString*)resourceURL {
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"url == %@",resourceURL];
    NSArray* result = [_resources filteredArrayUsingPredicate:predicate];
    if ([result count] > 0) {
        return (MKResource*)[result objectAtIndex:0];
    }
    return nil;
}

- (NSUInteger)indexOfResource:(MKResource*)resource {
    return [_resources indexOfObject:resource];
}

- (NSExpression*)sumExpression {
    if (_sumExpression == nil) {
        NSExpression* expression = [NSExpression expressionForKeyPath:@"expectedContentLength"];
        NSExpression* sumExpression = [NSExpression expressionForFunction:@"sum:" arguments:[NSArray arrayWithObject:expression]];
        _sumExpression = sumExpression;
    }
    return _sumExpression;
}

- (NSExpression*)averageExpression {
    if (_averageExpression == nil) {
        NSExpression* expression = [NSExpression expressionForKeyPath:@"floatValue"];
        NSExpression* averageExpression = [NSExpression expressionForFunction:@"average:" arguments:[NSArray arrayWithObject:expression]];
        _averageExpression = averageExpression;
    }
    return _averageExpression;
}

- (long long)commonExpectedContentLength {
    NSExpression* sumExpression = [self sumExpression];
    NSNumber* lenth = [sumExpression expressionValueWithObject:_resources context:nil];
    return [lenth longLongValue];
}

- (float)averageProgress {
    NSExpression* averageExpression = [self averageExpression];
    NSNumber* averageProgress = [averageExpression expressionValueWithObject:[_progresByResource allValues] context:nil];
    return [averageProgress floatValue];
}

#pragma mark -
#pragma mark Implement MKResourceStatusWatcher
- (void)resourceStatusDidChange:(MKResource*)resource {
}

- (void)resource:(MKResource*)resource loadProgressChanged:(NSNumber*)progress {
    [_progresByResource setObject:progress forKey:[NSValue valueWithPointer:(__bridge const void *)(resource)]];
    long long commonExpectedContentLength = [self commonExpectedContentLength];
    [self setExpectedContentLength:commonExpectedContentLength];
    float progressValue = [self averageProgress];
    [self setDownloadedLength:commonExpectedContentLength * progressValue];
}

- (void)resource:(MKResource*)resource loadCompletedWithError:(NSError*)error {
    [_progresByResource setObject:[NSNumber numberWithFloat:1.0f] forKey:[NSValue valueWithPointer:(__bridge const void *)(resource)]];

    BOOL didFinish = YES;
    for (MKResource* resource in _resources) {
        if (resource.status != MKStatusDownloaded) {
            didFinish = NO;
            break;
        }
    }

    if (didFinish == YES) {
        [self didFinishDownloadMR:nil error:nil];
    }
}

- (void)resourceDidCancelDownload:(MKResource*)resource {
    [_progresByResource setObject:[NSNumber numberWithFloat:1.0f] forKey:[NSValue valueWithPointer:(__bridge const void *)(resource)]];

    BOOL didCancel = YES;
    for (MKResource* resource in _resources) {
        if (resource.status == MKStatusNotDownloaded) {
            didCancel = NO;
            break;
        }
    }

    if (didCancel == YES) {
        [super cancelDownload];
    }
}

@end
