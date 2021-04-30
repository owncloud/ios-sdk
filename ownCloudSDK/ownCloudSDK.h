//
//  ownCloudSDK.h
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

//! Project version number for ownCloudSDK.
FOUNDATION_EXPORT double ownCloudSDKVersionNumber;

//! Project version string for ownCloudSDK.
FOUNDATION_EXPORT const unsigned char ownCloudSDKVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <ownCloudSDK/PublicHeader.h>

#import <ownCloudSDK/OCTypes.h>
#import <ownCloudSDK/OCMacros.h>
#import <ownCloudSDK/OCFeatureAvailability.h>

#import <ownCloudSDK/NSError+OCError.h>
#import <ownCloudSDK/OCHTTPStatus.h>
#import <ownCloudSDK/NSError+OCHTTPStatus.h>
#import <ownCloudSDK/NSError+OCDAVError.h>
#import <ownCloudSDK/NSError+OCNetworkFailure.h>

#import <ownCloudSDK/OCAppIdentity.h>

#import <ownCloudSDK/OCKeychain.h>
#import <ownCloudSDK/OCCertificate.h>
#import <ownCloudSDK/OCCertificateRuleChecker.h>

#import <ownCloudSDK/OCClassSetting.h>
#import <ownCloudSDK/OCClassSettings.h>
#import <ownCloudSDK/OCClassSettings+Documentation.h>
#import <ownCloudSDK/OCClassSettings+Metadata.h>
#import <ownCloudSDK/OCClassSettings+Validation.h>
#import <ownCloudSDK/NSObject+OCClassSettings.h>
#import <ownCloudSDK/NSError+OCClassSettings.h>
#import <ownCloudSDK/NSString+OCClassSettings.h>
#import <ownCloudSDK/OCClassSettingsFlatSource.h>
#import <ownCloudSDK/OCClassSettingsFlatSourceManagedConfiguration.h>
#import <ownCloudSDK/OCClassSettingsFlatSourcePropertyList.h>
#import <ownCloudSDK/NSDictionary+OCExpand.h>

#import <ownCloudSDK/OCCore.h>
#import <ownCloudSDK/OCCore+FileProvider.h>
#import <ownCloudSDK/OCCoreItemList.h>
#import <ownCloudSDK/OCCore+ItemList.h>
#import <ownCloudSDK/OCCore+ItemUpdates.h>
#import <ownCloudSDK/OCCore+DirectURL.h>
#import <ownCloudSDK/OCCore+NameConflicts.h>
#import <ownCloudSDK/OCScanJobActivity.h>
#import <ownCloudSDK/NSString+NameConflicts.h>
#import <ownCloudSDK/NSProgress+OCEvent.h>

#import <ownCloudSDK/OCCore+ItemPolicies.h>
#import <ownCloudSDK/OCItemPolicy.h>
#import <ownCloudSDK/OCItemPolicyProcessor.h>
#import <ownCloudSDK/OCItemPolicyProcessorAvailableOffline.h>
#import <ownCloudSDK/OCItemPolicyProcessorDownloadExpiration.h>
#import <ownCloudSDK/OCItemPolicyProcessorVacuum.h>

#import <ownCloudSDK/OCCore+Claims.h>
#import <ownCloudSDK/OCClaim.h>

#import <ownCloudSDK/OCKeyValueStore.h>

#import <ownCloudSDK/OCCoreConnectionStatusSignalProvider.h>

#import <ownCloudSDK/OCBookmark.h>
#import <ownCloudSDK/OCBookmark+Diagnostics.h>

#import <ownCloudSDK/OCAuthenticationMethod.h>
#import <ownCloudSDK/OCAuthenticationMethodBasicAuth.h>
#import <ownCloudSDK/OCAuthenticationMethodOAuth2.h>
#import <ownCloudSDK/OCAuthenticationMethodOpenIDConnect.h>
#import <ownCloudSDK/OCAuthenticationMethod+OCTools.h>

#import <ownCloudSDK/OCConnection.h>
#import <ownCloudSDK/OCCapabilities.h>

#import <ownCloudSDK/OCLockManager.h>
#import <ownCloudSDK/OCLockRequest.h>
#import <ownCloudSDK/OCLock.h>

#import <ownCloudSDK/OCHTTPRequest.h>
#import <ownCloudSDK/OCHTTPRequest+JSON.h>
#import <ownCloudSDK/OCHTTPResponse.h>
#import <ownCloudSDK/OCHTTPDAVRequest.h>

#import <ownCloudSDK/OCHTTPCookieStorage.h>
#import <ownCloudSDK/NSHTTPCookie+OCCookies.h>

#import <ownCloudSDK/OCHTTPPipelineManager.h>
#import <ownCloudSDK/OCHTTPPipeline.h>
#import <ownCloudSDK/OCHTTPPipelineTask.h>
#import <ownCloudSDK/OCHTTPPipelineTaskMetrics.h>
#import <ownCloudSDK/OCHTTPPipelineBackend.h>
#import <ownCloudSDK/OCHTTPPipelineTaskCache.h>

#import <ownCloudSDK/OCHTTPPolicyManager.h>
#import <ownCloudSDK/OCHTTPPolicy.h>

#import <ownCloudSDK/OCHTTPDAVMultistatusResponse.h>

#import <ownCloudSDK/OCHostSimulator.h>
#import <ownCloudSDK/OCHostSimulatorResponse.h>
#import <ownCloudSDK/OCHostSimulatorManager.h>
#import <ownCloudSDK/OCHostSimulator+BuiltIn.h>
#import <ownCloudSDK/OCExtension+HostSimulation.h>

#import <ownCloudSDK/OCWaitCondition.h>

