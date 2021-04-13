//
//  HTTPPipelineTests.m
//  ownCloudSDKTests
//
//  Created by Felix Schwarz on 13.02.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <ownCloudSDK/ownCloudSDK.h>
#import <ownCloudMocking/ownCloudMocking.h>

#pragma mark - Partition Simulator
typedef BOOL(^PartitionSimulatorMeetsSignalRequirements)(OCHTTPPipeline *pipeline, NSSet<OCConnectionSignalID> *requiredSignals, NSError **failWithError);

typedef OCHTTPRequest *(^PartitionSimulatorPrepareRequestForScheduling)(OCHTTPPipeline *pipeline, OCHTTPRequest *request);
typedef NSError *(^PartitionSimulatorPostProcessFinishedTask)(OCHTTPPipeline *pipeline, OCHTTPPipelineTask *task, NSError *error);
typedef OCHTTPRequestInstruction(^PartitionSimulatorInstructionForFinishedTask)(OCHTTPPipeline *pipeline, OCHTTPPipelineTask *task, NSError *error);

typedef void(^PartitionSimulatorHandleValidationOfRequest)(OCHTTPPipeline *pipeline, OCHTTPRequest *request, OCCertificate *certificate, OCCertificateValidationResult validationResult, NSError *validationError, OCConnectionCertificateProceedHandler proceedHandler);

typedef BOOL(^PartitionSimulatorSimulateRequestHandling)(OCHTTPPipeline *pipeline, OCHTTPPipelinePartitionID partitionID, OCHTTPRequest *request, void(^completionHandler)(OCHTTPResponse *response));

typedef void(^PartitionSimulatorHandleResult)(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error);

@interface PartitionSimulator : NSObject <OCHTTPPipelinePartitionHandler>

@property(strong) OCHTTPPipelinePartitionID partitionID; //!< The ID of the partition
@property(nullable,strong) OCCertificate *certificate; //!< The certificate used by the partition.

@property(copy) PartitionSimulatorMeetsSignalRequirements meetsSignalRequirements;

@property(copy) PartitionSimulatorPrepareRequestForScheduling prepareRequestForScheduling;
@property(copy) PartitionSimulatorPostProcessFinishedTask postProcessFinishedTask;
@property(copy) PartitionSimulatorInstructionForFinishedTask instructionForFinishedTask;

@property(copy) PartitionSimulatorHandleValidationOfRequest handleValidationOfRequest;

@property(copy) PartitionSimulatorSimulateRequestHandling simulateRequestHandling;

@property(copy) PartitionSimulatorHandleResult handleResult;

@end

@implementation PartitionSimulator

+ (SEL)handleResultSelector
{
	return (@selector(handleResult:error:));
}

- (instancetype)initWithPartitionID:(OCHTTPPipelinePartitionID)partitionID
{
	if ((self = [super init]) != nil)
	{
		_partitionID = partitionID;
	}

	return (self);
}

#pragma mark - Requirements
- (BOOL)pipeline:(OCHTTPPipeline *)pipeline meetsSignalRequirements:(NSSet<OCConnectionSignalID> *)requiredSignals forTask:(OCHTTPPipelineTask *)task failWithError:(NSError *__autoreleasing  _Nullable *)outError
{
	if (self.meetsSignalRequirements != nil)
	{
		return (self.meetsSignalRequirements(pipeline, requiredSignals, outError));
	}

	return (YES);
}

#pragma mark - Scheduling
- (OCHTTPRequest *)pipeline:(OCHTTPPipeline *)pipeline prepareRequestForScheduling:(OCHTTPRequest *)request
{
	if (self.prepareRequestForScheduling != nil)
	{
		return (self.prepareRequestForScheduling(pipeline, request));
	}

	return (request);
}

- (nullable NSError *)pipeline:(OCHTTPPipeline *)pipeline postProcessFinishedTask:(OCHTTPPipelineTask *)task error:(nullable NSError *)error
{
	if (self.postProcessFinishedTask != nil)
	{
		return (self.postProcessFinishedTask(pipeline, task, error));
	}

	return (error);
}

- (OCHTTPRequestInstruction)pipeline:(OCHTTPPipeline *)pipeline instructionForFinishedTask:(OCHTTPPipelineTask *)task instruction:(OCHTTPRequestInstruction)inInstruction error:(nullable NSError *)error
{
	if (self.instructionForFinishedTask != nil)
	{
		return (self.instructionForFinishedTask(pipeline, task, error));
	}

	return (OCHTTPRequestInstructionDeliver);
}

#pragma mark - Certificate validation
- (void)pipeline:(OCHTTPPipeline *)pipeline handleValidationOfRequest:(OCHTTPRequest *)request certificate:(OCCertificate *)certificate validationResult:(OCCertificateValidationResult)validationResult validationError:(NSError *)validationError proceedHandler:(OCConnectionCertificateProceedHandler)proceedHandler
{
	if (self.handleValidationOfRequest != nil)
	{
		self.handleValidationOfRequest(pipeline, request, certificate, validationResult, validationError, proceedHandler);
		return;
	}

	proceedHandler(YES, nil);
}

#pragma mark - Response simulation
- (BOOL)pipeline:(OCHTTPPipeline *)pipeline partitionID:(OCHTTPPipelinePartitionID)partitionID simulateRequestHandling:(OCHTTPRequest *)request completionHandler:(void(^)(OCHTTPResponse *response))completionHandler
{
	if (_simulateRequestHandling)
	{
		return (_simulateRequestHandling(pipeline, partitionID, request, completionHandler));
	}

	return (YES);
}

#pragma mark - Selector delivery
- (void)handleResult:(OCHTTPRequest *)request error:(NSError *)error
{
	_handleResult(request, nil, error);
}

@end

@interface OCHTTPPipeline (Setters)

- (void)setAlwaysUseDownloadTasks:(BOOL)always;

@end

@implementation OCHTTPPipeline (Setters)

-(void)setAlwaysUseDownloadTasks:(BOOL)always
{
	_alwaysUseDownloadTasks = always;
}

@end


#pragma mark - Progress observer helper class
@interface ProgressObserver : NSObject

@property(strong) NSProgress *progress;
@property(copy) void(^changeHandler)(NSString *keyPath, NSProgress *progress);

- (instancetype)initFor:(NSProgress *)progress changeHandler:(void(^)(NSString *keyPath, NSProgress *progress))changeHandler;

@end

@implementation ProgressObserver

- (instancetype)initFor:(NSProgress *)progress changeHandler:(void(^)(NSString *keyPath, NSProgress *progress))changeHandler
{
	if ((self = [super init]) != nil)
	{
		self.progress = progress;
		self.changeHandler = changeHandler;

		[progress addObserver:self forKeyPath:@"fractionCompleted" options:0 context:NULL];
	}

	return (self);
}

- (void)dealloc
{
	[_progress removeObserver:self forKeyPath:@"fractionCompleted" context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
	_changeHandler(keyPath,_progress);
}

@end

#pragma mark - Pipeline tests
@interface HTTPPipelineTests : XCTestCase
{
	BOOL _forceDownloads;
}

@end

@implementation HTTPPipelineTests

// Add request while attached, detach after receiving response
- (void)testSimpleHTTPRequest
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed started"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed started"];
	XCTestExpectation *requestCompletedExpectation = [self expectationWithDescription:@"request completed started"];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		OCHTTPRequest *request;

		if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
		{
			request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

				[requestCompletedExpectation fulfill];

				[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
					[detachCompletedExpectation fulfill];

					[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
						[pipelineStoppedExpectation fulfill];
					} graceful:YES];
				}];
			};

			[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
				[attachCompletedExpectation fulfill];
			}];

			[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID];
		}
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testSimpleHTTPRequestWithDownloadRequests
{
	_forceDownloads = YES;
	[self testSimpleHTTPRequest];
	_forceDownloads = NO;
}

