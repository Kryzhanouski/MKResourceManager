//
//  ResourceManagerTest.h
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 1/20/11.
//  Copyright 2011 Mark Kryzhanouski. All rights reserved.
//
//  See Also: http://developer.apple.com/iphone/library/documentation/Xcode/Conceptual/iphone_development/135-Unit_Testing_Applications/unit_testing_applications.html

//  Application unit tests contain unit test code that must be injected into an application to run correctly.
//  Define USE_APPLICATION_UNIT_TEST to 0 if the unit test code is designed to be linked into an independent test executable.

#define USE_APPLICATION_UNIT_TEST 0

#import <SenTestingKit/SenTestingKit.h>
#import <UIKit/UIKit.h>
#import "MKResourceManager.h"

// #import "application_headers" as required

@interface MKResourceManagerTest : SenTestCase <MKResourceStatusWatcher> {
    BOOL        _finish;
    NSUInteger  _imagesCount;
    NSUInteger  _downloadedImagesCount;
    NSUInteger  _downloadCompletedImagesCount;
    NSArray*    _imagesURLs;
}

#if USE_APPLICATION_UNIT_TEST
- (void)testAppDelegate;
#else
- (void)test;
- (void)testSuspendResume;
#endif

@end
