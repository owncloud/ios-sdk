//
//  OCConnection.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCTypes.h"
#import "OCBookmark.h"
#import "OCAuthenticationMethod.h"
#import "OCEventTarget.h"
#import "OCShare.h"
#import "OCClassSettings.h"
#import "OCCertificate.h"
#import "OCConnectionIssue.h"
#import "OCChecksum.h"

@class OCBookmark;
@class OCAuthenticationMethod;
@class OCItem;
@class OCConnectionQueue;
@class OCConnectionRequest;
@class OCConnection;
@class OCCertificate;
@class OCHTTPStatus;

typedef void(^OCConnectionEphermalResultHandler)(OCConnectionRequest *request, NSError *error);
typedef void(^OCConnectionCertificateProceedHandler)(BOOL proceed, NSError *error);
typedef void(^OCConnectionEphermalRequestCertificateProceedHandler)(OCConnectionRequest *request, OCCertificate *certificate, OCCertificateValidationResult validationResult, NSError *certificateValidationError, OCConnectionCertificateProceedHandler proceedHandler);

typedef NSString* OCConnectionEndpointID NS_TYPED_ENUM;
typedef NSString* OCConnectionOptionKey NS_TYPED_ENUM;
typedef NSDictionary<OCItemPropertyName,OCHTTPStatus*>* OCConnectionPropertyUpdateResult;

typedef NS_ENUM(NSUInteger, OCConnectionState)
{
	OCConnectionStateDisconnected,
	OCConnectionStateConnecting,
	OCConnectionStateConnected
};

@protocol OCConnectionDelegate <NSObject>

@optional
- (void)connection:(OCConnection *)connection handleError:(NSError *)error;

- (void)connection:(OCConnection *)connection request:(OCConnectionRequest *)request certificate:(OCCertificate *)certificate validationResult:(OCCertificateValidationResult)validationResult validationError:(NSError *)validationError defaultProceedValue:(BOOL)defaultProceedValue proceedHandler:(OCConnectionCertificateProceedHandler)proceedHandler;

@end

@protocol OCConnectionHostSimulator <NSObject>

- (BOOL)connection:(OCConnection *)connection queue:(OCConnectionQueue *)queue handleRequest:(OCConnectionRequest *)request completionHandler:(void(^)(NSError *error))completionHandler;

@end

@interface OCConnection : NSObject <OCClassSettingsSupport>
{
	OCBookmark *_bookmark;
	OCAuthenticationMethod *_authenticationMethod;

	OCChecksumAlgorithmIdentifier _preferredChecksumAlgorithm;

	OCUser *_loggedInUser;

	NSURL *_persistentStoreBaseURL;

	OCConnectionQueue *_commandQueue;

	OCConnectionQueue *_uploadQueue;
	OCConnectionQueue *_downloadQueue;

	NSMutableDictionary <NSString *, OCConnectionQueue *> *_attachedExtensionQueuesBySessionIdentifier;
	
	OCConnectionState _state;

	__weak id <OCConnectionDelegate> _delegate;

	__weak id <OCConnectionHostSimulator> _hostSimulator;

	NSDictionary<NSString *, id> *_serverStatus;

	NSMutableArray <OCConnectionAuthenticationAvailabilityHandler> *_pendingAuthenticationAvailabilityHandlers;
}

@property(class,readonly,nonatomic) BOOL backgroundURLSessionsAllowed; //!< Indicates whether background URL sessions should be used.

@property(strong) OCBookmark *bookmark;
@property(strong,nonatomic) OCAuthenticationMethod *authenticationMethod;

@property(strong) OCChecksumAlgorithmIdentifier preferredChecksumAlgorithm;

@property(strong) OCUser *loggedInUser;

@property(strong) OCConnectionQueue *commandQueue; //!< Queue for requests that carry metadata commands (move, delete, retrieve list, ..)

