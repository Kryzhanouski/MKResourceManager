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

    MKResourceManager* testedManager = [[MKResourceManager alloc] initWithKey:@"abcdefjxyz" pathCache:dirPath supportBackgroundLoading:NO];
    [testedManager resume];

      // should not crash on trying to download a nil
    [testedManager startDownloadResource:nil];

      // test custom resource
    [testedManager registerCustomResourceClass:[MKTestResource class]];
    NSURL* testURL = [NSURL URLWithString:@"MKTestResource"];
    MKResource* customResource = [testedManager resourceForNSURL:testURL];
    XCTAssertTrue([customResource isKindOfClass:[MKTestResource class]], @"MKTestResource should be here");

    [customResource startDownload];
    XCTAssertEqual(MKStatusInProgress, customResource.status, @"customResource should be in progress");
    [customResource cancelDownload];
    XCTAssertEqual(MKStatusNotDownloaded, customResource.status, @"customResource should be NotDownloaded");

    NSString* fakeRunString = @"MKTestResourceFakeRun";
    NSURL* fakeRunURL = [NSURL URLWithString:fakeRunString];
    MKResource* anotherResource = [testedManager resourceForNSURL:fakeRunURL];
    XCTAssertTrue([anotherResource isKindOfClass:[MKTestResource class]], @"MKTestResource should be here");

    [anotherResource startDownload];
    XCTAssertEqual(MKStatusDownloaded, anotherResource.status, @"anotherResource should have faked Downloaded status");
    NSError* error = nil;
    NSData *resData = [testedManager dataForResource:anotherResource error:&error];
    NSString* resString = [[NSString alloc] initWithData:resData encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(resString, fakeRunString, @"anotherResource should have returned '%@'", fakeRunString);
    XCTAssertNil(error, @"");

      // proceed to generic tests
    NSString* resourcePath = @"фыввлаэжжывдлаэждл±!@#$%^&*()_+";
    NSString* encPath = [MKResourceUtility URLEncode:resourcePath];
    NSURL* pathURL = [NSURL URLWithString:encPath];
    MKResource* resource = [testedManager resourceForNSURL:pathURL];
    XCTAssertFalse([resource isKindOfClass:[MKTestResource class]], @"This should be a generic MKResource");

    XCTAssertNotNil(resource, @"Resource cannot be nil for path %@",resourcePath);

    XCTAssertTrue(resource.status == MKStatusNotDownloaded, @"Resource status should be MKStatusNotDownloaded");

    XCTAssertNil([resource data], @"Resource data should be nil");

    NSString* dataString = @"Some Data: фыввлаэжжывдлаэждл±!@#$%^&*()_+";
    NSData* data = [dataString dataUsingEncoding:NSUTF8StringEncoding];
    NSString* tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%f",[NSDate timeIntervalSinceReferenceDate]]];
    NSURL* tempFileUrl = [NSURL fileURLWithPath:tempFile];
    [data writeToURL:tempFileUrl atomically:YES];

    [testedManager didFinishDownloadResource:resource dataFileURL:tempFileUrl error:nil httpResponse:nil];

    XCTAssertTrue(resource.status == MKStatusDownloaded, @"Resource status should be MKStatusDownloaded");

    NSData* resourceData = [resource data];
    XCTAssertNotNil(resourceData, @"Resource data should be not nil");

    NSString* resourceString = [[NSString alloc] initWithBytes:[resourceData bytes] length:[resourceData length] encoding:NSUTF8StringEncoding];

    XCTAssertTrue([dataString isEqualToString:resourceString], @"Data retrieved from manager is corrupted");

    BOOL result = [testedManager removeResourceForNSURL:pathURL];

    XCTAssertTrue(result,@"Resource removing failed");

    resource = [testedManager resourceForNSURL:pathURL];

    XCTAssertNotNil(resource, @"Resource cannot be nil for path %@",resourcePath);
    XCTAssertTrue(resource.status == MKStatusNotDownloaded, @"Resource status should be MKStatusNotDownloaded");
    XCTAssertNil([resource data], @"Resource data should be nil");

    NSString* timeoutResourcePath = @"timeoutResPath";
    NSString* encTimeoutPath = [MKResourceUtility URLEncode:timeoutResourcePath];
    NSURL* timeoutPathURL = [NSURL URLWithString:encTimeoutPath];
    MKResource* timeoutResource = [testedManager resourceForNSURL:timeoutPathURL];
    timeoutResource.expirationPeriod = 0.1;
    XCTAssertNotNil(timeoutResource, @"Timeout resource should not be nil");
    NSData* timeoutResData = [timeoutResourcePath dataUsingEncoding:NSUTF8StringEncoding];
    tempFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%f",[NSDate timeIntervalSinceReferenceDate]]];
    tempFileUrl = [NSURL fileURLWithPath:tempFile];
    [timeoutResData writeToURL:tempFileUrl atomically:YES];
    [testedManager didFinishDownloadResource:timeoutResource dataFileURL:tempFileUrl error:nil httpResponse:nil];
    NSData* timeoutResDataFromManager = [timeoutResource data];
    XCTAssertNotNil(timeoutResDataFromManager, @"Timeout resource data should not be nil");

    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:3.0]];

    MKResourceManager* anotherManager = [[MKResourceManager alloc] initWithKey:@"anotherManager" pathCache:dirPath supportBackgroundLoading:NO];
    MKResource* anotherTimeoutResource = [anotherManager resourceForNSURL:timeoutPathURL];
    NSData* anotherTimeoutResourceData = [anotherTimeoutResource data];
    XCTAssertNil(anotherTimeoutResourceData, @"Now timeout resource data should be nil");

    [[NSFileManager defaultManager] removeItemAtPath:dirPath error:nil];
}