// - Add request while detached, wait 3 seconds, then attach and receive response (+ check number of pending finished tasks at various points)
// - Detach, send new request, wait 3 seconds, fail if response was received inbetween, check number of pending finished tasks to be 1
// - Reattach, receive queued response, stop pipeline
- (void)testDetachedFinalQueueing
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed"];
	XCTestExpectation *requestOneCompletedExpectation = [self expectationWithDescription:@"request 1 completed"];
	XCTestExpectation *requestTwoCompletedExpectation = [self expectationWithDescription:@"request 2 completed"];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		OCHTTPRequest *request;

		if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
		{
			request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				XCTAssert(error==nil);

				OCLogDebug(@"<1> request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"<1> %@", [response responseDescriptionPrefixed:NO]);

				[requestOneCompletedExpectation fulfill];

				[pipeline.backend queueBlock:^{
					XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==0);

					[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
						XCTAssert(error==nil);

						[detachCompletedExpectation fulfill];

						OCHTTPRequest *request;

						if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
						{
							request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
								XCTFail(@"Response delivered while detached");
							};

							[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID isFinal:YES];
						}

						dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
							XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==1);

							request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
								OCLogDebug(@"<2> request=%@, response=%@, error=%@", request, response, error);
								OCLogDebug(@"<2> %@", [response responseDescriptionPrefixed:NO]);

								[requestTwoCompletedExpectation fulfill];
							};

							[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
								XCTAssert(error==nil);

								[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
									[pipelineStoppedExpectation fulfill];
								} graceful:YES];
							}];
						});
					}];
				}];
			};

			XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==0);

			[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID isFinal:YES];

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==1);

				[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
					[attachCompletedExpectation fulfill];
				}];
			});
		}
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testDetachedFinalQueueingWithDownloadRequests
{
	_forceDownloads = YES;
	[self testDetachedFinalQueueing];
	_forceDownloads = NO;
}

// - Add request while detached, wait 3 seconds, then attach and check that the request hasn't yet been sent
// - Detach after receiving the response, send new request, wait 3 seconds, fail if response was received inbetween, check number of pending finished tasks to be 0
// - Reattach, wait for request to be scheduled and responded to, stop pipeline
- (void)testDetachedNonFinalQueueing
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed"];
	XCTestExpectation *requestOneCompletedExpectation = [self expectationWithDescription:@"request 1 completed"];
	XCTestExpectation *requestTwoCompletedExpectation = [self expectationWithDescription:@"request 2 completed"];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		OCHTTPRequest *request;

		if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
		{
			request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				XCTAssert(error==nil);

				OCLogDebug(@"<1> request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"<1> %@", [response responseDescriptionPrefixed:NO]);

				[requestOneCompletedExpectation fulfill];

				[pipeline.backend queueBlock:^{
					XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==0);

					[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
						XCTAssert(error==nil);

						[detachCompletedExpectation fulfill];

						OCHTTPRequest *request;

						if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
						{
							request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
								XCTFail(@"Response delivered while detached");
							};

							[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID isFinal:NO];
						}

						dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
							XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==0);

							request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
								OCLogDebug(@"<2> request=%@, response=%@, error=%@", request, response, error);
								OCLogDebug(@"<2> %@", [response responseDescriptionPrefixed:NO]);

								[requestTwoCompletedExpectation fulfill];

								[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
									[pipelineStoppedExpectation fulfill];
								} graceful:YES];
							};

							[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
								XCTAssert(error==nil);
							}];
						});
					}];
				}];
			};

			XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==0);

			[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID isFinal:NO];

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==0);

				[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
					[attachCompletedExpectation fulfill];
				}];
			});
		}
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testDetachedNonFinalQueueingWithDownloadRequests
{
	_forceDownloads = YES;
	[self testDetachedNonFinalQueueing];
	_forceDownloads = NO;
}

// - queue a non-final request while detached
// - cancel individual request before execution
// - attach, wait for delivery and verify outcome
- (void)testDetachedCancellation
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed"];
	XCTestExpectation *requestOneCompletedExpectation = [self expectationWithDescription:@"request 1 completed"];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		OCHTTPRequest *request;

		if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
		{
			request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				XCTAssert([error isOCErrorWithCode:OCErrorRequestCancelled]);

				OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

				[requestOneCompletedExpectation fulfill];

				[pipeline.backend queueBlock:^{
					XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==0);

					[pipeline detachPartitionHandlerForPartitionID:partitionHandler.partitionID completionHandler:^(id sender, NSError *error) {
						XCTAssert(error==nil);

						[detachCompletedExpectation fulfill];

						[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
							[pipelineStoppedExpectation fulfill];
						} graceful:YES];
					}];
				}];
			};

			XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==0);

			[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID isFinal:NO];

			[pipeline cancelRequest:request];

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==1);

				[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
					[attachCompletedExpectation fulfill];
				}];
			});
		}
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testDetachedCancellationWithDownloadRequests
{
	_forceDownloads = YES;
	[self testDetachedCancellation];
	_forceDownloads = NO;
}

// - queue a non-final request while detached
// - cancel all requests for partition before execution
// - attach, wait for delivery and verify outcome
- (void)testDetachedPartitionCancellation
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed"];
	XCTestExpectation *requestOneCompletedExpectation = [self expectationWithDescription:@"request 1 completed"];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		OCHTTPRequest *request;

		if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
		{
			request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				XCTAssert([error isOCErrorWithCode:OCErrorRequestCancelled]);

				OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

				[requestOneCompletedExpectation fulfill];

				[pipeline.backend queueBlock:^{
					XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==0);

					[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
						XCTAssert(error==nil);

						[detachCompletedExpectation fulfill];

						[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
							[pipelineStoppedExpectation fulfill];
						} graceful:YES];
					}];
				}];
			};

			XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==0);

			[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID isFinal:NO];

			[pipeline cancelRequestsForPartitionID:partitionHandler.partitionID queuedOnly:YES];

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==1);

				[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
					[attachCompletedExpectation fulfill];
				}];
			});
		}
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testDetachedPartitionCancellationWithDownloadRequests
{
	_forceDownloads = YES;
	[self testDetachedPartitionCancellation];
	_forceDownloads = NO;
}

// - create two partitions
// - queue one final request for each of partitions while detached
// - attach first partition, verify that it gets the right response and that the second request's response is not yet delivered
// - attach second parition, verify that it gets the right response and that certificates match between first partition and second partition (testing certificate caching)
- (void)testPartitionIsolation
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed"];
	XCTestExpectation *requestOneCompletedExpectation = [self expectationWithDescription:@"request 1 completed"];
	XCTestExpectation *requestTwoCompletedExpectation = [self expectationWithDescription:@"request 2 completed"];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partition1 = [[PartitionSimulator alloc] initWithPartitionID:@"partition-1"];
	PartitionSimulator *partition2 = [[PartitionSimulator alloc] initWithPartitionID:@"partition-2"];

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		OCHTTPRequest *request1;
		OCHTTPRequest *request2;

		OCHTTPRequestID requestID1, requestID2;

		__block OCCertificate *certificate1=nil, *certificate2=nil;

		request1 = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]];
		request2 = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]];

		requestID1 = request1.identifier;
		requestID2 = request2.identifier;

		[request1 addHeaderFields:@{ @"X-Request-Partition" : @"1" }];
		[request2 addHeaderFields:@{ @"X-Request-Partition" : @"2" }];

		XCTAssert(requestID1 != nil);
		XCTAssert(requestID2 != nil);
		XCTAssert(![requestID1 isEqual:requestID2]);

		request1.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
			XCTAssert(error==nil);
			XCTAssert([request.identifier isEqual:requestID1]);
			XCTAssert([response.requestID isEqual:requestID1]);

			OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
			OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

			[requestOneCompletedExpectation fulfill];

			XCTAssert(response.certificate != nil);
			certificate1 = response.certificate;

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				NSUInteger partition1PendingDeliveryCount = [pipeline tasksPendingDeliveryForPartitionID:partition1.partitionID];
				NSUInteger partition2PendingDeliveryCount = [pipeline tasksPendingDeliveryForPartitionID:partition2.partitionID];

				OCLogDebug(@"Pending(B) 1: %ld, 2: %ld", partition1PendingDeliveryCount, partition2PendingDeliveryCount)

				[pipeline.backend dumpDBTable];

				XCTAssert(partition1PendingDeliveryCount==0);
				XCTAssert(partition2PendingDeliveryCount==1);

				[pipeline attachPartitionHandler:partition2 completionHandler:^(id sender, NSError *error) {
					request2.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
						XCTAssert(error==nil);
						XCTAssert([request.identifier isEqual:requestID2]);
						XCTAssert([response.requestID isEqual:requestID2]);

						XCTAssert(response.certificate != nil);
						certificate2 = response.certificate;

						XCTAssert([certificate1 isEqual:certificate2]);

						[requestTwoCompletedExpectation fulfill];

						[pipeline detachPartitionHandler:partition2 completionHandler:^(id sender, NSError *error) {
							XCTAssert(error==nil);

							[pipeline detachPartitionHandler:partition1 completionHandler:^(id sender, NSError *error) {
								XCTAssert(error==nil);

								[detachCompletedExpectation fulfill];

								[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
									[pipelineStoppedExpectation fulfill];
								} graceful:YES];
							}];
						}];
					};
				}];
			});
		};

		request2.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
			XCTFail(@"Request 2 may not be delivered");
		};

		XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partition1.partitionID]==0);
		XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partition2.partitionID]==0);

		[pipeline enqueueRequest:request1 forPartitionID:partition1.partitionID isFinal:YES];
		[pipeline enqueueRequest:request2 forPartitionID:partition2.partitionID isFinal:YES];

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			NSUInteger partition1PendingDeliveryCount = [pipeline tasksPendingDeliveryForPartitionID:partition1.partitionID];
			NSUInteger partition2PendingDeliveryCount = [pipeline tasksPendingDeliveryForPartitionID:partition2.partitionID];

			OCLogDebug(@"Pending(A) 1: %ld, 2: %ld", partition1PendingDeliveryCount, partition2PendingDeliveryCount)

			[pipeline.backend dumpDBTable];

			XCTAssert(partition1PendingDeliveryCount==1);
			XCTAssert(partition2PendingDeliveryCount==1);

			[pipeline attachPartitionHandler:partition1 completionHandler:^(id sender, NSError *error) {
				[attachCompletedExpectation fulfill];
			}];
		});
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testPartitionIsolationWithDownloadRequests
{
	_forceDownloads = YES;
	[self testPartitionIsolation];
	_forceDownloads = NO;
}