@property(strong) OCConnectionQueue *uploadQueue; //!< Queue for requests that upload files / changes
@property(strong) OCConnectionQueue *downloadQueue; //!< Queue for requests that download files / changes

@property(assign,nonatomic) OCConnectionState state;

@property(weak) id <OCConnectionDelegate> delegate;

@property(weak) id <OCConnectionHostSimulator> hostSimulator;

#pragma mark - Init
- (instancetype)init NS_UNAVAILABLE; //!< Always returns nil. Please use the designated initializer instead.
- (instancetype)initWithBookmark:(OCBookmark *)bookmark persistentStoreBaseURL:(NSURL *)persistentStoreBaseURL;

#pragma mark - Connect & Disconnect
- (NSProgress *)connectWithCompletionHandler:(void(^)(NSError *error, OCConnectionIssue *issue))completionHandler;
- (void)disconnectWithCompletionHandler:(dispatch_block_t)completionHandler;
- (void)disconnectWithCompletionHandler:(dispatch_block_t)completionHandler invalidate:(BOOL)invalidateConnection;

#pragma mark - Metadata actions
- (NSProgress *)retrieveItemListAtPath:(OCPath)path depth:(NSUInteger)depth completionHandler:(void(^)(NSError *error, NSArray <OCItem *> *items))completionHandler; //!< Retrieves the items at the specified path