- (void)testSuspendResume {
    NSString* notValidURL = @"http://www.NOT_VALID_URL/not_valid_image.JPG";
	NSMutableArray* imagesURLs = [NSMutableArray arrayWithObjects:
                                  @"http://upload.wikimedia.org/wikipedia/commons/e/e1/ARS_copper_rich_foods.jpg",
                                  @"http://en.wikipedia.org/wiki/Food#mediaviewer/File:Good_Food_Display_-_NCI_Visuals_Online.jpg",
                                  @"http://www.bigfoto.com/themes/food/food-fruits-photo.jpg",
                                  @"http://viewallpaper.com/wp-content/uploads/2013/07/Images-Water-Wallpaper.jpg",
                                  @"http://www.nt.gov.au/dpifm/Primary_Industry/Content/Image/horticulture/vegetables/tomatoes_with_no_background(1).JPG",
                                  nil];
    [imagesURLs addObject:notValidURL];
    _imagesURLs = imagesURLs;
    _imagesCount = [_imagesURLs count];
    
    NSString* dirPath = NSTemporaryDirectory();
	dirPath = [dirPath stringByAppendingPathComponent:@"TestDir"];
    [[NSFileManager defaultManager] removeItemAtPath:dirPath error:NULL];
	
	MKResourceManager* testedManager = [[MKResourceManager alloc] initWithKey:@"abcdefjxyz" pathCache:dirPath supportBackgroundLoading:NO];
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

    XCTAssertTrue(_downloadCompletedImagesCount == _imagesCount, @"");
    
    for (NSString* urlString in _imagesURLs) {
        BOOL notValid = [urlString isEqualToString:notValidURL];
        NSURL* url = [NSURL URLWithString:urlString];
        NSError* error = nil;
        MKResource* r = [testedManager resourceForNSURL:url];
        if (notValid) {
            XCTAssertNil([r data:&error], @"");
        } else {
            XCTAssertNotNil([r data:&error], @"");
        }
        XCTAssertNil(error, @"");
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
        XCTAssertNil([r data:&error], @"");
        XCTAssertNotNil(error, @"");
    }
}
     
#pragma mark Implement CAFResourceStatusWatcher

- (void)resourceStatusDidChange:(MKResource*)resource {
    if (resource.status == MKStatusDownloaded) {
        XCTAssertNotNil(resource.lastResponse, @"");
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
        XCTAssertNotNil(resource.lastResponse, @"");
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