// - create one partition and attach it
// - create and enqueue three requests with different signal requirements
// - verify each signal requirement is checked
// - let request1 meet signal requirements immediately
// - let request2 miss signal requirements
// - fail request3 with an error
// - after 3 seconds, change signal requirements handler to let request2 pass and signal pipeline it needs scheduling
// - verify request1 and request3 have already finished and that request2 has not
// - verify signal requirement for request2 is checked
// - wait for request2 to complete
- (void)testSignals
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed"];
	XCTestExpectation *requestOneCompletedExpectation = [self expectationWithDescription:@"request 1 completed"];
	XCTestExpectation *requestTwoCompletedExpectation = [self expectationWithDescription:@"request 2 completed"];
	XCTestExpectation *requestThreeCompletedExpectation = [self expectationWithDescription:@"request 2 completed"];
	__block XCTestExpectation *signalImmediatelyCheckedExpectation = [self expectationWithDescription:@"signalImmediatelyChecked"];
	__block XCTestExpectation *signalFailCheckedExpectation = [self expectationWithDescription:@"signalFailChecked"];
	__block XCTestExpectation *signalLaterCheckedOnceExpectation = [self expectationWithDescription:@"signalLaterCheckedOnce"];
	__block XCTestExpectation *signalLaterCheckedTwiceExpectation = [self expectationWithDescription:@"signalLaterCheckedTwice"];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partition1 = [[PartitionSimulator alloc] initWithPartitionID:@"partition-1"];

	partition1.meetsSignalRequirements = ^BOOL(OCHTTPPipeline *pipeline, NSSet<OCConnectionSignalID> *requiredSignals, NSError *__autoreleasing *failWithError) {
		if ([requiredSignals containsObject:@"immediately"])
		{
			[signalImmediatelyCheckedExpectation fulfill];
			signalImmediatelyCheckedExpectation = nil;
			return (YES);
		}

		if ([requiredSignals containsObject:@"fail"])
		{
			[signalFailCheckedExpectation fulfill];
			signalFailCheckedExpectation = nil;
			*failWithError = OCError(OCErrorFeatureNotSupportedForItem);
			return (NO);
		}

		if ([requiredSignals containsObject:@"later"])
		{
			[signalLaterCheckedOnceExpectation fulfill];
			signalLaterCheckedOnceExpectation = nil;
		}

		return (NO);
	};

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		[pipeline attachPartitionHandler:partition1 completionHandler:^(id sender, NSError *error) {
			OCHTTPRequest *request1;
			OCHTTPRequest *request2;
			OCHTTPRequest *request3;

			__block BOOL request1Done=NO, request2Done=NO, request3Done=NO;

			[attachCompletedExpectation fulfill];

			request1 = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]];
			request1.requiredSignals = [NSSet setWithObject:@"immediately"];
			request1.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				XCTAssert(error==nil);
				XCTAssert(response.certificate != nil);

				OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

				request1Done = YES;

				[requestOneCompletedExpectation fulfill];
			};

			request2 = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]];
			request2.requiredSignals = [NSSet setWithObject:@"later"];
			request2.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				XCTAssert(error==nil);
				XCTAssert(response.certificate != nil);

				OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

				request2Done = YES;

				[requestTwoCompletedExpectation fulfill];

				[pipeline detachPartitionHandler:partition1 completionHandler:^(id sender, NSError *error) {
					XCTAssert(error==nil);

					[detachCompletedExpectation fulfill];

					[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
						[pipelineStoppedExpectation fulfill];
					} graceful:YES];
				}];
			};

			request3 = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]];
			request3.requiredSignals = [NSSet setWithObject:@"fail"];
			request3.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				XCTAssert([error isOCErrorWithCode:OCErrorFeatureNotSupportedForItem]);
				XCTAssert(response.certificate == nil);

				OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

				request3Done = YES;

				[requestThreeCompletedExpectation fulfill];
			};

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				XCTAssert(request1Done);
				XCTAssert(!request2Done);
				XCTAssert(request3Done);

				partition1.meetsSignalRequirements = ^BOOL(OCHTTPPipeline *pipeline, NSSet<OCConnectionSignalID> *requiredSignals, NSError *__autoreleasing *failWithError) {
					if ([requiredSignals containsObject:@"later"])
					{
						[signalLaterCheckedTwiceExpectation fulfill];
						signalLaterCheckedTwiceExpectation = nil;
						return (YES);
					}

					return (NO);
				};

				[pipeline setPipelineNeedsScheduling];
			});

			[pipeline enqueueRequest:request1 forPartitionID:partition1.partitionID isFinal:YES];
			[pipeline enqueueRequest:request2 forPartitionID:partition1.partitionID isFinal:YES];
			[pipeline enqueueRequest:request3 forPartitionID:partition1.partitionID isFinal:YES];
		}];
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testSignalsWithDownloadRequests
{
	_forceDownloads = YES;
	[self testSignals];
	_forceDownloads = NO;
}

