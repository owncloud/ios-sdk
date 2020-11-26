//
//  OCConnection+Upload.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 10.06.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCConnection.h"
#import "NSError+OCError.h"
#import "OCLogger.h"
#import "OCMacros.h"
#import "NSProgress+OCEvent.h"
#import "OCTUSJob.h"
#import "OCHTTPPipelineManager.h"
#import "OCHTTPPipelineTask.h"
#import "OCHTTPResponse+DAVError.h"

typedef NSString* OCUploadInfoKey;
typedef NSString* OCUploadInfoTask;

static OCUploadInfoKey OCUploadInfoKeyTask = @"task";
static OCUploadInfoKey OCUploadInfoKeyJob = @"job";
static OCUploadInfoKey OCUploadInfoKeySegmentSize = @"segmentSize";

static OCUploadInfoTask OCUploadInfoTaskCreate = @"create";
static OCUploadInfoTask OCUploadInfoTaskHead = @"head";
static OCUploadInfoTask OCUploadInfoTaskUpload = @"upload";

@implementation OCConnection (Upload)

#pragma mark - File transfer: upload
- (OCProgress *)uploadFileFromURL:(NSURL *)sourceURL withName:(NSString *)fileName to:(OCItem *)newParentDirectory replacingItem:(OCItem *)replacedItem options:(NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget
{
	if ((sourceURL == nil) || (newParentDirectory == nil))
	{
		return(nil);
	}

	if (fileName == nil)
	{
		if (replacedItem != nil)
		{
			fileName = replacedItem.name;
		}
		else
		{
			fileName = sourceURL.lastPathComponent;
		}
	}

	if (![[NSFileManager defaultManager] fileExistsAtPath:sourceURL.path])
	{
		[eventTarget handleError:OCError(OCErrorFileNotFound) type:OCEventTypeUpload uuid:nil sender:self];

		return(nil);
	}

	// Determine file size
	NSNumber *fileSize = nil;
	{
		NSError *error = nil;
		if (![sourceURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:&error])
		{
			OCLogError(@"Error determining size of %@: %@", sourceURL, error);
		}
	}

	// Determine modification date
	NSDate *modDate = nil;
	if ((modDate = options[OCConnectionOptionLastModificationDateKey]) == nil)
	{
		NSError *error = nil;

		if (![sourceURL getResourceValue:&modDate forKey:NSURLAttributeModificationDateKey error:NULL])
		{
			OCLogError(@"Error determining modification date of %@: %@", sourceURL, error);
			modDate = nil;
		}
	}

	// Determine sufficiency of parameters
	if ((sourceURL == nil) || (fileName == nil) || (newParentDirectory == nil) || (modDate == nil) || (fileSize == nil))
	{
		[eventTarget handleError:OCError(OCErrorInsufficientParameters) type:OCEventTypeUpload uuid:nil sender:self];
		return(nil);
	}

	// Compute checksum
	__block OCChecksum *checksum = nil;

	if ((checksum = options[OCConnectionOptionChecksumKey]) == nil)
	{
		OCChecksumAlgorithmIdentifier checksumAlgorithmIdentifier = options[OCConnectionOptionChecksumAlgorithmKey];

		if (checksumAlgorithmIdentifier==nil)
		{
			checksumAlgorithmIdentifier = _preferredChecksumAlgorithm;
		}

		OCSyncExec(checksumComputation, {
			[OCChecksum computeForFile:sourceURL checksumAlgorithm:checksumAlgorithmIdentifier completionHandler:^(NSError *error, OCChecksum *computedChecksum) {
				checksum = computedChecksum;
				OCSyncExecDone(checksumComputation);
			}];
		});
	}

	// Determine TUS info
	OCTUSHeader *parentTusHeader = nil;

	if (OCTUSIsAvailable(newParentDirectory.tusSupport))
	{
		// Instantiate from OCItem
		parentTusHeader = [[OCTUSHeader alloc] initWithTUSInfo:newParentDirectory.tusInfo];
	}

	if ((_delegate != nil) && ([_delegate respondsToSelector:@selector(connection:tusHeader:forChildrenOf:)]))
	{
		// Modify / Retrieve from delegate
		parentTusHeader = [_delegate connection:self tusHeader:parentTusHeader forChildrenOf:newParentDirectory];
	}

	// Start upload
	if ((parentTusHeader != nil) && OCTUSIsAvailable(parentTusHeader.supportFlags) && // TUS support available
	    OCTUSIsSupported(parentTusHeader.supportFlags, OCTUSSupportExtensionCreation)) // TUS creation extension available
	{
		// Use TUS
		return ([self _tusUploadFileFromURL:sourceURL withName:fileName modificationDate:modDate fileSize:fileSize checksum:checksum tusHeader:parentTusHeader to:newParentDirectory replacingItem:replacedItem options:options resultTarget:eventTarget]);
	}
	else
	{
		// Use a single "traditional" PUT for uploads
		return ([self _directUploadFileFromURL:sourceURL withName:fileName modificationDate:modDate fileSize:fileSize checksum:checksum to:newParentDirectory replacingItem:replacedItem options:options resultTarget:eventTarget]);
	}
}

#pragma mark - File transfer: resumable upload (TUS)

/*
	TUS implementation score card:
	- [x] support for creation
	- [x] support for creation-with-upload
	- [x] store availability of tus extensions + max upload size
	- [x] use creation + PATCH if creation-with-upload is not available
	- [x] support for max chunk size via capabilities
	- [ ] apply cellular option to tus upload requests
	- [ ] provide progress updates for File Provider and app
	- [ ] use If-Match / If-None-Match with uploads
	- [ ] look for and use returned OC-Fileid and OC-ETag
	- [ ] handle little gap between upload finish and response not received via checksums
*/

+ (NSUInteger)tusSmallFileThreshold
{
	// return (100000); // 100 KB
	return (NSUIntegerMax); // No small file differentiation
}

- (OCProgress *)_tusUploadFileFromURL:(NSURL *)sourceURL withName:(NSString *)fileName modificationDate:(NSDate *)modificationDate fileSize:(NSNumber *)fileSize checksum:(OCChecksum *)checksum tusHeader:(OCTUSHeader *)parentTusHeader to:(OCItem *)parentItem replacingItem:(OCItem *)replacedItem options:(NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget
{
	OCProgress *tusProgress = nil;
	NSURL *segmentFolderURL = options[OCConnectionOptionTemporarySegmentFolderURLKey];
	NSError *error = nil;

	// Determine segment folder
	if (segmentFolderURL == nil)
	{
		segmentFolderURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[NSString stringWithFormat:@"OCTUS-%@",NSUUID.UUID.UUIDString]];
	}

	if (segmentFolderURL == nil)
	{
		[eventTarget handleError:OCError(OCErrorInsufficientStorage) type:OCEventTypeUpload uuid:nil sender:self];
		return(nil);
	}
	else
	{
		if (![[NSFileManager defaultManager] createDirectoryAtURL:segmentFolderURL withIntermediateDirectories:YES attributes:@{ NSFileProtectionKey : NSFileProtectionCompleteUntilFirstUserAuthentication } error:&error])
		{
			segmentFolderURL = nil;
			OCLogError(@"Error creating TUS segment folder at %@: %@", segmentFolderURL, error);
		}
	}

	// Clone source file to segment folder
	NSURL *clonedSourceURL = [segmentFolderURL URLByAppendingPathComponent:sourceURL.lastPathComponent isDirectory:NO];

	if (![NSFileManager.defaultManager copyItemAtURL:sourceURL toURL:clonedSourceURL error:&error])
	{
		OCLogError(@"Error cloning sourceURL %@ to segment folder at %@: %@", sourceURL, segmentFolderURL, error);
		[eventTarget handleError:OCError(OCErrorInsufficientStorage) type:OCEventTypeUpload uuid:nil sender:self];
		return(nil);
	}

	// Create TUS job
	OCTUSJob *tusJob;
	NSURL *creationURL;

	if ((creationURL = [[self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil] URLByAppendingPathComponent:parentItem.path]) != nil)
	{
		if ((tusJob = [[OCTUSJob alloc] initWithHeader:parentTusHeader segmentFolderURL:segmentFolderURL fileURL:clonedSourceURL creationURL:creationURL]) != nil)
		{
			tusJob.fileName = fileName;
			tusJob.fileSize = fileSize;
			tusJob.fileModDate = modificationDate;
			tusJob.fileChecksum = checksum;

			tusJob.futureItemPath = [parentItem.path stringByAppendingPathComponent:fileName];

			tusJob.eventTarget = eventTarget;

			if (tusJob.maxSegmentSize == 0)
			{
				NSNumber *capabilitiesTusMaxChunkSize;

				if ((capabilitiesTusMaxChunkSize = self.capabilities.tusMaxChunkSize) != nil)
				{
					tusJob.maxSegmentSize = capabilitiesTusMaxChunkSize.unsignedIntegerValue;
				}
			}

			tusProgress = [self _continueTusJob:tusJob lastTask:nil];
		}
	}
	else
	{
		// WebDAV root could not be generated (likely due to lack of username)
		[eventTarget handleError:OCError(OCErrorInternal) type:OCEventTypeUpload uuid:nil sender:self];
	}

	return (tusProgress);
}

- (OCProgress *)_continueTusJob:(OCTUSJob *)tusJob lastTask:(NSString *)lastTask
{
	OCProgress *tusProgress = nil;
	BOOL useCreationWithUpload = OCTUSIsSupported(tusJob.header.supportFlags, OCTUSSupportExtensionCreationWithUpload);
	NSUInteger maxCreationWithUploadSize = NSUIntegerMax;
	OCHTTPRequest *request = nil;

	/*
		OCTUSJob handling flow:

		Q: Is there an .uploadURL?

		1) No -> upload has not yet started
			- initiate upload via create or create-with-upload
				- response provides Tus-Resumable header
					- response status indicates success and provides Location:
						- save the URL returned via the Location header as .uploadURL
						- save 0 or $numberOfBytesAlreadyUploaded for .uploadOffset
						-> _continueTusJob…

					- response indicates failure
						- partial response with Location header
							- save Location header to .uploadURL
							- set nil for .uploadOffset
							-> _continueTusJob…
						- no response / response without Location heaer
							- restart upload via create or create-with-upload if necessary / makes sense (-> _continueTusJob…)
							- stop upload with error otherwise (-> message .eventTarget)

				- response provides NO Tus-Resumable header
					-> Tus not supported, reschedule as "traditional" direct upload

		2) Yes -> continue upload
			- is .uploadOffset set?
				- no
					- send HEAD request to .uploadURL to determine current Upload-Offset. On return:
						- response contains "Upload-Offset"
							- use as value for .uploadOffset
							-> _continueTusJob…
						- response doesn't contain "Upload-Offset"
							- if status is 404 -> upload was removed
								- set .uploadURL to nil to trigger an upload restart
								-> _continueTusJob…
							- other errors
								- stop upload with error
								-> message .eventTarget

				- yes
					- POST the next segment to .uploadURL
						- on success
							- increment .uploadOffset by the size of the segment
							- are any segments left?
								- yes
									-> _continueTusJob…
								- no
									-> initiate targeted PROPFIND and message .eventTarget
						- on failure
							- set .uploadOffset to nil
							-> _continueTusJob…

	*/

	OCTUSHeader *reqTusHeader = [OCTUSHeader new];
	reqTusHeader.version = @"1.0.0";

	if (tusJob.uploadURL == nil)
	{
		// Create file for upload and determine upload URL
		request = [OCHTTPRequest requestWithURL:tusJob.creationURL];
		request.method = OCHTTPMethodPOST;

		// Compose header and body
		reqTusHeader.uploadLength = tusJob.fileSize;
		reqTusHeader.uploadMetadata = @{
			OCTUSMetadataKeyFileName : tusJob.fileName,
			OCTUSMetadataKeyChecksum : [NSString stringWithFormat:@"%@ %@", tusJob.fileChecksum.algorithmIdentifier, tusJob.fileChecksum.checksum]
		};

		if (useCreationWithUpload && // server supports creation-with-upload
		    (tusJob.fileSize != nil) && // file size is known
		    (tusJob.fileSize.unsignedIntegerValue < OCConnection.tusSmallFileThreshold) // file size is below threshold for "small files"
		   )
		{
			// Compute initial chunk size
			NSUInteger initialChunkSize = tusJob.fileSize.unsignedIntegerValue;

			if (initialChunkSize > maxCreationWithUploadSize)
			{
				initialChunkSize = maxCreationWithUploadSize;
			}

			if ((initialChunkSize > tusJob.maxSegmentSize) && (tusJob.maxSegmentSize > 0))
			{
				initialChunkSize = tusJob.maxSegmentSize;
			}

			if (initialChunkSize > 0)
			{
				NSError *error = nil;

				// Create and send segment
				OCTUSJobSegment *segment;

				if ((segment = [tusJob requestSegmentFromOffset:0 withSize:initialChunkSize error:&error]) != nil)
				{
					if ((request.bodyURL = segment.url) != nil)
					{
						// Prepare header for inclusion of creation-with-upload data
						reqTusHeader.uploadOffset = @(0);

						[request setValue:@"application/offset+octet-stream" forHeaderField:@"Content-Type"];
					}
				}

				if (error != nil)
				{
					OCTLogError(@[@"TUS"], @"Request for initial chunk with size %lu failed with error: %@", initialChunkSize, error);
				}
			}
		}

		[request addHeaderFields:reqTusHeader.httpHeaderFields];

		// TODO: clarify if conditions (If-Match / If-None-Match) are still relevant/supported with ocis

		// Add userInfo
		request.userInfo = @{
			OCUploadInfoKeyTask : OCUploadInfoTaskCreate,
			OCUploadInfoKeyJob  : tusJob
		};
	}
	else
	{
		if (tusJob.uploadOffset == nil)
		{
			// Determine .uploadOffset
			request = [OCHTTPRequest requestWithURL:tusJob.uploadURL];
			request.method = OCHTTPMethodHEAD;

			// Compose header
			[request addHeaderFields:reqTusHeader.httpHeaderFields];

			// Add userInfo
			request.userInfo = @{
				OCUploadInfoKeyTask : OCUploadInfoTaskHead,
				OCUploadInfoKeyJob  : tusJob
			};
		}
		else
		{
			if (tusJob.uploadOffset.unsignedIntegerValue == tusJob.fileSize.unsignedIntegerValue)
			{
				// Upload complete

				// Destroy TusJob
				[tusJob destroy];

				// Retrieve item information
				[self retrieveItemListAtPath:tusJob.futureItemPath depth:0 options:@{
					@"alternativeEventType"  : @(OCEventTypeUpload),
				} resultTarget:tusJob.eventTarget];
			}
			else
			{
				// Continue upload from .uploadOffset
				request = [OCHTTPRequest requestWithURL:tusJob.uploadURL];
				request.method = OCHTTPMethodPATCH;

				// Compose body
				NSError *error;
				OCTUSJobSegment *segment = [tusJob requestSegmentFromOffset:tusJob.uploadOffset.unsignedIntegerValue
								   withSize:((tusJob.maxSegmentSize == 0) ?
										(tusJob.fileSize.unsignedIntegerValue - tusJob.uploadOffset.unsignedIntegerValue) :
										tusJob.maxSegmentSize
									)
								   error:&error];

				if (segment != nil)
				{
					request.bodyURL = segment.url;
				}

				// Compose header
				reqTusHeader.uploadOffset = tusJob.uploadOffset;
				// reqTusHeader.uploadLength = @(segment.size);
				[request addHeaderFields:reqTusHeader.httpHeaderFields];
				[request setValue:@"application/offset+octet-stream" forHeaderField:@"Content-Type"];

				// Add userInfo
				request.userInfo = @{
					OCUploadInfoKeyTask : OCUploadInfoTaskUpload,
					OCUploadInfoKeyJob  : tusJob,
					OCUploadInfoKeySegmentSize : @(segment.size)
				};
			}
		}
	}

	if (request != nil)
	{
		// Set meta data for handling
		request.requiredSignals = self.actionSignals;
		request.resultHandlerAction = @selector(_handleUploadTusJobResult:error:);
		request.eventTarget = tusJob.eventTarget;
		request.forceCertificateDecisionDelegation = YES;

		// Attach to pipelines
		[self attachToPipelines];

//		// TODO: Apply cellular options
//		if (options[OCConnectionOptionRequiredCellularSwitchKey] != nil)
//		{
//			request.requiredCellularSwitch = options[OCConnectionOptionRequiredCellularSwitchKey];
//		}
//
//		// Enqueue request
//		if (options[OCConnectionOptionRequestObserverKey] != nil)
//		{
//			// TODO: proper progress reporting for file provider and UI
//			request.requestObserver = options[OCConnectionOptionRequestObserverKey];
//		}

		[[self transferPipelineForRequest:request withExpectedResponseLength:1000] enqueueRequest:request forPartitionID:self.partitionID];
	}

	return (tusProgress);
}

- (void)_handleUploadTusJobResult:(OCHTTPRequest *)request error:(NSError *)error
{
	NSString *task = request.userInfo[OCUploadInfoKeyTask];
	OCTUSJob *tusJob = request.userInfo[OCUploadInfoKeyJob];
	BOOL isTusResponse = (request.httpResponse.headerFields[OCTUSHeaderNameTusResumable] != nil); // Tus-Resumable header indicates server supports TUS

	if ([task isEqual:OCUploadInfoTaskCreate])
	{
		NSString *location = request.httpResponse.headerFields[@"Location"]; // URL to continue the upload at

		// #warning remove this hack
		// location = [location stringByReplacingOccurrencesOfString:@"localhost" withString:tusJob.creationURL.host];

		if (isTusResponse && (location != nil))
		{
			if (request.httpResponse.status.isSuccess) // Expected: 201 Created
			{
				tusJob.uploadURL = [NSURL URLWithString:location]; // save Location to .uploadURL

				if (error == nil)
				{
					// Set default value (for "creation")
					tusJob.uploadOffset = @(0);

					// Use returned Upload-Offset header if available (for "creation-with-upload")
					if (request.httpResponse.headerFields != nil)
					{
						OCTUSHeader *tusHeader = [[OCTUSHeader alloc] initWithHTTPHeaderFields:request.httpResponse.headerFields];

						if (tusHeader.uploadOffset != nil)
						{
							OCTLogDebug(@[@"TUS"], @"TUS CREATE response indicates uploadOffset of %@ / %@", tusHeader.uploadOffset, tusJob.fileSize);

							tusJob.uploadOffset = tusHeader.uploadOffset;
						}
					}
				}
				else
				{
					tusJob.uploadOffset = nil; // ensure a HEAD request is sent to determine current upload status before continuing
				}

				// Continue
				[self _continueTusJob:tusJob lastTask:task];
			}
			else
			{
				// Stop upload with an error
				OCTLogError(@[@"TUS"], @"creation response doesn't indicate success");
				[self _errorEventFromRequest:request error:error send:YES];
			}
		}
		else
		{
			// Stop upload with an error
			OCTLogError(@[@"TUS"], @"creation response is not a TUS response");
			[self _errorEventFromRequest:request error:error send:YES];
		}
	}
	else if ([task isEqual:OCUploadInfoTaskHead])
	{
		if (isTusResponse &&
		    request.httpResponse.status.isSuccess && // Expected: 200 OK
		    (request.httpResponse.headerFields != nil))
		{
			OCTUSHeader *tusHeader = [[OCTUSHeader alloc] initWithHTTPHeaderFields:request.httpResponse.headerFields];

			if (tusHeader.uploadOffset != nil)
			{
				OCTLogDebug(@[@"TUS"], @"TUS HEAD response indicates uploadOffset of %@ / %@", tusHeader.uploadOffset, tusJob.fileSize);

				tusJob.uploadOffset = tusHeader.uploadOffset;
				[self _continueTusJob:tusJob lastTask:task];
			}
			else
			{
				OCTLogError(@[@"TUS"], @"TUS HEAD response lacks expected Upload-Offset");
				[request.eventTarget handleError:OCError(OCErrorResponseUnknownFormat) type:OCEventTypeUpload uuid:nil sender:self];
			}
		}
		else
		{
			// Stop upload with an error
			[self _errorEventFromRequest:request error:error send:YES];
		}
	}
	else if ([task isEqual:OCUploadInfoTaskUpload])
	{
		if (isTusResponse &&
		    request.httpResponse.status.isSuccess && // Expected: 204 No Content
		    (request.httpResponse.headerFields != nil))
		{
			OCTUSHeader *tusHeader = [[OCTUSHeader alloc] initWithHTTPHeaderFields:request.httpResponse.headerFields];

			if (tusHeader.uploadOffset != nil)
			{
				OCTLogDebug(@[@"TUS"], @"TUS upload response indicates uploadOffset of %@ / %@", tusHeader.uploadOffset, tusJob.fileSize);

				tusJob.uploadOffset = tusHeader.uploadOffset;
				[self _continueTusJob:tusJob lastTask:task];
			}
		}
	}
}

- (OCEvent *)_errorEventFromRequest:(OCHTTPRequest *)request error:(NSError *)error send:(BOOL)send
{
	OCEvent *event;

	if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeUpload uuid:request.identifier attributes:nil]) != nil)
	{
		if (error != nil)
		{
			event.error = error;
		}
		else
		{
			if (request.error != nil)
			{
				event.error = request.error;
			}
			else
			{
				event.error = request.httpResponse.status.error;
			}
		}

		// Add date to error
		if (event.error != nil)
		{
			OCErrorAddDateFromResponse(event.error, request.httpResponse);
		}

		if (send)
		{
			[request.eventTarget handleEvent:event sender:self];
		}
	}

	return (event);
}

