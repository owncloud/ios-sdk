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
#import "OCClassSettingsUserPreferences.h"
#import "OCCertificate.h"
#import "OCIssue.h"
#import "OCChecksum.h"
#import "OCLogTag.h"
#import "OCIPNotificationCenter.h"
#import "OCHTTPTypes.h"
#import "OCHTTPCookieStorage.h"
#import "OCCapabilities.h"

@class OCBookmark;
@class OCAuthenticationMethod;
@class OCItem;
@class OCConnection;
@class OCXMLNode;

typedef NSString* OCConnectionEndpointID NS_TYPED_ENUM;
typedef NSString* OCConnectionOptionKey NS_TYPED_ENUM;
typedef NSString* OCConnectionEndpointURLOption NS_TYPED_ENUM;
typedef NSDictionary<OCItemPropertyName,OCHTTPStatus*>* OCConnectionPropertyUpdateResult;

typedef NS_ENUM(NSUInteger, OCConnectionState)
{
	OCConnectionStateDisconnected,
	OCConnectionStateConnecting,
	OCConnectionStateConnected
};

typedef NS_ENUM(NSUInteger, OCConnectionSetupHTTPPolicy)
{
	OCConnectionSetupHTTPPolicyAuto,		//!< Determines the HTTP policy from class settings. Defaults to Warn. Can be used to return to the settings/default-controlled value after manually overriding it, f.ex. in the context of a unit test.

	OCConnectionSetupHTTPPolicyAllow,		//!< Allow plain-text HTTP URL during setup without warning (** for unit tests only **).
	OCConnectionSetupHTTPPolicyWarn,		//!< Ask the user when trying to use a plain-text HTTP URL during setup
	OCConnectionSetupHTTPPolicyForbidden		//!< Make setup fail when the user tries to use a plain-text HTTP URL
};

NS_ASSUME_NONNULL_BEGIN

@protocol OCConnectionDelegate <NSObject>

@optional
- (void)connection:(OCConnection *)connection handleError:(NSError *)error;

- (void)connection:(OCConnection *)connection request:(OCHTTPRequest *)request certificate:(OCCertificate *)certificate validationResult:(OCCertificateValidationResult)validationResult validationError:(NSError *)validationError defaultProceedValue:(BOOL)defaultProceedValue proceedHandler:(OCConnectionCertificateProceedHandler)proceedHandler;

- (void)connectionChangedState:(OCConnection *)connection;
- (void)connectionCertificateUserApproved:(OCConnection *)connection;

- (OCHTTPRequestInstruction)connection:(OCConnection *)connection instructionForFinishedRequest:(OCHTTPRequest *)request withResponse:(OCHTTPResponse *)response error:(NSError *)error defaultsTo:(OCHTTPRequestInstruction)defaultInstruction;

- (nullable OCTUSHeader *)connection:(OCConnection *)connection tusHeader:(nullable OCTUSHeader *)tusHeader forChildrenOf:(OCItem *)parentItem;

@end

NS_ASSUME_NONNULL_END

#import "OCHTTPPipeline.h"

NS_ASSUME_NONNULL_BEGIN

@protocol OCConnectionHostSimulator <NSObject>

- (BOOL)connection:(OCConnection *)connection pipeline:(OCHTTPPipeline *)pipeline simulateRequestHandling:(OCHTTPRequest *)request completionHandler:(void (^)(OCHTTPResponse * _Nonnull))completionHandler;

@end

@interface OCConnection : NSObject <OCClassSettingsSupport, OCClassSettingsUserPreferencesSupport, OCLogTagging, OCHTTPPipelinePartitionHandler>
{
	OCBookmark *_bookmark;
	OCAuthenticationMethod *_authenticationMethod;

	OCChecksumAlgorithmIdentifier _preferredChecksumAlgorithm;

	OCHTTPPipelinePartitionID _partitionID;

	OCUser *_loggedInUser;
	OCCapabilities *_capabilities;

	OCConnectionState _state;

	__weak id <OCConnectionDelegate> _delegate;

	__weak id <OCConnectionHostSimulator> _hostSimulator;