// - create pipeline and attach
// - schedule (G-1)*5 request in G-1 groups (and 5 requests without groupID)
// - limit maximumConcurrentRequests to 1 request to eliminate timing issues where one group's request could finish sooner than another one's
// - keep record of the group IDs of scheduled requests
// - check that groupIDs and requests without groupID are evenly serviced
// - check order in which the group's requests were serviced is the order in which they were enqueued
- (void)testGrouping
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed"];
	XCTestExpectation *requestsCompletedExpectation = [self expectationWithDescription:@"requests completed"];

	NSMutableDictionary<NSString *,NSMutableArray *> *requestIDsByGroupID = [NSMutableDictionary new];
	NSMutableArray *scheduledGroupIDs = [NSMutableArray new];
	NSMutableArray *finishedGroupIDs = [NSMutableArray new];
	NSMutableDictionary<NSString *, OCHTTPRequest *> *requestsByRequestID = [NSMutableDictionary new];
	NSMutableArray<OCHTTPRequest *> *finishedRequests = [NSMutableArray new];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;
	pipeline.maximumConcurrentRequests = 1;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";
	partitionHandler.prepareRequestForScheduling = ^OCHTTPRequest *(OCHTTPPipeline *pipeline, OCHTTPRequest *request) {
		@synchronized (scheduledGroupIDs)
		{
			[scheduledGroupIDs addObject:request.groupID != nil ? request.groupID : [NSNull null]];

			// Check order of requests from groups
			NSString *groupID =  request.groupID != nil ? request.groupID : @"default";
			XCTAssert([requestIDsByGroupID[groupID].firstObject isEqual:request.identifier]);
			[requestIDsByGroupID[groupID] removeObjectAtIndex:0];
		}

		return (request);
	};

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
			[attachCompletedExpectation fulfill];
			NSUInteger groupCount = 8;
			__block NSUInteger requestCount = groupCount*5;

			for (NSUInteger i=0; i<requestCount; i++)
			{
				OCHTTPRequest *request;

				request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]];
				request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
					XCTAssert(error==nil);
					XCTAssert(response!=nil);

					@synchronized(finishedGroupIDs)
					{
						if (request.groupID)
						{
							[finishedGroupIDs addObject:request.groupID];
						}
						else
						{
							[finishedGroupIDs addObject:[NSNull null]];
						}

						[finishedRequests addObject:request];

						requestCount--;

						OCLogDebug(@"%ld requests remaining", requestCount);

						if (requestCount == 0)
						{
							[requestsCompletedExpectation fulfill];

							[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
								XCTAssert(error==nil);

								[detachCompletedExpectation fulfill];

								[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {

									OCLogDebug(@"Finished group IDs: %@\nScheduled group IDs: %@", finishedGroupIDs, scheduledGroupIDs);

									// Test that the first [groupCount] groupIDs are all different
									XCTAssert([NSSet setWithArray:[scheduledGroupIDs subarrayWithRange:NSMakeRange(0, groupCount)]].count == groupCount);

									// Test uniform repetition of groupIDs during scheduling using the first [groupCount] groupIDs
									[scheduledGroupIDs enumerateObjectsUsingBlock:^(id  _Nonnull groupID, NSUInteger idx, BOOL * _Nonnull stop) {
										if (idx >= groupCount)
										{
											XCTAssert([scheduledGroupIDs[idx % groupCount] isEqual:groupID]);
										}
									}];

									[pipelineStoppedExpectation fulfill];
								} graceful:YES];
							}];
						}
					}
				};

				if ((i % groupCount) != (groupCount-1))
				{
					request.groupID = [@"group" stringByAppendingFormat:@"%ld", (i % groupCount)];
				}
				else
				{
					request.groupID = @"default";
				}

				if (requestIDsByGroupID[request.groupID] == nil)
				{
					requestIDsByGroupID[request.groupID] = [NSMutableArray new];
				}

				[requestIDsByGroupID[request.groupID] addObject:request.identifier];
				requestsByRequestID[request.identifier] = request;

				if ([request.groupID isEqual:@"default"])
				{
					request.groupID = nil;
				}
			}

			@synchronized (scheduledGroupIDs)
			{
				for (NSString *groupID in requestIDsByGroupID)
				{
					for (NSString *requestID in requestIDsByGroupID[groupID])
					{
						[pipeline enqueueRequest:requestsByRequestID[requestID] forPartitionID:partitionHandler.partitionID isFinal:NO];
					}
				}
			}
		}];
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testGroupingWithDownloadRequests
{
	_forceDownloads = YES;
	[self testGrouping];
	_forceDownloads = NO;
}

// - Limit maximumConcurrentRequests to 10
// - Schedule 50 requests
// - Keep track of the number of running requests and test that their number is <= (maximumConcurrentRequests+1) at all times (the +1 is due to the possibility of scheduling happening before delivery of a request that's already finished at that point)
- (void)testMaxConcurrency
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed"];
	XCTestExpectation *requestsCompletedExpectation = [self expectationWithDescription:@"requests completed"];

	NSMutableArray<OCHTTPRequest *> *scheduleRequests = [NSMutableArray new];
	NSMutableArray<OCHTTPRequestID> *runningRequestIDs = [NSMutableArray new];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;
	pipeline.maximumConcurrentRequests = 10;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";
	partitionHandler.prepareRequestForScheduling = ^OCHTTPRequest *(OCHTTPPipeline *pipeline, OCHTTPRequest *request) {
		@synchronized (runningRequestIDs)
		{
			[runningRequestIDs addObject:request.identifier];

			OCLogDebug(@"Running requests while preparing to schedule: %ld", runningRequestIDs.count);
			XCTAssert(runningRequestIDs.count <= (pipeline.maximumConcurrentRequests+1));
		}

		return (request);
	};

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
			[attachCompletedExpectation fulfill];
			__block NSUInteger requestCount = 50;
			NSUInteger requests = requestCount;

			for (NSUInteger i=0; i<requests; i++)
			{
				OCHTTPRequest *request;

				request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]];
				request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
					XCTAssert(error==nil);
					XCTAssert(response!=nil);

					@synchronized (runningRequestIDs)
					{
						[runningRequestIDs removeObject:request.identifier];

						OCLogDebug(@"Running requests after finishing request: %ld", runningRequestIDs.count);
						XCTAssert(runningRequestIDs.count <= (pipeline.maximumConcurrentRequests+1));

						requestCount--;

						OCLogDebug(@"%ld requests remaining", requestCount);

						if (requestCount == 0)
						{
							[requestsCompletedExpectation fulfill];

							[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
								XCTAssert(error==nil);

								[detachCompletedExpectation fulfill];

								[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
									[pipelineStoppedExpectation fulfill];
								} graceful:YES];
							}];
						}
					}
				};

				[scheduleRequests addObject:request];
			}

			for (OCHTTPRequest *request in scheduleRequests)
			{
				[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID isFinal:NO];
			}
		}];
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testMaxConcurrencyWithDownloadRequests
{
	_forceDownloads = YES;
	[self testMaxConcurrency];
	_forceDownloads = NO;
}

- (void)testRedirection
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed started"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed started"];
	XCTestExpectation *requestCompletedExpectation = [self expectationWithDescription:@"request completed started"];

	// Apple documentation: "Tasks in background sessions automatically follow redirects."
	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		OCHTTPRequest *request;

		if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"http://bit.ly/2GTa2wD"]]) != nil)
		{
			request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

				XCTAssert([response.redirectURL.absoluteString isEqual:@"https://goo.gl/dh6yW5"]);

				[requestCompletedExpectation fulfill];

				[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
					[detachCompletedExpectation fulfill];

					[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
						[pipelineStoppedExpectation fulfill];
					} graceful:YES];
				}];
			};

			[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
				[attachCompletedExpectation fulfill];
			}];

			[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID];
		}
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testRedirectionWithDownloadRequests
{
	_forceDownloads = YES;
	[self testRedirection];
	_forceDownloads = NO;
}

// - Queue 50 requests
// - Stop pipeline gracefully after 1 second
// - Check that all 50 requests finish without any error
- (void)testGracefulStop
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed"];

	NSMutableArray<OCHTTPRequest *> *scheduleRequests = [NSMutableArray new];

	__block NSUInteger requestCount = 50;

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
			[attachCompletedExpectation fulfill];
			NSUInteger requests = requestCount;

			for (NSUInteger i=0; i<requests; i++)
			{
				OCHTTPRequest *request;

				request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]];
				request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
					XCTAssert(error==nil);

					requestCount--;
					OCLogDebug(@"%ld requests remaining", requestCount);
				};

				[scheduleRequests addObject:request];
			}

			for (OCHTTPRequest *request in scheduleRequests)
			{
				[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID isFinal:NO];
			}

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
					[pipelineStoppedExpectation fulfill];

					[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
						XCTAssert(error==nil);

						[detachCompletedExpectation fulfill];
					}];
				} graceful:YES];
			});
		}];
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];

	XCTAssert(requestCount==0);
}

- (void)testGracefulStopWithDownloadRequests
{
	_forceDownloads = YES;
	[self testGracefulStop];
	_forceDownloads = NO;
}

