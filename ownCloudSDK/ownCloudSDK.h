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

#import <ownCloudSDK/OCPlatform.h>

#import <ownCloudSDK/OCTypes.h>
#import <ownCloudSDK/OCMacros.h>
#import <ownCloudSDK/OCFeatureAvailability.h>

#import <ownCloudSDK/OCViewProvider.h>
#import <ownCloudSDK/OCViewProviderContext.h>

#import <ownCloudSDK/OCLocale.h>
#import <ownCloudSDK/OCLocaleFilter.h>
#import <ownCloudSDK/OCLocaleFilterClassSettings.h>
#import <ownCloudSDK/OCLocaleFilterVariables.h>
#import <ownCloudSDK/OCLocale+SystemLanguage.h>

#import <ownCloudSDK/NSError+OCError.h>
#import <ownCloudSDK/OCHTTPStatus.h>
#import <ownCloudSDK/NSError+OCHTTPStatus.h>
#import <ownCloudSDK/NSError+OCDAVError.h>
#import <ownCloudSDK/NSError+OCNetworkFailure.h>

#import <ownCloudSDK/OCAppIdentity.h>

#import <ownCloudSDK/OCKeychain.h>
#import <ownCloudSDK/OCCertificate.h>
#import <ownCloudSDK/OCCertificateRuleChecker.h>
#import <ownCloudSDK/OCCertificateStore.h>
#import <ownCloudSDK/OCCertificateStoreRecord.h>

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
#import <ownCloudSDK/OCClassSettingsFlatSourcePostBuild.h>
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
#import <ownCloudSDK/OCItemPolicy+OCDataItem.h>
#import <ownCloudSDK/OCItemPolicyProcessor.h>
#import <ownCloudSDK/OCItemPolicyProcessorAvailableOffline.h>
#import <ownCloudSDK/OCItemPolicyProcessorDownloadExpiration.h>
#import <ownCloudSDK/OCItemPolicyProcessorVacuum.h>

#import <ownCloudSDK/OCPasswordPolicy.h>
#import <ownCloudSDK/OCPasswordPolicyRule.h>
#import <ownCloudSDK/OCPasswordPolicyRule+StandardRules.h>
#import <ownCloudSDK/OCPasswordPolicyReport.h>
#import <ownCloudSDK/OCCapabilities+PasswordPolicy.h>

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

#import <ownCloudSDK/OCAuthenticationBrowserSession.h>
#import <ownCloudSDK/OCAuthenticationBrowserSessionCustomScheme.h>

#import <ownCloudSDK/OCConnection.h>
#import <ownCloudSDK/OCCapabilities.h>

#import <ownCloudSDK/OCServerInstance.h>
#import <ownCloudSDK/OCBookmark+ServerInstance.h>

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
#import <ownCloudSDK/OCVaultLocation.h>
#import <ownCloudSDK/OCDatabase.h>
#import <ownCloudSDK/OCDatabase+Versions.h>
#import <ownCloudSDK/OCDatabaseConsistentOperation.h>
#import <ownCloudSDK/OCSQLiteDB.h>
#import <ownCloudSDK/OCSQLiteQuery.h>
#import <ownCloudSDK/OCSQLiteQueryCondition.h>
#import <ownCloudSDK/OCSQLiteTransaction.h>
#import <ownCloudSDK/OCSQLiteResultSet.h>
#import <ownCloudSDK/OCSQLiteCollation.h>
#import <ownCloudSDK/OCSQLiteCollationLocalized.h>

#import <ownCloudSDK/OCBookmark+Prepopulation.h>
#import <ownCloudSDK/OCVault+Prepopulation.h>
#import <ownCloudSDK/OCDAVRawResponse.h>

#import <ownCloudSDK/OCResourceTypes.h>
#import <ownCloudSDK/OCResourceManager.h>
#import <ownCloudSDK/OCResourceManagerJob.h>
#import <ownCloudSDK/OCResourceSource.h>
#import <ownCloudSDK/OCResourceSourceURL.h>
#import <ownCloudSDK/OCResourceSourceStorage.h>
#import <ownCloudSDK/OCResourceRequest.h>
#import <ownCloudSDK/OCResourceRequestImage.h>
#import <ownCloudSDK/OCResource.h>
#import <ownCloudSDK/OCResourceImage.h>
#import <ownCloudSDK/OCResourceTextPlaceholder.h>
#import <ownCloudSDK/OCResourceText.h>
#import <ownCloudSDK/OCResourceSourceAvatarPlaceholders.h>
#import <ownCloudSDK/OCResourceSourceAvatars.h>
#import <ownCloudSDK/OCResourceRequestAvatar.h>
#import <ownCloudSDK/OCResourceSourceItemThumbnails.h>
#import <ownCloudSDK/OCResourceSourceItemLocalThumbnails.h>
#import <ownCloudSDK/OCResourceRequestItemThumbnail.h>
#import <ownCloudSDK/OCResourceSourceURLItems.h>
#import <ownCloudSDK/OCResourceRequestURLItem.h>