- (NSProgress *)retrieveItemListAtPath:(OCPath)path depth:(NSUInteger)depth notBefore:(NSDate *)notBeforeDate options:(NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget; //!< Retrieves the items at the specified path, with options to schedule on the background queue and with a "not before" date.

#pragma mark - Actions
- (NSProgress *)createFolder:(NSString *)folderName inside:(OCItem *)parentItem options:(NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget;

- (NSProgress *)moveItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)newName options:(NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget;
- (NSProgress *)copyItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)newName options:(NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget;

- (NSProgress *)deleteItem:(OCItem *)item requireMatch:(BOOL)requireMatch resultTarget:(OCEventTarget *)eventTarget;

- (NSProgress *)uploadFileFromURL:(NSURL *)sourceURL withName:(NSString *)fileName to:(OCItem *)newParentDirectory replacingItem:(OCItem *)replacedItem options:(NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget;
- (NSProgress *)downloadItem:(OCItem *)item to:(NSURL *)targetURL options:(NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget;

- (NSProgress *)updateItem:(OCItem *)item properties:(NSArray <OCItemPropertyName> *)properties options:(NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget;

- (NSProgress *)retrieveThumbnailFor:(OCItem *)item to:(NSURL *)localThumbnailURL maximumSize:(CGSize)size resultTarget:(OCEventTarget *)eventTarget;

- (NSProgress *)shareItem:(OCItem *)item options:(OCShareOptions)options resultTarget:(OCEventTarget *)eventTarget;

- (NSProgress *)sendRequest:(OCConnectionRequest *)request toQueue:(OCConnectionQueue *)queue ephermalCompletionHandler:(OCConnectionEphermalResultHandler)ephermalResultHandler;

#pragma mark - Sending requests synchronously
- (NSError *)sendSynchronousRequest:(OCConnectionRequest *)request toQueue:(OCConnectionQueue *)queue;

#pragma mark - Resume background sessions
- (void)resumeBackgroundSessions;
- (void)finishedQueueForResumedBackgroundSessionWithIdentifier:(NSString *)backgroundSessionIdentifier;

@end

#pragma mark - SETUP
@interface OCConnection (Setup)

#pragma mark - Prepare for setup
- (void)prepareForSetupWithOptions:(NSDictionary<NSString *, id> *)options completionHandler:(void(^)(OCConnectionIssue *issue, NSURL *suggestedURL, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods, NSArray <OCAuthenticationMethodIdentifier> *preferredAuthenticationMethods))completionHandler; //!< Helps in creation of a valid bookmark during setup. Provides found issues as OCConnectionIssue (type: group) that can be accepted or rejected. Individual issues can be used as source for line items.

@end

#pragma mark - AUTHENTICATION
@interface OCConnection (Authentication)

#pragma mark - Authentication
- (void)requestSupportedAuthenticationMethodsWithOptions:(OCAuthenticationMethodDetectionOptions)options completionHandler:(void(^)(NSError *error, NSArray <OCAuthenticationMethodIdentifier> *supportedMethods))completionHandler; //!< Requests a list of supported authentication methods and returns the result

- (void)generateAuthenticationDataWithMethod:(OCAuthenticationMethodIdentifier)methodIdentifier options:(OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError *error, OCAuthenticationMethodIdentifier authenticationMethodIdentifier, NSData *authenticationData))completionHandler; //!< Uses the OCAuthenticationMethod to generate the authenticationData for storing in the bookmark. It is not directly stored in the bookmark so that an app can decide on its own when to overwrite existing data - or save the result.

- (BOOL)canSendAuthenticatedRequestsForQueue:(OCConnectionQueue *)queue availabilityHandler:(OCConnectionAuthenticationAvailabilityHandler)availabilityHandler; //!< This method is called by the OCConnectionQueue to determine if authenticated requests can be sent right now. If the method returns YES, the queue will proceed to schedule requests immediately and the availabilityHandler must not be called. If the method returns NO, only requests whose skipAuthorization property is set to YES will be scheduled, while all other requests remain queued. The queue will resume normal operation once the availabilityHandler was called with error==nil and authenticationIsAvailable==YES. If authenticationIsAvailable==NO, the queue will cancel all queued requests with the provided error.

+ (NSArray <OCAuthenticationMethodIdentifier> *)filteredAndSortedMethodIdentifiers:(NSArray <OCAuthenticationMethodIdentifier> *)methodIdentifiers allowedMethodIdentifiers:(NSArray <OCAuthenticationMethodIdentifier> *)allowedMethodIdentifiers preferredMethodIdentifiers:(NSArray <OCAuthenticationMethodIdentifier> *)preferredMethodIdentifiers; //!< Returns allowed entries from methodIdentifiers in order of preferrence

- (NSArray <OCAuthenticationMethodIdentifier> *)filteredAndSortedMethodIdentifiers:(NSArray <OCAuthenticationMethodIdentifier> *)methodIdentifiers; //!< Returns allowed entries from methodIdentifiers in order of preferrence

@end

#pragma mark - USERS
@interface OCConnection (Users)

#pragma mark - User info
- (NSProgress *)retrieveLoggedInUserWithCompletionHandler:(void(^)(NSError *error, OCUser *loggedInUser))completionHandler; //!< Retrieves information on the currently logged in user and returns it via the completion handler

@end

#pragma mark - TOOLS
@interface OCConnection (Tools)

#pragma mark - Endpoints
- (NSString *)pathForEndpoint:(OCConnectionEndpointID)endpoint; //!< Returns the path of an endpoint identified by its OCConnectionEndpointID
- (NSURL *)URLForEndpoint:(OCConnectionEndpointID)endpoint options:(NSDictionary <NSString *,id> *)options; //!< Returns the URL of an endpoint identified by its OCConnectionEndpointID, allowing additional options (reserved for future use)
- (NSURL *)URLForEndpointPath:(OCPath)endpointPath; //!< Returns the URL of the endpoint at the supplied endpointPath

#pragma mark - Base URL Extract
+ (NSURL *)extractBaseURLFromRedirectionTargetURL:(NSURL *)inRedirectionTargetURL originalURL:(NSURL *)inOriginalURL originalBaseURL:(NSURL *)inOriginalBaseURL;
- (NSURL *)extractBaseURLFromRedirectionTargetURL:(NSURL *)inRedirectionTargetURL originalURL:(NSURL *)inOriginalURL;

#pragma mark - Safe upgrades
+ (BOOL)isAlternativeBaseURL:(NSURL *)alternativeBaseURL safeUpgradeForPreviousBaseURL:(NSURL *)baseURL;

@end

#pragma mark - COMPATIBILITY
@interface OCConnection (Compatibility)

#pragma mark - Version
- (NSString *)serverVersion; //!< After connecting, the version of the server ("version"), f.ex. "10.0.8.5".
- (NSString *)serverVersionString; //!< After connecting, the version string of the server ("versionstring"), fe.x. "10.0.8", "10.1.0 prealpha"
- (BOOL)runsServerVersionOrHigher:(NSString *)version; //!< Returns YES if the server runs at least [version].

- (NSString *)serverProductName; //!< After connecting, the product name of the server ("productname"), f.ex. "ownCloud".
- (NSString *)serverEdition; //!< After connecting, the edition of the server ("edition"), f.ex. "Community".

- (NSString *)serverLongProductVersionString; //!< After connecting, a string summarizing the product, edition and version, f.ex. "ownCloud Community 10.0.8.5"
+ (NSString *)serverLongProductVersionStringFromServerStatus:(NSDictionary<NSString *, id> *)serverStatus;

#pragma mark - API Switches
- (BOOL)supportsPreviewAPI; //!< Returns YES if the server supports the Preview API.

#pragma mark - Checks
- (NSError *)supportsServerVersion:(NSString *)serverVersion longVersion:(NSString *)longVersion;

@end

extern OCConnectionEndpointID OCConnectionEndpointIDCapabilities;
extern OCConnectionEndpointID OCConnectionEndpointIDUser;
extern OCConnectionEndpointID OCConnectionEndpointIDWebDAV;
extern OCConnectionEndpointID OCConnectionEndpointIDWebDAVRoot; //!< Virtual, non-configurable endpoint, builds the root URL based on OCConnectionEndpointIDWebDAV and the username found in connection.loggedInUser
extern OCConnectionEndpointID OCConnectionEndpointIDThumbnail;
extern OCConnectionEndpointID OCConnectionEndpointIDStatus;

extern OCClassSettingsKey OCConnectionInsertXRequestTracingID; //!< Controls whether a X-Request-ID should be included into the header of every request. Defaults to YES. [NSNumber]
extern OCClassSettingsKey OCConnectionPreferredAuthenticationMethodIDs; //!< Array of OCAuthenticationMethodIdentifiers of preferred authentication methods in order of preference, starting with the most preferred. Defaults to @[ OCAuthenticationMethodIdentifierOAuth2, OCAuthenticationMethodIdentifierBasicAuth ]. [NSArray <OCAuthenticationMethodIdentifier> *]
extern OCClassSettingsKey OCConnectionAllowedAuthenticationMethodIDs; //!< Array of OCAuthenticationMethodIdentifiers of allowed authentication methods. Defaults to nil for no restrictions. [NSArray <OCAuthenticationMethodIdentifier> *]
extern OCClassSettingsKey OCConnectionStrictBookmarkCertificateEnforcement; //!< Controls whether OCConnection should only allow the bookmark's certificate when connected. Defaults to YES.
extern OCClassSettingsKey OCConnectionMinimumVersionRequired; //!< Makes sure connections via -connectWithCompletionHandler:completionHandler: can only be made to servers with this version number or higher.
extern OCClassSettingsKey OCConnectionAllowBackgroundURLSessions; //!< Allows (TRUE) or disallows (FALSE) the use of background URL sessions. Defaults to TRUE.

extern OCConnectionOptionKey OCConnectionOptionRequestObserverKey;
extern OCConnectionOptionKey OCConnectionOptionChecksumKey; //!< OCChecksum instance to use for the "OC-Checksum" header in uploads
extern OCConnectionOptionKey OCConnectionOptionChecksumAlgorithmKey; //!< OCChecksumAlgorithmIdentifier identifying the checksum algorithm to use to compute checksums for the "OC-Checksum" header in uploads

#import "OCClassSettings.h"

#import "OCConnectionRequest.h"