// - Queue 50 requests, 25 of which are marked non-critical
// - Stop pipeline gracefully after 1 second
// - Check that all 50 requests finish
// - Check that only non-critical requests finished with cancellation-error
- (void)testGracefulStopWithNonCritical
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed"];

	NSMutableArray<OCHTTPRequest *> *scheduleRequests = [NSMutableArray new];

	__block NSUInteger requestCount = 150;
	__block NSUInteger cancelledRequests = 0;
	NSUInteger requests = requestCount;

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
			[attachCompletedExpectation fulfill];

			for (NSUInteger i=0; i<requests; i++)
			{
				OCHTTPRequest *request;

				request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]];
				request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
					if ([error isOCErrorWithCode:OCErrorRequestCancelled])
					{
						cancelledRequests++;
						XCTAssert(request.isNonCritial);
					}

					requestCount--;
					OCLogDebug(@"%ld requests remaining", requestCount);
				};
				request.isNonCritial = (i >= (requests /2));

				[scheduleRequests addObject:request];
			}

			for (OCHTTPRequest *request in scheduleRequests)
			{
				[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID isFinal:NO];
			}

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[pipeline.backend dumpDBTable];

				[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
					[pipelineStoppedExpectation fulfill];

					[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
						XCTAssert(error==nil);

						[detachCompletedExpectation fulfill];
					}];
				} graceful:YES];
			});
		}];
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];

	XCTAssert(requestCount==0);
	XCTAssert(cancelledRequests > 0);
}

- (void)testGracefulStopWithNonCriticalWithDownloadRequests
{
	_forceDownloads = YES;
	[self testGracefulStopWithNonCritical];
	_forceDownloads = NO;
}

// - Queue 50 requests, 25 of which are marked non-critical
// - Stop pipeline non-gracefully after 1 second
// - Check that at least some requests finish with cancellation-error
- (void)testNonGracefulStop
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed"];

	NSMutableArray<OCHTTPRequest *> *scheduleRequests = [NSMutableArray new];

	__block NSUInteger cancelledRequests = 0;

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
			[attachCompletedExpectation fulfill];
			__block NSUInteger requestCount = 150;
			NSUInteger requests = requestCount;

			for (NSUInteger i=0; i<requests; i++)
			{
				OCHTTPRequest *request;

				request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://download.owncloud.org/community/owncloud-10.1.0.tar.bz2"]];
				request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
					if ([error isOCErrorWithCode:OCErrorRequestCancelled])
					{
						cancelledRequests++;
					}

					requestCount--;
					OCLogDebug(@"%ld requests remaining", requestCount);
				};

				[scheduleRequests addObject:request];
			}

			for (OCHTTPRequest *request in scheduleRequests)
			{
				[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID isFinal:NO];
			}

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[pipeline.backend dumpDBTable];

				[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
					[pipelineStoppedExpectation fulfill];

					[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
						XCTAssert(error==nil);

						[detachCompletedExpectation fulfill];
					}];
				} graceful:NO];
			});
		}];
	}];

	[self waitForExpectationsWithTimeout:240 handler:nil];

	XCTAssert(cancelledRequests!=0);
}

- (void)testNonGracefulStopWithDownloadRequests
{
	_forceDownloads = YES;
	[self testNonGracefulStop];
	_forceDownloads = NO;
}

// - Creates pipeline 1 with a maximumConcurrentRequests limit and a file-backed backend
// - Adds 50 requests
// - After 1 second, non-gracefully stops the pipeline
// - Creates a new pipeline 2 with a new backend using the same file
// - Checks that all requests have been scheduled and finished
// - Checks that some requests finished with cancellation error
- (void)testPipelineRecoveryWithRecreatedBackend
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed"];

	XCTestExpectation *secondPipelineStartedExpectation = [self expectationWithDescription:@"second pipeline started"];
	XCTestExpectation *secondPipelineStoppedExpectation = [self expectationWithDescription:@"second pipeline stopped"];
	XCTestExpectation *secondAttachCompletedExpectation = [self expectationWithDescription:@"second attach completed"];
	XCTestExpectation *secondDetachCompletedExpectation = [self expectationWithDescription:@"second detach completed"];

	NSMutableArray<OCHTTPRequest *> *scheduleRequests = [NSMutableArray new];

	__block NSUInteger cancelledRequests = 0;
	__block NSUInteger requestCount = 50;
	NSUInteger requests = requestCount;

	__block OCHTTPPipeline *secondPipeline;

	NSURL *temporaryDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
	NSURL *temporaryBackendDBURL = [temporaryDirectoryURL URLByAppendingPathComponent:[NSUUID UUID].UUIDString];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:[[OCHTTPPipelineBackend alloc] initWithSQLDB:[[OCSQLiteDB alloc] initWithURL:temporaryBackendDBURL] temporaryFilesRoot:nil] configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;
	pipeline.maximumConcurrentRequests = 15;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";
	partitionHandler.handleResult = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
		if ([error isOCErrorWithCode:OCErrorRequestCancelled])
		{
			cancelledRequests++;
		}

		requestCount--;
		OCLogDebug(@"%ld requests remaining", requestCount);

		if (requestCount == 0)
		{
			[secondPipeline stopWithCompletionHandler:^(id sender, NSError *error) {
				[secondPipelineStoppedExpectation fulfill];

				[secondPipeline detachPartitionHandlerForPartitionID:@"partition-1" completionHandler:^(id sender, NSError *error) {
					XCTAssert(error==nil);

					[secondDetachCompletedExpectation fulfill];
				}];
			} graceful:YES];
		}
	};

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
			[attachCompletedExpectation fulfill];

			for (NSUInteger i=0; i<requests; i++)
			{
				OCHTTPRequest *request;

				request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]];

				// Can't use request.ephermalResultHandler because those get lost when re-creating the backend
				request.resultHandlerAction = [PartitionSimulator handleResultSelector];

				[scheduleRequests addObject:request];
			}

			for (OCHTTPRequest *request in scheduleRequests)
			{
				[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID isFinal:NO];
			}

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				[pipeline.backend dumpDBTable];

				[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
					XCTAssert(requestCount > 0); // This test only makes sense if there are outstanding requests

					[pipelineStoppedExpectation fulfill];

					[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
						XCTAssert(error==nil);

						[detachCompletedExpectation fulfill];

						if ((secondPipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:[[OCHTTPPipelineBackend alloc] initWithSQLDB:[[OCSQLiteDB alloc] initWithURL:temporaryBackendDBURL] temporaryFilesRoot:nil] configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]]) != nil)
						{
							[secondPipeline startWithCompletionHandler:^(id sender, NSError *error) {
								XCTAssert(error==nil);
								[secondPipelineStartedExpectation fulfill];

								[secondPipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
									XCTAssert(error==nil);
									[secondAttachCompletedExpectation fulfill];
								}];
							}];
						}
					}];
				} graceful:NO];
			});
		}];
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];

	XCTAssert(cancelledRequests!=0);
	XCTAssert(requestCount==0);

	[[NSFileManager defaultManager] removeItemAtURL:temporaryBackendDBURL error:NULL];
}