#import <ownCloudSDK/OCAvatar.h>

#import <ownCloudSDK/GAGraph.h>
#import <ownCloudSDK/GAGraphObject.h>
#import <ownCloudSDK/GAGraphContext.h>
#import <ownCloudSDK/GAQuota.h>
#import <ownCloudSDK/OCConnection+GraphAPI.h>

#import <ownCloudSDK/OCLocation.h>
#import <ownCloudSDK/OCDrive.h>
#import <ownCloudSDK/OCQuota.h>

#import <ownCloudSDK/OCDataTypes.h>
#import <ownCloudSDK/OCDataSource.h>
#import <ownCloudSDK/OCDataSourceArray.h>
#import <ownCloudSDK/OCDataSourceComposition.h>
#import <ownCloudSDK/OCDataSourceKVO.h>
#import <ownCloudSDK/OCDataSourceMapped.h>
#import <ownCloudSDK/OCDataSourceSubscription.h>
#import <ownCloudSDK/OCDataSourceSnapshot.h>
#import <ownCloudSDK/OCDataItemRecord.h>
#import <ownCloudSDK/OCDataConverter.h>
#import <ownCloudSDK/OCDataConverterPipeline.h>
#import <ownCloudSDK/OCDataItemPresentable.h>
#import <ownCloudSDK/OCDataRenderer.h>

#import <ownCloudSDK/OCCore+DataSources.h>

#import <ownCloudSDK/OCQuery.h>
#import <ownCloudSDK/OCQueryFilter.h>
#import <ownCloudSDK/OCQueryCondition.h>
#import <ownCloudSDK/OCQueryCondition+Item.h>
#import <ownCloudSDK/OCQueryChangeSet.h>

#import <ownCloudSDK/OCItem.h>
#import <ownCloudSDK/OCItem+OCDataItem.h>
#import <ownCloudSDK/OCItem+OCTypeAlias.h>
#import <ownCloudSDK/OCItemVersionIdentifier.h>

#import <ownCloudSDK/OCShare.h>
#import <ownCloudSDK/OCShare+OCDataItem.h>
#import <ownCloudSDK/OCShareRole.h>
#import <ownCloudSDK/OCShareRole+OCDataItem.h>
#import <ownCloudSDK/OCUser.h>
#import <ownCloudSDK/OCGroup.h>
#import <ownCloudSDK/OCIdentity.h>
#import <ownCloudSDK/OCIdentity+DataItem.h>

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

#import <ownCloudSDK/OCAppProvider.h>
#import <ownCloudSDK/OCAppProviderApp.h>
#import <ownCloudSDK/OCAppProviderFileType.h>

#import <ownCloudSDK/OCTUSHeader.h>
#import <ownCloudSDK/NSString+TUSMetadata.h>

#import <ownCloudSDK/NSURL+OCURLNormalization.h>
#import <ownCloudSDK/NSURL+OCURLQueryParameterExtensions.h>
#import <ownCloudSDK/NSString+OCVersionCompare.h>
#import <ownCloudSDK/NSString+OCPath.h>
#import <ownCloudSDK/NSString+OCFormatting.h>
#import <ownCloudSDK/NSProgress+OCExtensions.h>
#import <ownCloudSDK/NSArray+ObjCRuntime.h>
#import <ownCloudSDK/NSArray+OCFiltering.h>
#import <ownCloudSDK/NSArray+OCMapping.h>
#import <ownCloudSDK/NSDate+OCDateParser.h>

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

#import <ownCloudSDK/OCServerLocator.h>

#import <ownCloudSDK/OCVFSTypes.h>
#import <ownCloudSDK/OCVFSCore.h>
#import <ownCloudSDK/OCVFSNode.h>
#import <ownCloudSDK/OCVFSContent.h>
#import <ownCloudSDK/OCItem+OCVFSItem.h>

#import <ownCloudSDK/OCAction.h>
#import <ownCloudSDK/OCSymbol.h>
#import <ownCloudSDK/OCStatistic.h>