#pragma mark - File transfer: direct upload (PUT)
- (OCProgress *)_directUploadFileFromURL:(NSURL *)sourceURL withName:(NSString *)fileName modificationDate:(NSDate *)modDate fileSize:(NSNumber *)fileSize checksum:(OCChecksum *)checksum to:(OCItem *)newParentDirectory replacingItem:(OCItem *)replacedItem options:(NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget
{
	OCProgress *requestProgress = nil;
	NSURL *uploadURL;

	if ((uploadURL = [[[self URLForEndpoint:OCConnectionEndpointIDWebDAVRoot options:nil] URLByAppendingPathComponent:newParentDirectory.path] URLByAppendingPathComponent:fileName]) != nil)
	{
		OCHTTPRequest *request = [OCHTTPRequest requestWithURL:uploadURL];

		request.method = OCHTTPMethodPUT;

		// Set Content-Type
		[request setValue:@"application/octet-stream" forHeaderField:@"Content-Type"];

		// Set conditions
		if (!((NSNumber *)options[OCConnectionOptionForceReplaceKey]).boolValue)
		{
			if (replacedItem != nil)
			{
				// Ensure the upload fails if there's a different version at the target already
				[request setValue:replacedItem.eTag forHeaderField:@"If-Match"];
			}
			else
			{
				// Ensure the upload fails if there's any file at the target already
				[request setValue:@"*" forHeaderField:@"If-None-Match"];
			}
		}

		// Set Content-Length
		OCLogDebug(@"Uploading file %@ (%@ bytes)..", OCLogPrivate(fileName), fileSize);
		[request setValue:fileSize.stringValue forHeaderField:@"Content-Length"];

		// Set modification date
		[request setValue:[@((SInt64)[modDate timeIntervalSince1970]) stringValue] forHeaderField:@"X-OC-MTime"];

		// Set checksum header
		OCChecksumHeaderString checksumHeaderValue = nil;

		if ((checksum != nil) && ((checksumHeaderValue = checksum.headerString) != nil))
		{
			[request setValue:checksumHeaderValue forHeaderField:@"OC-Checksum"];
		}

		// Set meta data for handling
		request.requiredSignals = self.actionSignals;
		request.resultHandlerAction = @selector(_handleDirectUploadFileResult:error:);
		request.userInfo = @{
			@"sourceURL" : sourceURL,
			@"fileName" : fileName,
			@"parentItem" : newParentDirectory,
			@"modDate" : modDate,
			@"fileSize" : fileSize,
			@"checksum" : (checksum!=nil) ? checksum : @""
		};
		request.eventTarget = eventTarget;
		request.bodyURL = sourceURL;
		request.forceCertificateDecisionDelegation = YES;

		if (options[OCConnectionOptionRequiredCellularSwitchKey] != nil)
		{
			request.requiredCellularSwitch = options[OCConnectionOptionRequiredCellularSwitchKey];
		}

		// Attach to pipelines
		[self attachToPipelines];

		// Enqueue request
		if (options[OCConnectionOptionRequestObserverKey] != nil)
		{
			request.requestObserver = options[OCConnectionOptionRequestObserverKey];
		}

		[[self transferPipelineForRequest:request withExpectedResponseLength:1000] enqueueRequest:request forPartitionID:self.partitionID];

		requestProgress = request.progress;
		requestProgress.progress.eventType = OCEventTypeUpload;
		requestProgress.progress.localizedDescription = [NSString stringWithFormat:OCLocalized(@"Uploading %@…"), fileName];
	}
	else
	{
		// WebDAV root could not be generated (likely due to lack of username)
		[eventTarget handleError:OCError(OCErrorInternal) type:OCEventTypeUpload uuid:nil sender:self];
	}

	return(requestProgress);
}

- (void)_handleUploadFileResult:(OCHTTPRequest *)request error:(NSError *)error
{
	// Compatibility with previous selector (from before the addition of TUS support) - some Sync Journal entries may still reference this selector
	[self _handleDirectUploadFileResult:request error:error];
}

- (void)_handleDirectUploadFileResult:(OCHTTPRequest *)request error:(NSError *)error
{
	NSString *fileName = request.userInfo[@"fileName"];
	OCItem *parentItem = request.userInfo[@"parentItem"];

	OCLogDebug(@"Handling file upload result with error=%@: %@", error, request);

	if (request.httpResponse.status.isSuccess)
	{
		/*
			Almost there! Only lacking permissions and mime type and we'd not have to do this PROPFIND 0.

			{
			    "Cache-Control" = "no-store, no-cache, must-revalidate";
			    "Content-Length" = 0;
			    "Content-Type" = "text/html; charset=UTF-8";
			    Date = "Tue, 31 Jul 2018 09:35:22 GMT";
			    Etag = "\"b4e54628946633eba3a601228e638f21\"";
			    Expires = "Thu, 19 Nov 1981 08:52:00 GMT";
			    Pragma = "no-cache";
			    Server = Apache;
			    "Strict-Transport-Security" = "max-age=15768000; preload";
			    "content-security-policy" = "default-src 'none';";
			    "oc-etag" = "\"b4e54628946633eba3a601228e638f21\"";
			    "oc-fileid" = 00000066ocxll7pjzvku;
			    "x-content-type-options" = nosniff;
			    "x-download-options" = noopen;
			    "x-frame-options" = SAMEORIGIN;
			    "x-permitted-cross-domain-policies" = none;
			    "x-robots-tag" = none;
			    "x-xss-protection" = "1; mode=block";
			}
		*/

		// Retrieve item information
		[self retrieveItemListAtPath:[parentItem.path stringByAppendingPathComponent:fileName] depth:0 options:@{
			@"alternativeEventType"  : @(OCEventTypeUpload)
		} resultTarget:request.eventTarget];
	}
	else
	{
		OCEvent *event = nil;

		if ((event = [OCEvent eventForEventTarget:request.eventTarget type:OCEventTypeUpload uuid:request.identifier attributes:nil]) != nil)
		{
			if (error != nil)
			{
				event.error = error;
			}
			else
			{
				if (request.error != nil)
				{
					event.error = request.error;
				}
				else
				{
					switch (request.httpResponse.status.code)
					{
						case OCHTTPStatusCodePRECONDITION_FAILED: {
							NSString *errorDescription = nil;
							OCChecksum *expectedChecksum = OCTypedCast(request.userInfo[@"checksum"], OCChecksum);

							errorDescription = [NSString stringWithFormat:OCLocalized(@"Another item named %@ already exists in %@."), fileName, parentItem.name];
							event.error = OCErrorWithDescription(OCErrorItemAlreadyExists, errorDescription);

							if (expectedChecksum != nil)
							{
								// Sometimes, a file uploads correctly but the connection is cut off just as the success response is transmitted back to the client,
								// whose request may then be re-scheduled at a later time and receive a "PRECONDITION FAILED" response because a file already exists
								// in this place. In order not to return an error if the file on the server equals the file to be uploaded, we first perform a PROPFIND
								// check and compare the checksums

								[self retrieveItemListAtPath:[parentItem.path stringByAppendingPathComponent:fileName] depth:0 options:@{
									@"alternativeEventType"  : @(OCEventTypeUpload),

									// Return an error if checksum of local and remote file mismatch
									@"checksumExpected" 	 : expectedChecksum,
									@"checksumMismatchError" : event.error
								} resultTarget:request.eventTarget];

								return; // Do not deliver the event error just yet
							}
						}
						break;

						case OCHTTPStatusCodeINSUFFICIENT_STORAGE: {
							NSString *errorDescription = nil;

							errorDescription = [NSString stringWithFormat:OCLocalized(@"Not enough space left on the server to upload %@."), fileName];
							event.error = OCErrorWithDescription(OCErrorInsufficientStorage, errorDescription);
						}
						break;

						case OCHTTPStatusCodeFORBIDDEN: {
							NSString *errorDescription = request.httpResponse.bodyParsedAsDAVError.davExceptionMessage;

							if (errorDescription == nil)
							{
								errorDescription = OCLocalized(@"Uploads to this folder are not allowed.");
							}

							event.error = OCErrorWithDescription(OCErrorItemOperationForbidden, errorDescription);
						}
						break;

						default: {
							NSError *davError = [request.httpResponse bodyParsedAsDAVError];
							NSString *davMessage = davError.davExceptionMessage;

							if (davMessage != nil)
							{
								event.error = [request.httpResponse.status errorWithDescription:davMessage];
							}
							else
							{
								event.error = request.httpResponse.status.error;
							}
						}
						break;
					}
				}
			}

			// Add date to error
			if (event.error != nil)
			{
				OCErrorAddDateFromResponse(event.error, request.httpResponse);
			}

			[request.eventTarget handleEvent:event sender:self];
		}
	}
}

@end