// - Creates pipeline 1 with a maximumConcurrentRequests limit and a file-backed backend
// - Adds 50 requests
// - After 1 second, non-gracefully stops the pipeline
// - Creates a new pipeline 2 reusing the same backend
// - Checks that all requests have been scheduled and finished
// - Checks that some requests finished with cancellation error
// - Uses ephermal result handlers instead, so this test can only pass if the backend preserves them
- (void)testPipelineRecoveryWithReusedBackend
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed"];

	XCTestExpectation *secondPipelineStartedExpectation = [self expectationWithDescription:@"second pipeline started"];
	XCTestExpectation *secondPipelineStoppedExpectation = [self expectationWithDescription:@"second pipeline stopped"];
	XCTestExpectation *secondAttachCompletedExpectation = [self expectationWithDescription:@"second attach completed"];
	XCTestExpectation *secondDetachCompletedExpectation = [self expectationWithDescription:@"second detach completed"];

	NSMutableArray<OCHTTPRequest *> *scheduleRequests = [NSMutableArray new];

	__block NSUInteger cancelledRequests = 0;
	__block NSUInteger requestCount = 50;
	NSUInteger requests = requestCount;

	__block OCHTTPPipeline *secondPipeline;

	NSURL *temporaryDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
	NSURL *temporaryBackendDBURL = [temporaryDirectoryURL URLByAppendingPathComponent:[NSUUID UUID].UUIDString];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:[[OCHTTPPipelineBackend alloc] initWithSQLDB:[[OCSQLiteDB alloc] initWithURL:temporaryBackendDBURL] temporaryFilesRoot:nil] configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;
	pipeline.maximumConcurrentRequests = 15;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
			[attachCompletedExpectation fulfill];

			for (NSUInteger i=0; i<requests; i++)
			{
				OCHTTPRequest *request;

				request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]];

				request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
					if ([error isOCErrorWithCode:OCErrorRequestCancelled])
					{
						cancelledRequests++;
					}

					requestCount--;
					OCLogDebug(@"%ld requests remaining", requestCount);

					if (requestCount == 0)
					{
						[secondPipeline stopWithCompletionHandler:^(id sender, NSError *error) {
							[secondPipelineStoppedExpectation fulfill];

							[secondPipeline detachPartitionHandlerForPartitionID:@"partition-1" completionHandler:^(id sender, NSError *error) {
								XCTAssert(error==nil);

								[secondDetachCompletedExpectation fulfill];
							}];
						} graceful:YES];
					}
				};

				[scheduleRequests addObject:request];
			}

			for (OCHTTPRequest *request in scheduleRequests)
			{
				[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID isFinal:NO];
			}

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				OCHTTPPipelineBackend *backend = pipeline.backend;

				[pipeline.backend dumpDBTable];

				[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
					XCTAssert(requestCount > 0); // This test only makes sense if there are outstanding requests
					[pipelineStoppedExpectation fulfill];

					[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
						XCTAssert(error==nil);

						[detachCompletedExpectation fulfill];

						if ((secondPipeline = [[OCHTTPPipeline alloc] initWithIdentifier:pipeline.identifier backend:backend configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]]) != nil)
						{
							[secondPipeline startWithCompletionHandler:^(id sender, NSError *error) {
								XCTAssert(error==nil);
								[secondPipelineStartedExpectation fulfill];

								[secondPipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
									XCTAssert(error==nil);
									[secondAttachCompletedExpectation fulfill];
								}];
							}];
						}
					}];
				} graceful:NO];
			});
		}];
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];

	XCTAssert(cancelledRequests!=0);
	XCTAssert(requestCount==0);

	[[NSFileManager defaultManager] removeItemAtURL:temporaryBackendDBURL error:NULL];
}

// - schedules a simple request
// - on finish, instructs the pipeline to reschedule the request
// - on second finish, instructs the pipeline to deliver the response
// - verifies the two responses differ by checking the "Set-Cookie" header field of both
// - verifies the response handler was only invoked with the second response
- (void)testRescheduleInstruction
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed started"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed started"];
	XCTestExpectation *requestCompletedExpectation = [self expectationWithDescription:@"request completed started"];

	XCTestExpectation *firstInstructionExpectation = [self expectationWithDescription:@"first finishedRequest instruction requested"];
	XCTestExpectation *secondInstructionExpectation = [self expectationWithDescription:@"second finishedRequest instruction requested"];

	__block BOOL firstInstructionForStatus=YES;
	__block BOOL secondInstructionForStatus=NO;

	__block NSString *firstSetCookieString=nil, *secondSetCookieString=nil;

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	partitionHandler.instructionForFinishedTask = ^OCHTTPRequestInstruction(OCHTTPPipeline *pipeline, OCHTTPPipelineTask *task, NSError *error) {
		if (firstInstructionForStatus)
		{
			firstInstructionForStatus = NO;

			[firstInstructionExpectation fulfill];

			firstSetCookieString = task.response.headerFields[@"Set-Cookie"];

			return (OCHTTPRequestInstructionReschedule);
		}

		[secondInstructionExpectation fulfill];
		secondInstructionForStatus = YES;

		secondSetCookieString = task.response.headerFields[@"Set-Cookie"];

		return (OCHTTPRequestInstructionDeliver);
	};

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		OCHTTPRequest *request;

		if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
		{
			request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

				XCTAssert(!firstInstructionForStatus);
				XCTAssert(secondInstructionForStatus);

				XCTAssert(firstSetCookieString!=nil);
				XCTAssert(secondSetCookieString!=nil);
				XCTAssert(![firstSetCookieString isEqual:secondSetCookieString]);

				XCTAssert([response.headerFields[@"Set-Cookie"] isEqual:secondSetCookieString]);

				[requestCompletedExpectation fulfill];

				[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
					[detachCompletedExpectation fulfill];

					[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
						[pipelineStoppedExpectation fulfill];
					} graceful:YES];
				}];
			};

			[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
				[attachCompletedExpectation fulfill];
			}];

			[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID];
		}
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testRescheduleInstructionWithDownloadRequests
{
	_forceDownloads = YES;
	[self testRescheduleInstruction];
	_forceDownloads = NO;
}


// - schedules a simple request
// - on finish, instructs the pipeline to deliver the request
// - verifies no more than one instruction is requested per actual request/response pair
// - verifies the delivered response is the one that the instruction was requested for
- (void)testDeliverInstruction
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed started"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed started"];
	XCTestExpectation *requestCompletedExpectation = [self expectationWithDescription:@"request completed started"];

	XCTestExpectation *firstInstructionExpectation = [self expectationWithDescription:@"first finishedRequest instruction requested"];

	__block NSString *firstSetCookieString=nil;

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	partitionHandler.instructionForFinishedTask = ^OCHTTPRequestInstruction(OCHTTPPipeline *pipeline, OCHTTPPipelineTask *task, NSError *error) {
		[firstInstructionExpectation fulfill];

		firstSetCookieString = task.response.headerFields[@"Set-Cookie"];

		return (OCHTTPRequestInstructionDeliver);
	};

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		OCHTTPRequest *request;

		if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
		{
			request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

				XCTAssert(firstSetCookieString!=nil);
				XCTAssert([response.headerFields[@"Set-Cookie"] isEqual:firstSetCookieString]);

				[requestCompletedExpectation fulfill];

				[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
					[detachCompletedExpectation fulfill];

					[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
						[pipelineStoppedExpectation fulfill];
					} graceful:YES];
				}];
			};

			[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
				[attachCompletedExpectation fulfill];
			}];

			[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID];
		}
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testDeliverInstructionWithDownloadRequests
{
	_forceDownloads = YES;
	[self testDeliverInstruction];
	_forceDownloads = NO;
}

// - asks the pipeline to download a file
// - checks the URL to be temporary
// - checks the URL to contain pipelineID, partitionID and requestID
// - checks the file exists on delivery
// - checks the file has vanished shortly after
- (void)testTemporaryDownloads
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed started"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed started"];
	XCTestExpectation *requestCompletedExpectation = [self expectationWithDescription:@"request completed started"];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		OCHTTPRequest *request;

		if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
		{
			request.downloadRequest = YES;

			request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

				[requestCompletedExpectation fulfill];

				XCTAssert(response.bodyURL != nil);
				XCTAssert(response.bodyURLIsTemporary);

				XCTAssert([response.bodyURL.absoluteString containsString:partitionHandler.partitionID]);
				XCTAssert([response.bodyURL.absoluteString containsString:pipeline.identifier]);
				XCTAssert([response.bodyURL.absoluteString containsString:request.identifier]);

				XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:response.bodyURL.path]);

				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					XCTAssert(![[NSFileManager defaultManager] fileExistsAtPath:response.bodyURL.path]);

					[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
						[detachCompletedExpectation fulfill];

						[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
							[pipelineStoppedExpectation fulfill];
						} graceful:YES];
					}];
				});
			};

			[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
				[attachCompletedExpectation fulfill];
			}];

			[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID];
		}
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