	NSDictionary<NSString *, id> *_serverStatus;

	NSMutableDictionary<NSString *, OCUser *> *_usersByUserID;

	NSMutableSet<OCConnectionSignalID> *_signals;
	NSSet<OCConnectionSignalID> *_actionSignals;
	NSSet<OCConnectionSignalID> *_propFindSignals;
	NSSet<OCConnectionSignalID> *_authSignals;

	BOOL _authMethodUnavailable;
	BOOL _authMethodUnavailableChecked;

	BOOL _attachedToPipelines;

	NSMutableArray <OCConnectionAuthenticationAvailabilityHandler> *_pendingAuthenticationAvailabilityHandlers;
}

@property(class,readonly,nonatomic) BOOL backgroundURLSessionsAllowed; //!< Indicates whether background URL sessions should be used.
@property(class,readonly,nonatomic) BOOL allowCellular; //!< Indicates whether cellular may be used (reflecting class settings / MDM configuration)
@property(class,assign,nonatomic) OCConnectionSetupHTTPPolicy setupHTTPPolicy; //!< Policy to use for setting up with plain-text HTTP URLs.

@property(nullable,strong) OCBookmark *bookmark;
@property(nullable,strong,nonatomic) OCAuthenticationMethod *authenticationMethod;

@property(nullable,strong) NSDictionary<NSString *, NSString *> *staticHeaderFields; //!< Dictionary of header fields to add to every HTTP request

@property(nullable,strong) OCChecksumAlgorithmIdentifier preferredChecksumAlgorithm;

@property(nullable,strong) OCUser *loggedInUser;
@property(nullable,strong) OCCapabilities *capabilities;

@property(nullable,strong) OCHTTPPipeline *ephermalPipeline; //!< Pipeline for requests whose response is only interesting for the instance making them (f.ex. login, status, PROPFINDs)
@property(nullable,strong) OCHTTPPipeline *commandPipeline;  //!< Pipeline for requests whose response is important across instances (f.ex. commands like move, delete)
@property(nullable,strong) OCHTTPPipeline *longLivedPipeline; //!< Pipeline for requests whose response may take a while (like uploads, downloads) or that may not be dropped - not even temporarily.

@property(strong,nullable) OCHTTPCookieStorage *cookieStorage; //!< Cookie storage. Must be set externally if it should be used.

@property(strong,readonly,nonatomic) NSSet<OCHTTPPipeline *> *allHTTPPipelines; //!< A set of all HTTP pipelines used by the connection

@property(nullable,strong) NSSet<OCConnectionSignalID> *actionSignals; //!< The set of signals to use for the requests of all actions
@property(nullable,strong) NSSet<OCConnectionSignalID> *propFindSignals; //!< The set of signals to use for PROPFIND requests
@property(nullable,strong) NSSet<OCConnectionSignalID> *authSignals; //!< The set of signals to use for authentication requests

@property(assign,nonatomic) OCConnectionState state;
@property(assign) BOOL connectionInitializationPhaseCompleted; //!< Indiciates whether the connection initialization phase has been completed.

@property(nullable,weak) id <OCConnectionDelegate> delegate;

@property(nullable,weak) id <OCConnectionHostSimulator> hostSimulator;

#pragma mark - Init
- (instancetype)init NS_UNAVAILABLE; //!< Always returns nil. Please use the designated initializer instead.
- (instancetype)initWithBookmark:(OCBookmark *)bookmark;

#pragma mark - Connect & Disconnect
- (nullable NSProgress *)connectWithCompletionHandler:(void(^)(NSError * _Nullable error, OCIssue * _Nullable issue))completionHandler;
- (void)disconnectWithCompletionHandler:(dispatch_block_t)completionHandler;
- (void)disconnectWithCompletionHandler:(dispatch_block_t)completionHandler invalidate:(BOOL)invalidateConnection;

- (void)cancelNonCriticalRequests;

#pragma mark - Pipelines
- (void)attachToPipelines; //!< Attaches the connection to its pipelines (can be called repeatedly)

