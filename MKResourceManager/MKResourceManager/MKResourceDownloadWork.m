//
//  MediaResourceDownloadWork.m
//  MKResourceManager
//
//  Created by Mark Kryzhanouski on 7.12.10.
//  Copyright 2010 Mark Kryzhanouski. All rights reserved.
//

#import "MKResourceDownloadWork.h"
#import "MKResource+Private.h"
#import "MKResourceUtility.h"
//#import "MKHTTPHandlerClientPrivate.h"

@interface MKResourceDownloadWork ()

@property (nonatomic, weak) MKResourceManager* manager;
@property (nonatomic, strong) NSMutableURLRequest * urlRequest;
@property (nonatomic, strong) NSHTTPURLResponse * urlResponse;
@property (nonatomic, strong) id<MKHTTPHandlerClientPrivate> httpClient;
@property (nonatomic, strong) NSError* httpError;
@property (nonatomic, strong) NSURLConnection* theConnection;

@end


@implementation MKResourceDownloadWork

@synthesize urlData         = _urlData;
@synthesize resource        = _resource;
@synthesize manager         = _manager;
@synthesize urlRequest      = _urlRequest;
@synthesize urlResponse     = _urlResponse;
@synthesize httpClient      = _httpClient;
@synthesize httpError       = _httpError;
@synthesize theConnection   = _theConnection;

- (void)dealloc {
    [_theConnection cancel];
}

- (NSError*)formattedError {
	NSError* httpError = self.httpError;
    NSUInteger httpStatusCode = [self.urlResponse statusCode];
    NSDictionary* httpResponseHeaders = [self.urlResponse allHeaderFields];
	
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
            
            NSData* httpResponseData = [self.urlData data];
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

- (void)startDownloadWork:(MKResource*)aResource manager:(MKResourceManager * )aManager httpClient:(id<MKHTTPHandlerClientPrivate>)httpClient {
    self.httpClient = httpClient;
    self.resource = aResource;
    self.manager = aManager;
    _statusCode = 0;

	NSMutableURLRequest *dataRequest = [NSMutableURLRequest requestWithURL:self.resource.resourceURL cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                             timeoutInterval:60];
	self.urlRequest = dataRequest;
//    if (self.httpClient) {
//        [self.httpClient willSendRequest:dataRequest];
//    }

    self.theConnection = [[NSURLConnection alloc] initWithRequest:dataRequest delegate:self startImmediately:YES];

    if (self.theConnection == nil) {
        self.urlData = nil;
        [self.resource didFinishDownloadMR:nil error:nil httpResponse:nil];
    } else {
        NSLog(@"Start loading url:%@", self.resource.resourceURL);//Info
        self.urlData = [MKResourceBuffer buffer];
    }
}

- (void)cancelLoading {
    [self.theConnection cancel];
    self.theConnection = nil;
}

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response {
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*) response;
    self.urlResponse = httpResponse;
    
    _statusCode = [httpResponse statusCode];
    NSDictionary* dict = [httpResponse allHeaderFields];
    NSLog(@"response headers = %@ with status code: %d", dict, _statusCode);//Info

    NSString* contentType = [dict objectForKey:@"Content-Type"];
    if (contentType == nil || [contentType isEqualToString:@""]) {
        contentType = httpResponse.MIMEType;
    }
    [self.resource setContentType:contentType];

    long long contentLength = [response expectedContentLength];
    [self.resource setExpectedContentLength:contentLength];
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)incrementalData {
    int code = _statusCode / 100;
    if (code == 2) {
        [self.urlData appendData:incrementalData];
        NSUInteger downloadedLength = [self.urlData length];
        [self.resource setDownloadedLength:downloadedLength];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection {
    if ((_statusCode / 100) == 2) {
          // status 200, OK
        [self.resource didFinishDownloadMR:[self.urlData data] error:nil httpResponse:self.urlResponse];
    } else {
          // !OK
        NSError *mediaError = [self formattedError];
        NSLog(@"Error download data, url=%@: %@", self.resource.resourceURL, mediaError);//Error
        [self.resource didFinishDownloadMR:nil error:mediaError httpResponse:self.urlResponse];
//        if (self.httpClient) {
//			[self.httpClient request:self.urlRequest didFailWithError:mediaError responce:self.urlResponse];
//        }
    }
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error {
    NSLog(@"Error download data, url=%@: %@", self.resource.resourceURL, [error localizedDescription]);//Error
    self.httpError = error;
    NSError *mediaError = [self formattedError];
	[self.resource didFinishDownloadMR:nil error:mediaError httpResponse:self.urlResponse];
//    if (self.httpClient) {
//        [self.httpClient request:self.urlRequest didFailWithError:mediaError responce:self.urlResponse];
//    }
}

- (void)connection:(NSURLConnection*)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge*)challenge {
    NSLog(@"authentication required %@ ",[challenge failureResponse]);//Info
    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *) [challenge failureResponse];
    self.urlResponse = httpResponse;
    [[challenge sender] cancelAuthenticationChallenge:challenge];
	NSURL *remoteURL = [httpResponse URL];
#pragma unused(remoteURL)
//    PostAuthenticationFaultForURLwithCredential(remoteURL, nil);
}

@end