// - asks the pipeline to download a file
// - checks the URL to be temporary
// - checks the URL to match that in the request
// - checks the file exists on delivery
// - checks the file has vanished shortly after
- (void)testTemporaryDownloadsWithDestination
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed started"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed started"];
	XCTestExpectation *requestCompletedExpectation = [self expectationWithDescription:@"request completed started"];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		OCHTTPRequest *request;

		if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
		{
			request.downloadRequest = YES;
			request.downloadedFileURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:@"temporaryDownload"];
			request.downloadedFileIsTemporary = YES;

			[[NSFileManager defaultManager] removeItemAtURL:request.downloadedFileURL error:NULL];

			request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

				[requestCompletedExpectation fulfill];

				XCTAssert(response.bodyURL != nil);
				XCTAssert(response.bodyURLIsTemporary);

				XCTAssert([response.bodyURL isEqual:request.downloadedFileURL]);

				XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:response.bodyURL.path]);

				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					XCTAssert(![[NSFileManager defaultManager] fileExistsAtPath:request.downloadedFileURL.path]);
					XCTAssert(response.bodyURL==nil);

					[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
						[detachCompletedExpectation fulfill];

						[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
							[pipelineStoppedExpectation fulfill];
						} graceful:YES];
					}];
				});
			};

			[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
				[attachCompletedExpectation fulfill];
			}];

			[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID];
		}
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

// - asks the pipeline to download a file
// - checks the URL to not be temporary
// - checks the URL to match that in the request
// - checks the file exists on delivery
// - checks the file exists shortly after
- (void)testPermanentDownloads
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed started"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed started"];
	XCTestExpectation *requestCompletedExpectation = [self expectationWithDescription:@"request completed started"];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		OCHTTPRequest *request;

		if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
		{
			request.downloadRequest = YES;
			request.downloadedFileURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:@"permanentDownload"];

			[[NSFileManager defaultManager] removeItemAtURL:request.downloadedFileURL error:NULL];

			request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

				[requestCompletedExpectation fulfill];

				XCTAssert(response.bodyURL != nil);
				XCTAssert(!response.bodyURLIsTemporary);

				XCTAssert([response.bodyURL isEqual:request.downloadedFileURL]);

				XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:response.bodyURL.path]);

				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:response.bodyURL.path]);

					[[NSFileManager defaultManager] removeItemAtURL:request.downloadedFileURL error:NULL];

					[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
						[detachCompletedExpectation fulfill];

						[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
							[pipelineStoppedExpectation fulfill];
						} graceful:YES];
					}];
				});
			};

			[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
				[attachCompletedExpectation fulfill];
			}];

			[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID];
		}
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

// - schedules a request while not attached
// - after 3 seconds, inspects the database for pending deliveries
// - then destroys the partition
// - checks that nothing is pending delivery anymore
- (void)testPartitionDestructionWithPendingDelivery
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-e";

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		OCHTTPRequest *request;

		if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
		{
			request.downloadRequest = YES;
			request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				XCTFail(@"Should never be called");
			};

			XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==0);

			[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID isFinal:YES];

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==1);
				XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:[[pipeline.backend.temporaryFilesRoot URLByAppendingPathComponent:pipeline.identifier] path]]);
				XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:[[[pipeline.backend.temporaryFilesRoot URLByAppendingPathComponent:pipeline.identifier] URLByAppendingPathComponent:partitionHandler.partitionID] path]]);
				XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:[[[[pipeline.backend.temporaryFilesRoot URLByAppendingPathComponent:pipeline.identifier] URLByAppendingPathComponent:partitionHandler.partitionID] URLByAppendingPathComponent:request.identifier] path]]);

				[pipeline destroyPartition:partitionHandler.partitionID completionHandler:^(id sender, NSError *error) {
					XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==0);

					XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:[[pipeline.backend.temporaryFilesRoot URLByAppendingPathComponent:pipeline.identifier] path]]);
					XCTAssert(![[NSFileManager defaultManager] fileExistsAtPath:[[[pipeline.backend.temporaryFilesRoot URLByAppendingPathComponent:pipeline.identifier] URLByAppendingPathComponent:partitionHandler.partitionID] path]]);
					XCTAssert(![[NSFileManager defaultManager] fileExistsAtPath:[[[[pipeline.backend.temporaryFilesRoot URLByAppendingPathComponent:pipeline.identifier] URLByAppendingPathComponent:partitionHandler.partitionID] URLByAppendingPathComponent:request.identifier] path]]);

					[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
						[pipelineStoppedExpectation fulfill];
					} graceful:YES];
				}];
			});
		}
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

// - Attach partition and schedule 100 requests
// - After 0.5 seconds, tell pipeline to destroy the partition
// - Check all requests returned a result and that at least some of them were cancelled
// - Assert if result is delivered after -destroyPartition:completionHandler: called the completionHandler
// - Verify temporary directories for the partition have also been removed
- (void)testPartitionDestructionInFullAction
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;
	pipeline.maximumConcurrentRequests = 5;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-d";

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==0);

		__block NSInteger requests = 200, outstandingRequests, cancelledRequests = 0;
		__block BOOL deliveryAllowed = YES;

		outstandingRequests = requests;

		[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
			for (NSUInteger i=0; i<requests; i++)
			{
				OCHTTPRequest *request;

				if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
				{
					request.downloadRequest = YES;
					request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
						if ([error isOCErrorWithCode:OCErrorRequestCancelled])
						{
							cancelledRequests++;
						}

						outstandingRequests--;

						XCTAssert(deliveryAllowed);
					};
				}

				[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID isFinal:NO];
			}

			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:[[pipeline.backend.temporaryFilesRoot URLByAppendingPathComponent:pipeline.identifier] path]]);
				XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:[[[pipeline.backend.temporaryFilesRoot URLByAppendingPathComponent:pipeline.identifier] URLByAppendingPathComponent:partitionHandler.partitionID] path]]);

				[pipeline destroyPartition:partitionHandler.partitionID completionHandler:^(id sender, NSError *error) {
					OCLog(@"outstandingRequests: %ld, cancelledRequests: %ld", outstandingRequests, cancelledRequests);

					XCTAssert(outstandingRequests==0);
					XCTAssert(cancelledRequests>0);

					deliveryAllowed = NO;

					XCTAssert([pipeline tasksPendingDeliveryForPartitionID:partitionHandler.partitionID]==0);

					XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:[[pipeline.backend.temporaryFilesRoot URLByAppendingPathComponent:pipeline.identifier] path]]);
					XCTAssert(![[NSFileManager defaultManager] fileExistsAtPath:[[[pipeline.backend.temporaryFilesRoot URLByAppendingPathComponent:pipeline.identifier] URLByAppendingPathComponent:partitionHandler.partitionID] path]]);

					[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
						[pipelineStoppedExpectation fulfill];
					} graceful:YES];
				}];
			});
		}];
	}];

	[self waitForExpectationsWithTimeout:240 handler:nil];
}

// - creates a fake task in the backend with status "running" (=> when actually it has never been scheduled and the NSURLSession can't know about it)
// - verify that the pipeline detects that the underlying NSURLSession has no corresponding task and finishes the task with the correct error
- (void)testSessionDroppedRequests
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed started"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed started"];
	XCTestExpectation *requestCompletedExpectation = [self expectationWithDescription:@"request completed started"];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-r";

	OCHTTPRequest *fakeRequest;

	if ((fakeRequest = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
	{
		fakeRequest.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
			OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
			OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

			XCTAssert(error!=nil);
			XCTAssert([error isOCErrorWithCode:OCErrorRequestDroppedByURLSession]);

			[requestCompletedExpectation fulfill];

			[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
				[detachCompletedExpectation fulfill];

				[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
					[pipelineStoppedExpectation fulfill];
				} graceful:YES];
			}];
		};

		[pipeline.backend openWithCompletionHandler:^(id sender, NSError *error) {
			OCHTTPPipelineTask *task;

			task = [[OCHTTPPipelineTask alloc] initWithRequest:fakeRequest pipeline:pipeline partition:partitionHandler.partitionID];
			task.state = OCHTTPPipelineTaskStateRunning;
			[pipeline.backend addPipelineTask:task];

			[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
				XCTAssert(error==nil);
				XCTAssert(sender==pipeline);

				[pipelineStartedExpectation fulfill];

				[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
					[attachCompletedExpectation fulfill];
				}];
			}];

			[pipeline.backend closeWithCompletionHandler:^(id sender, NSError *error) {}];
		}];
	}

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