#import <ownCloudSDK/OCEvent.h>
#import <ownCloudSDK/OCEventTarget.h>

#import <ownCloudSDK/OCVault.h>
#import <ownCloudSDK/OCDatabase.h>
#import <ownCloudSDK/OCDatabase+Versions.h>
#import <ownCloudSDK/OCDatabaseConsistentOperation.h>
#import <ownCloudSDK/OCSQLiteDB.h>
#import <ownCloudSDK/OCSQLiteQuery.h>
#import <ownCloudSDK/OCSQLiteQueryCondition.h>
#import <ownCloudSDK/OCSQLiteTransaction.h>
#import <ownCloudSDK/OCSQLiteResultSet.h>

#import <ownCloudSDK/OCQuery.h>
#import <ownCloudSDK/OCQueryFilter.h>
#import <ownCloudSDK/OCQueryCondition.h>
#import <ownCloudSDK/OCQueryCondition+Item.h>
#import <ownCloudSDK/OCQueryChangeSet.h>

#import <ownCloudSDK/OCItem.h>
#import <ownCloudSDK/OCItemVersionIdentifier.h>

#import <ownCloudSDK/OCShare.h>
#import <ownCloudSDK/OCUser.h>
#import <ownCloudSDK/OCGroup.h>
#import <ownCloudSDK/OCRecipient.h>

#import <ownCloudSDK/OCRecipientSearchController.h>
#import <ownCloudSDK/OCShareQuery.h>

#import <ownCloudSDK/OCActivity.h>
#import <ownCloudSDK/OCActivityManager.h>
#import <ownCloudSDK/OCActivityUpdate.h>

#import <ownCloudSDK/OCSyncRecord.h>
#import <ownCloudSDK/OCSyncRecordActivity.h>

#import <ownCloudSDK/OCSyncIssue.h>
#import <ownCloudSDK/OCSyncIssueChoice.h>
#import <ownCloudSDK/OCMessageTemplate.h>
#import <ownCloudSDK/OCIssue+SyncIssue.h>

#import <ownCloudSDK/OCMessageQueue.h>
#import <ownCloudSDK/OCMessage.h>
#import <ownCloudSDK/OCMessageChoice.h>
#import <ownCloudSDK/OCMessagePresenter.h>

#import <ownCloudSDK/OCTUSHeader.h>
#import <ownCloudSDK/NSString+TUSMetadata.h>

#import <ownCloudSDK/NSURL+OCURLNormalization.h>
#import <ownCloudSDK/NSURL+OCURLQueryParameterExtensions.h>
#import <ownCloudSDK/NSString+OCVersionCompare.h>
#import <ownCloudSDK/NSString+OCPath.h>
#import <ownCloudSDK/NSString+OCFormatting.h>
#import <ownCloudSDK/NSProgress+OCExtensions.h>
#import <ownCloudSDK/NSArray+ObjCRuntime.h>

#import <ownCloudSDK/UIImage+OCTools.h>

#import <ownCloudSDK/OCXMLNode.h>
#import <ownCloudSDK/OCXMLParser.h>
#import <ownCloudSDK/OCXMLParserNode.h>

#import <ownCloudSDK/OCCache.h>

#import <ownCloudSDK/OCCoreManager.h>
#import <ownCloudSDK/OCCoreManager+ItemResolution.h>
#import <ownCloudSDK/OCBookmarkManager.h>
#import <ownCloudSDK/OCBookmarkManager+ItemResolution.h>

#import <ownCloudSDK/OCChecksum.h>
#import <ownCloudSDK/OCChecksumAlgorithm.h>
#import <ownCloudSDK/OCChecksumAlgorithmSHA1.h>

#import <ownCloudSDK/OCFile.h>

#import <ownCloudSDK/OCProgress.h>

#import <ownCloudSDK/OCLogger.h>
#import <ownCloudSDK/OCLogComponent.h>
#import <ownCloudSDK/OCLogToggle.h>
#import <ownCloudSDK/OCLogFileRecord.h>
#import <ownCloudSDK/OCLogWriter.h>
#import <ownCloudSDK/OCLogFileWriter.h>
#import <ownCloudSDK/OCLogTag.h>

#import <ownCloudSDK/OCExtensionTypes.h>
#import <ownCloudSDK/OCExtensionManager.h>
#import <ownCloudSDK/OCExtensionContext.h>
#import <ownCloudSDK/OCExtensionLocation.h>
#import <ownCloudSDK/OCExtensionMatch.h>
#import <ownCloudSDK/OCExtension.h>
#import <ownCloudSDK/OCExtension+License.h>

#import <ownCloudSDK/OCIPNotificationCenter.h>

#import <ownCloudSDK/OCBackgroundTask.h>

#import <ownCloudSDK/OCProcessManager.h>
#import <ownCloudSDK/OCProcessSession.h>

#import <ownCloudSDK/OCCellularManager.h>
#import <ownCloudSDK/OCCellularSwitch.h>

#import <ownCloudSDK/OCNetworkMonitor.h>

#import <ownCloudSDK/OCDiagnosticSource.h>
#import <ownCloudSDK/OCDiagnosticNode.h>
#import <ownCloudSDK/OCDatabase+Diagnostic.h>
#import <ownCloudSDK/OCSyncRecord+Diagnostic.h>
#import <ownCloudSDK/OCHTTPPipeline+Diagnostic.h>

#import <ownCloudSDK/OCAsyncSequentialQueue.h>
#import <ownCloudSDK/OCRateLimiter.h>
#import <ownCloudSDK/OCDeallocAction.h>
#import <ownCloudSDK/OCCancelAction.h>
#import <ownCloudSDK/OCMeasurement.h>
#import <ownCloudSDK/OCMeasurementEvent.h>
