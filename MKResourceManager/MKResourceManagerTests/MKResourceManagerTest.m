//
//  ResourceManagerTest.m
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 1/20/11.
//  Copyright 2011 Mark Kryzhanousk. All rights reserved.
//

#import "MKResourceManagerTest.h"
#import "MKResourceManager+Private.h"
#import "MKTestResource.h"
#import "MKResourceUtility.h"

@implementation MKResourceManagerTest

#if USE_APPLICATION_UNIT_TEST     // all code under test is in the iPhone Application

- (void)testAppDelegate {
    id yourApplicationDelegate = [[UIApplication sharedApplication] delegate];
    STAssertNotNil(yourApplicationDelegate, @"UIApplication failed to find the AppDelegate");
}

#else                           // all code under test must be linked into the Unit Test bundle

- (void)test {
    NSString* dirPath = NSTemporaryDirectory();
    dirPath = [dirPath stringByAppendingPathComponent:@"TestDir"];

    MKResourceManager* testedManager = [[MKResourceManager alloc] initWithKey:@"abcdefjxyz" pathCache:dirPath];
    [testedManager resume];

      // should not crash on trying to download a nil
    [testedManager startDownloadResource:nil];

      // test custom resource
    [testedManager registerCustomResourceClass:[MKTestResource class]];
    NSURL* testURL = [NSURL URLWithString:@"MKTestResource"];
    MKResource* customResource = [testedManager resourceForNSURL:testURL];
    STAssertTrue([customResource isKindOfClass:[MKTestResource class]], @"MKTestResource should be here");

    [customResource startDownload];
    STAssertEquals(MKStatusInProgress, customResource.status, @"customResource should be in progress");
    [customResource cancelDownload];
    STAssertEquals(MKStatusNotDownloaded, customResource.status, @"customResource should be NotDownloaded");

    NSString* fakeRunString = @"MKTestResourceFakeRun";
    NSURL* fakeRunURL = [NSURL URLWithString:fakeRunString];
    MKResource* anotherResource = [testedManager resourceForNSURL:fakeRunURL];
    STAssertTrue([anotherResource isKindOfClass:[MKTestResource class]], @"MKTestResource should be here");

    [anotherResource startDownload];
    STAssertEquals(MKStatusDownloaded, anotherResource.status, @"anotherResource should have faked Downloaded status");
    NSError* error = nil;
    NSData *resData = [testedManager dataForResource:anotherResource error:&error];
    NSString* resString = [[NSString alloc] initWithData:resData encoding:NSUTF8StringEncoding];
    STAssertEqualObjects(resString, fakeRunString, @"anotherResource should have returned '%@'", fakeRunString);
    STAssertNil(error, @"");

      // proceed to generic tests
    NSString* resourcePath = @"фыввлаэжжывдлаэждл±!@#$%^&*()_+";
    NSString* encPath = [MKResourceUtility URLEncode:resourcePath];
    NSURL* pathURL = [NSURL URLWithString:encPath];
    MKResource* resource = [testedManager resourceForNSURL:pathURL];
    STAssertFalse([resource isKindOfClass:[MKTestResource class]], @"This should be a generic MKResource");

    STAssertNotNil(resource, @"Resource cannot be nil for path %@",resourcePath);

    STAssertTrue(resource.status == MKStatusNotDownloaded, @"Resource status should be MKStatusNotDownloaded");

    STAssertNil([resource data], @"Resource data should be nil");

    NSString* dataString = @"Some Data: фыввлаэжжывдлаэждл±!@#$%^&*()_+";
    NSData* data = [dataString dataUsingEncoding:NSUTF8StringEncoding];

	[testedManager didFinishDownloadResource:resource data:data error:nil httpResponse:nil];

    STAssertTrue(resource.status == MKStatusDownloaded, @"Resource status should be MKStatusDownloaded");

    NSData* resourceData = [resource data];
    STAssertNotNil(resourceData, @"Resource data should be not nil");

    NSString* resourceString = [[NSString alloc] initWithBytes:[resourceData bytes] length:[resourceData length] encoding:NSUTF8StringEncoding];

    STAssertTrue([dataString isEqualToString:resourceString], @"Data retrieved from manager is corrupted");

    BOOL result = [testedManager removeResourceForNSURL:pathURL];

    STAssertTrue(result,@"Resource removing failed");

    resource = [testedManager resourceForNSURL:pathURL];

    STAssertNotNil(resource, @"Resource cannot be nil for path %@",resourcePath);
    STAssertTrue(resource.status == MKStatusNotDownloaded, @"Resource status should be MKStatusNotDownloaded");
    STAssertNil([resource data], @"Resource data should be nil");

    NSString* timeoutResourcePath = @"timeoutResPath";
    NSString* encTimeoutPath = [MKResourceUtility URLEncode:timeoutResourcePath];
    NSURL* timeoutPathURL = [NSURL URLWithString:encTimeoutPath];
    MKResource* timeoutResource = [testedManager resourceForNSURL:timeoutPathURL];
    timeoutResource.expirationPeriod = 0.1;
    STAssertNotNil(timeoutResource, @"Timeout resource should not be nil");
    NSData* timeoutResData = [timeoutResourcePath dataUsingEncoding:NSUTF8StringEncoding];
    [testedManager didFinishDownloadResource:timeoutResource data:timeoutResData error:nil httpResponse:nil];
    NSData* timeoutResDataFromManager = [timeoutResource data];
    STAssertNotNil(timeoutResDataFromManager, @"Timeout resource data should not be nil");

    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:3.0]];

    MKResourceManager* anotherManager = [[MKResourceManager alloc] initWithKey:@"anotherManager" pathCache:dirPath];
    MKResource* anotherTimeoutResource = [anotherManager resourceForNSURL:timeoutPathURL];
    NSData* anotherTimeoutResourceData = [anotherTimeoutResource data];
    STAssertNil(anotherTimeoutResourceData, @"Now timeout resource data should be nil");

    [[NSFileManager defaultManager] removeItemAtPath:dirPath error:nil];
}