#pragma mark - Server Status
- (nullable NSProgress *)requestServerStatusWithCompletionHandler:(void(^)(NSError * _Nullable error, OCHTTPRequest * _Nullable request, NSDictionary<NSString *,id> * _Nullable statusInfo))completionHandler;

#pragma mark - Metadata actions
- (nullable NSProgress *)retrieveItemListAtPath:(OCPath)path depth:(NSUInteger)depth completionHandler:(void(^)(NSError * _Nullable error, NSArray <OCItem *> * _Nullable items))completionHandler; //!< Retrieves the items at the specified path
- (nullable NSProgress *)retrieveItemListAtPath:(OCPath)path depth:(NSUInteger)depth options:(nullable NSDictionary<OCConnectionOptionKey,id> *)options completionHandler:(void(^)(NSError * _Nullable error, NSArray <OCItem *> * _Nullable items))completionHandler; //!< Retrieves the items at the specified path with options

- (nullable NSProgress *)retrieveItemListAtPath:(OCPath)path depth:(NSUInteger)depth options:(nullable NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget; //!< Retrieves the items at the specified path, with options to schedule on the background queue and with a "not before" date.

#pragma mark - Actions
- (nullable OCProgress *)createFolder:(NSString *)folderName inside:(OCItem *)parentItem options:(nullable NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget;

- (nullable OCProgress *)moveItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)newName options:(nullable NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget;
- (nullable OCProgress *)copyItem:(OCItem *)item to:(OCItem *)parentItem withName:(NSString *)newName options:(nullable NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget;

- (nullable OCProgress *)deleteItem:(OCItem *)item requireMatch:(BOOL)requireMatch resultTarget:(OCEventTarget *)eventTarget;

- (nullable OCProgress *)downloadItem:(OCItem *)item to:(nullable NSURL *)targetURL options:(nullable NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget;

- (nullable OCProgress *)updateItem:(OCItem *)item properties:(nullable NSArray <OCItemPropertyName> *)properties options:(nullable NSDictionary *)options resultTarget:(OCEventTarget *)eventTarget;

- (nullable NSProgress *)retrieveThumbnailFor:(OCItem *)item to:(nullable NSURL *)localThumbnailURL maximumSize:(CGSize)size resultTarget:(OCEventTarget *)eventTarget;
- (nullable NSProgress *)retrieveThumbnailFor:(OCItem *)item to:(nullable NSURL *)localThumbnailURL maximumSize:(CGSize)size waitForConnectivity:(BOOL)waitForConnectivity resultTarget:(OCEventTarget *)eventTarget;

- (nullable NSProgress *)sendRequest:(OCHTTPRequest *)request ephermalCompletionHandler:(OCHTTPRequestEphermalResultHandler)ephermalResultHandler; //!< Sends a request to the ephermal pipeline and returns the result via the ephermalResultHandler.

#pragma mark - Report API
- (nullable OCProgress *)filterFilesWithRules:(nullable NSDictionary<OCItemPropertyName, id> *)filterRules properties:(nullable NSArray<OCXMLNode *> *)properties resultTarget:(OCEventTarget *)eventTarget;

#pragma mark - Transfer pipeline
- (OCHTTPPipeline *)transferPipelineForRequest:(OCHTTPRequest *)request withExpectedResponseLength:(NSUInteger)expectedResponseLength;

#pragma mark - Sending requests synchronously
- (nullable NSError *)sendSynchronousRequest:(OCHTTPRequest *)request; //!< Send a request synchronously using the ephermal pipeline and returns the error.

@end

#pragma mark - Action: Upload
@interface OCConnection (Upload)
- (nullable OCProgress *)uploadFileFromURL:(NSURL *)sourceURL withName:(nullable NSString *)fileName to:(OCItem *)newParentDirectory replacingItem:(nullable OCItem *)replacedItem options:(nullable NSDictionary<OCConnectionOptionKey,id> *)options resultTarget:(OCEventTarget *)eventTarget;
@end

#pragma mark - SIGNALS
@interface OCConnection (Signals)
- (void)setSignal:(OCConnectionSignalID)signal on:(BOOL)on;
- (void)updateSignalsWith:(NSSet <OCConnectionSignalID> *)allSignals;

- (BOOL)isSignalOn:(OCConnectionSignalID)signal;
- (BOOL)meetsSignalRequirements:(NSSet<OCConnectionSignalID> *)requiredSignals;
@end

#pragma mark - SETUP
@interface OCConnection (Setup)

#pragma mark - Prepare for setup
- (void)prepareForSetupWithOptions:(nullable NSDictionary<NSString *, id> *)options completionHandler:(void(^)(OCIssue * _Nullable issue, NSURL * _Nullable suggestedURL, NSArray <OCAuthenticationMethodIdentifier> * _Nullable supportedMethods, NSArray <OCAuthenticationMethodIdentifier> * _Nullable preferredAuthenticationMethods))completionHandler; //!< Helps in creation of a valid bookmark during setup. Provides found issues as OCIssue (type: group) that can be accepted or rejected. Individual issues can be used as source for line items.

@end

#pragma mark - AUTHENTICATION
@interface OCConnection (Authentication)

#pragma mark - Authentication
- (void)requestSupportedAuthenticationMethodsWithOptions:(nullable OCAuthenticationMethodDetectionOptions)options completionHandler:(void(^)(NSError * _Nullable error, NSArray <OCAuthenticationMethodIdentifier> * _Nullable supportedMethods))completionHandler; //!< Requests a list of supported authentication methods and returns the result

- (void)generateAuthenticationDataWithMethod:(OCAuthenticationMethodIdentifier)methodIdentifier options:(nullable OCAuthenticationMethodBookmarkAuthenticationDataGenerationOptions)options completionHandler:(void(^)(NSError * _Nullable error, OCAuthenticationMethodIdentifier _Nullable authenticationMethodIdentifier, NSData * _Nullable authenticationData))completionHandler; //!< Uses the OCAuthenticationMethod to generate the authenticationData for storing in the bookmark. It is not directly stored in the bookmark so that an app can decide on its own when to overwrite existing data - or save the result.

- (BOOL)canSendAuthenticatedRequestsWithAvailabilityHandler:(OCConnectionAuthenticationAvailabilityHandler)availabilityHandler; //!< This method is called to determine if authenticated requests can be sent right now. If the method returns YES, the queue will proceed to schedule requests immediately and the availabilityHandler must not be called. If the method returns NO, only requests whose signals property doesn't include OCConnectionSignalIDAuthenticationAvailable will be scheduled, while all other requests remain queued. The queue will resume normal operation once the availabilityHandler was called with error==nil and authenticationIsAvailable==YES. If authenticationIsAvailable==NO, the queue will cancel all queued requests with the provided error.

+ (NSArray <OCAuthenticationMethodIdentifier> *)filteredAndSortedMethodIdentifiers:(NSArray <OCAuthenticationMethodIdentifier> *)methodIdentifiers allowedMethodIdentifiers:(nullable NSArray <OCAuthenticationMethodIdentifier> *)allowedMethodIdentifiers preferredMethodIdentifiers:(NSArray <OCAuthenticationMethodIdentifier> *)preferredMethodIdentifiers; //!< Returns allowed entries from methodIdentifiers in order of preferrence

- (NSArray <OCAuthenticationMethodIdentifier> *)filteredAndSortedMethodIdentifiers:(NSArray <OCAuthenticationMethodIdentifier> *)methodIdentifiers; //!< Returns allowed entries from methodIdentifiers in order of preferrence

@end

#pragma mark - SHARING
typedef void(^OCConnectionShareRetrievalCompletionHandler)(NSError * _Nullable error, NSArray <OCShare *> * _Nullable shares);
typedef void(^OCConnectionShareCompletionHandler)(NSError * _Nullable error, OCShare * _Nullable share);

@interface OCConnection (Sharing)

#pragma mark - Retrieval
- (nullable NSProgress *)retrieveSharesWithScope:(OCShareScope)scope forItem:(nullable OCItem *)item options:(nullable NSDictionary *)options completionHandler:(OCConnectionShareRetrievalCompletionHandler)completionHandler; //!< Retrieves the shares for the given scope and (optional) item.

- (nullable NSProgress *)retrieveShareWithID:(OCShareID)shareID options:(nullable NSDictionary *)options completionHandler:(OCConnectionShareCompletionHandler)completionHandler; //!< Retrieves the share for the given shareID.

#pragma mark - Creation and deletion
/**
 Creates a new share on the server.

 @param share The OCShare object with the share to create. Use the OCShare convenience constructors for this object.
 @param options Options (pass nil for now).
 @param eventTarget Event target to receive the outcome via the event's .error and .result. The latter can contain an OCShare object.
 @return A progress object tracking the underlying HTTP request.
 */
- (nullable OCProgress *)createShare:(OCShare *)share options:(nullable OCShareOptions)options resultTarget:(OCEventTarget *)eventTarget;

/**
 Updates an existing share with changes.

 @param share The share to update (without changes).
 @param performChanges A block within which the changes to the share need to be performed (will be called immediately) so the method can detect what changed and perform updates on the server as needed.
 @param eventTarget Event target to receive the outcome via the event's .error and .result. The latter can contain an OCShare object.
 @return A progress object tracking the underlying HTTP request(s).
 */
- (nullable OCProgress *)updateShare:(OCShare *)share afterPerformingChanges:(void(^)(OCShare *share))performChanges resultTarget:(OCEventTarget *)eventTarget;

/**
 Deletes an existing share.

 @param share The share to delete.
 @param eventTarget Event target to receive the outcome via the event's .error.
 @return A progress object tracking the underlying HTTP request(s).
 */
- (nullable OCProgress *)deleteShare:(OCShare *)share resultTarget:(OCEventTarget *)eventTarget;

#pragma mark - Federated share management
/**
 Make a decision on whether to allow or reject a request for federated sharing.

 @param share The share to make the decision on.
 @param accept YES to allow the request for sharing. NO to decline it.
 @param eventTarget Event target to receive the outcome via the event's .error.
 @return A progress object tracking the underlying HTTP request(s).
 */
- (nullable OCProgress *)makeDecisionOnShare:(OCShare *)share accept:(BOOL)accept resultTarget:(OCEventTarget *)eventTarget;

#pragma mark - Private Link
- (nullable NSProgress *)retrievePrivateLinkForItem:(OCItem *)item completionHandler:(void(^)(NSError * _Nullable error, NSURL * _Nullable privateLink))completionHandler;
- (nullable NSProgress *)retrievePathForPrivateLink:(NSURL *)privateLink completionHandler:(void(^)(NSError * _Nullable error, NSString * _Nullable path))completionHandler;

@end

#pragma mark - RECIPIENTS
typedef void(^OCConnectionRecipientsRetrievalCompletionHandler)(NSError * _Nullable error, NSArray <OCRecipient *> * _Nullable recipients);

@interface OCConnection (Recipients)

#pragma mark - Retrieval
- (nullable NSProgress *)retrieveRecipientsForItemType:(OCItemType)itemType ofShareType:(nullable NSArray <OCShareTypeID> *)shareTypes searchTerm:(nullable NSString *)searchTerm maximumNumberOfRecipients:(NSUInteger)maximumNumberOfRecipients completionHandler:(OCConnectionRecipientsRetrievalCompletionHandler)completionHandler;

@end

#pragma mark - USERS
@interface OCConnection (Users)

#pragma mark - User info
- (nullable NSProgress *)retrieveLoggedInUserWithCompletionHandler:(void(^)(NSError * _Nullable error, OCUser * _Nullable loggedInUser))completionHandler; //!< Retrieves information on the currently logged in user and returns it via the completion handler
- (nullable NSProgress *)retrieveLoggedInUserWithRequestCustomization:(nullable void(^)(OCHTTPRequest *request))requestCustomizer completionHandler:(void(^)(NSError * _Nullable error, OCUser * _Nullable loggedInUser))completionHandler; //!< Retrieves information on the currently logged in user and returns it via the completion handler. Allows customization of the request with a block before scheduling.

@end

#pragma mark - TOOLS
@interface OCConnection (Tools)

#pragma mark - Endpoints
- (nullable NSString *)pathForEndpoint:(OCConnectionEndpointID)endpoint; //!< Returns the path of an endpoint identified by its OCConnectionEndpointID
- (nullable NSURL *)URLForEndpoint:(OCConnectionEndpointID)endpoint options:(nullable NSDictionary <OCConnectionEndpointURLOption,id> *)options; //!< Returns the URL of an endpoint identified by its OCConnectionEndpointID, allowing additional options (reserved for future use)
- (nullable NSURL *)URLForEndpointPath:(OCPath)endpointPath; //!< Returns the URL of the endpoint at the supplied endpointPath

#pragma mark - Base URL Extract
+ (nullable NSURL *)extractBaseURLFromRedirectionTargetURL:(NSURL *)inRedirectionTargetURL originalURL:(NSURL *)inOriginalURL originalBaseURL:(NSURL *)inOriginalBaseURL;
- (nullable NSURL *)extractBaseURLFromRedirectionTargetURL:(NSURL *)inRedirectionTargetURL originalURL:(NSURL *)inOriginalURL;

#pragma mark - Safe upgrades
+ (BOOL)isAlternativeBaseURL:(NSURL *)alternativeBaseURL safeUpgradeForPreviousBaseURL:(NSURL *)baseURL;

@end

#pragma mark - COMPATIBILITY
@interface OCConnection (Compatibility)

#pragma mark - Retrieve capabilities
- (nullable NSProgress *)retrieveCapabilitiesWithCompletionHandler:(void(^)(NSError * _Nullable error, OCCapabilities * _Nullable capabilities))completionHandler;

#pragma mark - Version
- (nullable NSString *)serverVersion; //!< After connecting, the version of the server ("version"), f.ex. "10.0.8.5".
- (nullable NSString *)serverVersionString; //!< After connecting, the version string of the server ("versionstring"), fe.x. "10.0.8", "10.1.0 prealpha"
- (BOOL)runsServerVersionOrHigher:(NSString *)version; //!< Returns YES if the server runs at least [version].

- (nullable NSString *)serverProductName; //!< After connecting, the product name of the server ("productname"), f.ex. "ownCloud".
- (nullable NSString *)serverEdition; //!< After connecting, the edition of the server ("edition"), f.ex. "Community".

- (nullable NSString *)serverLongProductVersionString; //!< After connecting, a string summarizing the product, edition and version, f.ex. "ownCloud Community 10.0.8.5"
+ (nullable NSString *)serverLongProductVersionStringFromServerStatus:(NSDictionary<NSString *, id> *)serverStatus;

#pragma mark - API Switches
- (BOOL)supportsPreviewAPI; //!< Returns YES if the server supports the Preview API.

#pragma mark - Checks
- (nullable NSError *)supportsServerVersion:(NSString *)serverVersion product:(NSString *)product longVersion:(NSString *)longVersion allowHiddenVersion:(BOOL)allowHiddenVersion;
@end

extern OCConnectionEndpointID OCConnectionEndpointIDWellKnown;
extern OCConnectionEndpointID OCConnectionEndpointIDCapabilities;
extern OCConnectionEndpointID OCConnectionEndpointIDUser;
extern OCConnectionEndpointID OCConnectionEndpointIDWebDAV;
extern OCConnectionEndpointID OCConnectionEndpointIDWebDAVMeta;
extern OCConnectionEndpointID OCConnectionEndpointIDWebDAVRoot; //!< Virtual, non-configurable endpoint, builds the root URL based on OCConnectionEndpointIDWebDAV and the username found in connection.loggedInUser
extern OCConnectionEndpointID OCConnectionEndpointIDThumbnail;
extern OCConnectionEndpointID OCConnectionEndpointIDStatus;
extern OCConnectionEndpointID OCConnectionEndpointIDShares;
extern OCConnectionEndpointID OCConnectionEndpointIDRemoteShares;
extern OCConnectionEndpointID OCConnectionEndpointIDRecipients;

extern OCConnectionEndpointURLOption OCConnectionEndpointURLOptionWellKnownSubPath;

extern OCClassSettingsKey OCConnectionPreferredAuthenticationMethodIDs; //!< Array of OCAuthenticationMethodIdentifiers of preferred authentication methods in order of preference, starting with the most preferred. Defaults to @[ OCAuthenticationMethodIdentifierOAuth2, OCAuthenticationMethodIdentifierBasicAuth ]. [NSArray <OCAuthenticationMethodIdentifier> *]
extern OCClassSettingsKey OCConnectionAllowedAuthenticationMethodIDs; //!< Array of OCAuthenticationMethodIdentifiers of allowed authentication methods. Defaults to nil for no restrictions. [NSArray <OCAuthenticationMethodIdentifier> *]
extern OCClassSettingsKey OCConnectionCertificateExtendedValidationRule; //!< Rule that defines the criteria a certificate needs to meet for OCConnection to accept it.
extern OCClassSettingsKey OCConnectionRenewedCertificateAcceptanceRule; //!< Rule that defines the criteria that need to be met for OCConnection to accept a renewed certificate automatically. Used when OCConnectionCertificateExtendedValidationRule fails. Set this to "never" if the user should always be prompted when a server's certificate changed.
extern OCClassSettingsKey OCConnectionMinimumVersionRequired; //!< Makes sure connections via -connectWithCompletionHandler:completionHandler: can only be made to servers with this version number or higher.
extern OCClassSettingsKey OCConnectionAllowBackgroundURLSessions; //!< Allows (TRUE) or disallows (FALSE) the use of background URL sessions. Defaults to TRUE.
extern OCClassSettingsKey OCConnectionForceBackgroundURLSessions; //!< Forces (TRUE) or allows (FALSE) the use of background URL sessions everywhere. Defaults to FALSE.
extern OCClassSettingsKey OCConnectionAllowCellular; //!< Allows (TRUE) or disallows(FALSE) the use of cellular connections
extern OCClassSettingsKey OCConnectionPlainHTTPPolicy; //!< Either "warn" (for OCConnectionSetupHTTPPolicyWarn) or "forbidden" (for OCConnectionSetupHTTPPolicyForbidden). Controls if plain-text HTTP URLs should be allow for setup with warning - or not at all.
extern OCClassSettingsKey OCConnectionAlwaysRequestPrivateLink; //!< Controls whether private links are requested with regular PROPFINDs.
extern OCClassSettingsKey OCConnectionTransparentTemporaryRedirect; //!< Allows (TRUE) transparent handling of 307 redirects at the HTTP pipeline level.

extern OCConnectionOptionKey OCConnectionOptionRequestObserverKey;
extern OCConnectionOptionKey OCConnectionOptionLastModificationDateKey; //!< Last modification date for uploads
extern OCConnectionOptionKey OCConnectionOptionIsNonCriticalKey; // Request is non-critical
extern OCConnectionOptionKey OCConnectionOptionChecksumKey; //!< OCChecksum instance to use for the "OC-Checksum" header in uploads
extern OCConnectionOptionKey OCConnectionOptionChecksumAlgorithmKey; //!< OCChecksumAlgorithmIdentifier identifying the checksum algorithm to use to compute checksums for the "OC-Checksum" header in uploads
extern OCConnectionOptionKey OCConnectionOptionGroupIDKey; //!< OCHTTPRequestGroupID to use for requests
extern OCConnectionOptionKey OCConnectionOptionRequiredSignalsKey; //!< NSSet<OCConnectionSignalID> with the signal ids to require for the requests
extern OCConnectionOptionKey OCConnectionOptionRequiredCellularSwitchKey; //!< OCCellularSwitchIdentifier to require for the requests.
extern OCConnectionOptionKey OCConnectionOptionTemporarySegmentFolderURLKey; //!< NSURL of the temporary folder to store file segments in when performing uploads via TUS
extern OCConnectionOptionKey OCConnectionOptionForceReplaceKey; //!< If YES, force replace existing items.

extern OCConnectionSignalID OCConnectionSignalIDAuthenticationAvailable; //!< Signal indicating that authentication is required for this request

NS_ASSUME_NONNULL_END

#import "OCClassSettings.h"

#import "OCHTTPRequest.h"