// - enqueues two requests
// - host simulator lets one pass through, lets one fail with an error
// - assert checks for expected results
- (void)testHostSimulationSupport
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed started"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed started"];
	XCTestExpectation *requestCompletedExpectation = [self expectationWithDescription:@"request completed started"];

	requestCompletedExpectation.expectedFulfillmentCount = 2;

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";
	partitionHandler.simulateRequestHandling = ^BOOL(OCHTTPPipeline *pipeline, OCHTTPPipelinePartitionID partitionID, OCHTTPRequest *request, void (^completionHandler)(OCHTTPResponse *response)) {
		if ([request.url.absoluteString hasSuffix:@"?"])
		{
			completionHandler([OCHTTPResponse responseWithRequest:request HTTPError:OCError(OCErrorResponseUnknownFormat)]);
			return (NO);
		}

		return (YES);
	};

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		OCHTTPRequest *requestPassthrough;
		OCHTTPRequest *requestSimulated;

		if ((requestSimulated = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php?"]]) != nil)
		{
			requestSimulated.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

				XCTAssert([error isOCErrorWithCode:OCErrorResponseUnknownFormat]);

				[requestCompletedExpectation fulfill];
			};
		}

		if ((requestPassthrough = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://demo.owncloud.org/status.php"]]) != nil)
		{
			requestPassthrough.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
				OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
				OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

				XCTAssert(error==nil);

				[requestCompletedExpectation fulfill];

				[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
					[detachCompletedExpectation fulfill];

					[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
						[pipelineStoppedExpectation fulfill];
					} graceful:YES];
				}];
			};
		}

		[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
			[pipeline enqueueRequest:requestSimulated forPartitionID:partitionHandler.partitionID];
			[pipeline enqueueRequest:requestPassthrough forPartitionID:partitionHandler.partitionID];

			[attachCompletedExpectation fulfill];
		}];
	}];

	[self waitForExpectationsWithTimeout:120 handler:nil];
}

- (void)testProgress
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed started"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed started"];
	XCTestExpectation *requestCompletedExpectation = [self expectationWithDescription:@"request completed started"];

	__block XCTestExpectation *progressQuarterCompletedExpectation = [self expectationWithDescription:@"progress quarter completed"];
	__block XCTestExpectation *progressHalfCompletedExpectation = [self expectationWithDescription:@"progress half completed"];
	__block XCTestExpectation *progressFullyCompletedExpectation = [self expectationWithDescription:@"progress full completed"];

	OCHTTPPipeline *pipeline = [[OCHTTPPipeline alloc] initWithIdentifier:@"testPipeline" backend:nil configuration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"bgQueue"]];
	pipeline.alwaysUseDownloadTasks = _forceDownloads;

	PartitionSimulator *partitionHandler = [PartitionSimulator new];
	partitionHandler.partitionID = @"partition-1";

	__block ProgressObserver *progressObserver = nil;

	[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
		XCTAssert(error==nil);
		XCTAssert(sender==pipeline);

		[pipelineStartedExpectation fulfill];

		[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
			OCHTTPRequest *request;

			[attachCompletedExpectation fulfill];

			if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://download.owncloud.org/community/owncloud-10.1.0.tar.bz2"]]) != nil)
			{
				NSProgress *progress = nil;

				request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
					OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
					OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

					[requestCompletedExpectation fulfill];

					[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
						[detachCompletedExpectation fulfill];

						[pipeline stopWithCompletionHandler:^(id sender, NSError *error) {
							[pipelineStoppedExpectation fulfill];
						} graceful:YES];
					}];
				};

				XCTAssert(request.progress!=nil);

				progress = [request.progress resolveWith:nil];

				progressObserver = [[ProgressObserver alloc] initFor:progress changeHandler:^(NSString *keyPath, NSProgress *progress) {
					if (progress.fractionCompleted > 0.25)
					{
						[progressQuarterCompletedExpectation fulfill];
						progressQuarterCompletedExpectation = nil;
					}

					if (progress.fractionCompleted > 0.5)
					{
						[progressHalfCompletedExpectation fulfill];
						progressHalfCompletedExpectation = nil;
					}

					if (progress.fractionCompleted == 1.0)
					{
						[progressFullyCompletedExpectation fulfill];
						progressFullyCompletedExpectation = nil;
					}

					OCLogDebug(@"progress.fractionCompleted=%f", progress.fractionCompleted);
				}];

				[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID];
			}
		}];
	}];

	[self waitForExpectationsWithTimeout:480 handler:nil];

	progressObserver = nil;
}

- (void)testProgressRecoveryAndCancellation
{
	XCTestExpectation *pipelineStartedExpectation = [self expectationWithDescription:@"pipeline started"];
	XCTestExpectation *pipelineStoppedExpectation = [self expectationWithDescription:@"pipeline stopped"];
	XCTestExpectation *attachCompletedExpectation = [self expectationWithDescription:@"attach completed started"];
	XCTestExpectation *detachCompletedExpectation = [self expectationWithDescription:@"detach completed started"];
	XCTestExpectation *requestCompletedExpectation = [self expectationWithDescription:@"request completed started"];

	__block XCTestExpectation *progressCancellationLimitReachedExpectation = [self expectationWithDescription:@"progress quarter completed"];

	__block ProgressObserver *progressObserver = nil;

	[OCHTTPPipelineManager.sharedPipelineManager requestPipelineWithIdentifier:OCHTTPPipelineIDEphermal completionHandler:^(OCHTTPPipeline * _Nullable pipeline, NSError * _Nullable error) {
		PartitionSimulator *partitionHandler = [PartitionSimulator new];
		partitionHandler.partitionID = @"partition-1";

		[pipeline startWithCompletionHandler:^(id sender, NSError *error) {
			XCTAssert(error==nil);
			XCTAssert(sender==pipeline);

			[pipelineStartedExpectation fulfill];

			[pipeline attachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
				OCHTTPRequest *request;

				[attachCompletedExpectation fulfill];

				if ((request = [OCHTTPRequest requestWithURL:[NSURL URLWithString:@"https://download.owncloud.org/community/owncloud-10.1.0.tar.bz2"]]) != nil)
				{
					NSProgress *progress = nil;

					request.ephermalResultHandler = ^(OCHTTPRequest *request, OCHTTPResponse *response, NSError *error) {
						OCLogDebug(@"request=%@, response=%@, error=%@", request, response, error);
						OCLogDebug(@"%@", [response responseDescriptionPrefixed:NO]);

						XCTAssert([error isOCErrorWithCode:OCErrorRequestCancelled]);

						[requestCompletedExpectation fulfill];

						[pipeline detachPartitionHandler:partitionHandler completionHandler:^(id sender, NSError *error) {
							[detachCompletedExpectation fulfill];

							[OCHTTPPipelineManager.sharedPipelineManager returnPipelineWithIdentifier:pipeline.identifier completionHandler:^{
								[pipelineStoppedExpectation fulfill];
							}];
						}];
					};

					XCTAssert(request.progress!=nil);

					OCProgress *recoverFromProgress = [[OCProgress alloc] initWithPath:request.progress.path progress:nil];

					XCTAssert([recoverFromProgress resolveWith:nil] == nil);

					progress = [request.progress resolveWith:nil];

					progressObserver = [[ProgressObserver alloc] initFor:progress changeHandler:^(NSString *keyPath, NSProgress *progress) {
						if (progress.fractionCompleted > 0.10)
						{
							if (progressCancellationLimitReachedExpectation != nil)
							{
								[progressCancellationLimitReachedExpectation fulfill];
								progressCancellationLimitReachedExpectation = nil;

								[[recoverFromProgress resolveWith:nil] cancel];
							}
						}

						OCLogDebug(@"progress.fractionCompleted=%f", progress.fractionCompleted);
					}];

					[pipeline enqueueRequest:request forPartitionID:partitionHandler.partitionID];

					XCTAssert([recoverFromProgress resolveWith:nil] == progress);
				}
			}];
		}];
	}];

	[self waitForExpectationsWithTimeout:480 handler:nil];

	progressObserver = nil;
}

/*
	Test scenarios currently not covered:
	- test certificate issue handling (including a non-response to the certificate callback and restart (test for handling of app crashes/terminations))
	- test session recovery. Not sure if possible to disrupt an NSURLSession to this extent without exiting and restarting.
*/

@end