- (void)testSuspendResume {
    NSString* notValidURL = @"http://www.NOT_VALID_URL/not_valid_image.JPG";
	NSMutableArray* imagesURLs = [NSMutableArray arrayWithObjects:
                                  @"http://upload.wikimedia.org/wikipedia/commons/e/e1/ARS_copper_rich_foods.jpg",
                                  @"http://www.apps4rent.com/images/apple-products-for-business.jpg",
                                  @"http://www.bigfoto.com/themes/food/food-fruits-photo.jpg",
                                  @"http://viewallpaper.com/wp-content/uploads/2013/07/Images-Water-Wallpaper.jpg",
                                  @"http://www.nt.gov.au/dpifm/Primary_Industry/Content/Image/horticulture/vegetables/tomatoes_with_no_background(1).JPG",
                                  nil];
    [imagesURLs addObject:notValidURL];
    _imagesURLs = imagesURLs;
    _imagesCount = [_imagesURLs count];
    
    NSString* dirPath = NSTemporaryDirectory();
	dirPath = [dirPath stringByAppendingPathComponent:@"TestDir"];
	
	MKResourceManager* testedManager = [[MKResourceManager alloc] initWithKey:@"abcdefjxyz" pathCache:dirPath];
    [testedManager resume];
    
    for (NSString* urlString in _imagesURLs) {
        NSURL* url = [NSURL URLWithString:urlString];
        MKResource* r = [testedManager resourceForNSURL:url];
        [r addWatcher:self];
        [r startDownload];
    }
    
    [self performSelector:@selector(suspend:) withObject:testedManager afterDelay:1.0f];
    
    _finish = NO;
	do {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
	} while (!_finish);

    STAssertTrue(_downloadCompletedImagesCount == _imagesCount, @"");
    
    for (NSString* urlString in _imagesURLs) {
        BOOL notValid = [urlString isEqualToString:notValidURL];
        NSURL* url = [NSURL URLWithString:urlString];
        NSError* error = nil;
        MKResource* r = [testedManager resourceForNSURL:url];
        if (notValid) {
            STAssertNil([r data:&error], @"");
        } else {
            STAssertNotNil([r data:&error], @"");
        }
        STAssertNil(error, @"");
    }
    
    _imagesURLs = nil;
}

- (void)suspend:(MKResourceManager *)manager {
    [manager suspend];
    [manager performSelector:@selector(resume) withObject:nil afterDelay:1.0f];

    for (NSString* urlString in _imagesURLs) {
        NSURL* url = [NSURL URLWithString:urlString];
        NSError* error = nil;
        MKResource* r = [manager resourceForNSURL:url];
        STAssertNil([r data:&error], @"");
        STAssertNotNil(error, @"");
    }
}
     
#pragma mark Implement CAFResourceStatusWatcher

- (void)resourceStatusDidChange:(MKResource*)resource {
    if (resource.status == MKStatusDownloaded) {
        STAssertNotNil(resource.lastResponse, @"");
    }
}

- (void)resource:(MKResource*)resource loadProgressChanged:(NSNumber*)progress {
}

- (void)resource:(MKResource*)resource loadCompletedWithError:(NSError*)error {
    _downloadCompletedImagesCount++;
    _downloadedImagesCount++;
    if (_downloadedImagesCount == _imagesCount) {
        _finish = YES;
    }
    if (error == nil) {
        STAssertNotNil(resource.lastResponse, @"");
    }
}

- (void)resourceDidCancelDownload:(MKResource*)resource {
    _downloadedImagesCount++;
    if (_downloadedImagesCount == _imagesCount) {
        _finish = YES;
    }
}

#endif

@end
