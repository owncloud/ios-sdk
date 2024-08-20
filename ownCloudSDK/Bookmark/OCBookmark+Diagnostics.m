//
//  OCBookmark+Diagnostics.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.08.20.
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

#import "OCBookmark+Diagnostics.h"
#import "OCAuthenticationMethodBasicAuth.h"
#import "OCAuthenticationMethodOAuth2.h"
#import "OCAuthenticationMethodOpenIDConnect.h"
#import "OCMacros.h"
#import "OCBookmarkManager.h"
#import "OCCoreManager.h"
#import "OCCertificateStoreRecord.h"

@implementation OCBookmark (Diagnostics)

- (NSArray<OCDiagnosticNode *> *)diagnosticNodesWithContext:(OCDiagnosticContext *)context
{
	NSMutableArray<OCDiagnosticNode *> *certificateChildren = [NSMutableArray new];
	__weak OCBookmark *weakSelf = self;

	for (OCCertificateStoreRecord *record in self.certificateStore.allRecords)
	{
		[certificateChildren addObject:[OCDiagnosticNode withLabel:record.hostname children:@[
			[OCDiagnosticNode withLabel:OCLocalizedString(@"Certificate Date",nil) content:record.lastModifiedDate.description],
			[OCDiagnosticNode withLabel:OCLocalizedString(@"Invalidate",nil) action:^(OCDiagnosticContext * _Nullable context) {
				OCCertificate *invalidCertificate = [OCCertificate certificateWithCertificateData:[NSData new] hostName:record.hostname];
				[weakSelf.certificateStore storeCertificate:invalidCertificate forHostname:record.hostname];
			}]
		]]];
	}

	return (@[
		[OCDiagnosticNode withLabel:OCLocalizedString(@"UUID",nil) 			content:self.uuid.UUIDString],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Name",nil) 			content:self.name],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"URL",nil) 			content:self.url.absoluteString],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Origin URL",nil)			content:self.originURL.absoluteString],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Use Origin URL as URL",nil) 	action:^(OCDiagnosticContext * _Nullable context) {
			if (self.originURL != nil)
			{
				self.url = self.originURL;
				self.originURL = nil;

				[[NSNotificationCenter defaultCenter] postNotificationName:OCBookmarkUpdatedNotification object:self];
			}
		}],

		[OCDiagnosticNode withLabel:OCLocalizedString(@"Certificates",nil) 		children:certificateChildren],

		[OCDiagnosticNode withLabel:OCLocalizedString(@"User Name",nil)			content:self.userName],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Auth Method",nil)			content:self.authenticationMethodIdentifier],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Auth Data",nil)			content:[NSString stringWithFormat:@"%lu bytes", (unsigned long)self.authenticationData.length]],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"Auth Validation Date",nil)	content:self.authenticationValidationDate.description],

		[OCDiagnosticNode withLabel:OCLocalizedString(@"Database Version",nil)		content:@(self.databaseVersion).stringValue],
		[OCDiagnosticNode withLabel:OCLocalizedString(@"UserInfo",nil)			content:self.userInfo.description],

		[OCDiagnosticNode withLabel:OCLocalizedString(@"Invalidate Login Data",nil) 	action:^(OCDiagnosticContext * _Nullable context) {
			if ([self.authenticationMethodIdentifier isEqual:OCAuthenticationMethodIdentifierBasicAuth])
			{
				self.authenticationData = [OCAuthenticationMethodBasicAuth authenticationDataForUsername:self.userName passphrase:NSUUID.UUID.UUIDString authenticationHeaderValue:NULL error:NULL];
			}

			if ([self.authenticationMethodIdentifier isEqual:OCAuthenticationMethodIdentifierOAuth2] || [self.authenticationMethodIdentifier isEqual:OCAuthenticationMethodIdentifierOpenIDConnect])
			{
				NSMutableDictionary *plist;

				plist = [NSPropertyListSerialization propertyListWithData:self.authenticationData options:NSPropertyListMutableContainersAndLeaves format:NULL error:NULL];

				if (plist != nil)
				{
					((NSMutableDictionary *)plist[@"tokenResponse"])[@"access_token"] = NSUUID.UUID.UUIDString;
					((NSMutableDictionary *)plist[@"tokenResponse"])[@"refresh_token"] = NSUUID.UUID.UUIDString;
					plist[@"bearerString"] = [@"Bearer " stringByAppendingString:((NSMutableDictionary *)plist[@"tokenResponse"])[@"access_token"]];

					self.authenticationData = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
				}
			}
		}],

		[OCDiagnosticNode withLabel:OCLocalizedString(@"Delete Authentication Data",nil) 	action:^(OCDiagnosticContext * _Nullable context) {
			self.authenticationData = nil;
		}],

		[OCDiagnosticNode withLabel:OCLocalizedString(@"Remove Database Version",nil) 	action:^(OCDiagnosticContext * _Nullable context) {
			self.databaseVersion = OCDatabaseVersionUnknown;
			[[NSNotificationCenter defaultCenter] postNotificationName:OCBookmarkUpdatedNotification object:self];
		}],

		[OCDiagnosticNode withLabel:OCLocalizedString(@"Delete Database",nil) action:^(OCDiagnosticContext * _Nullable context) {
			[OCCoreManager.sharedCoreManager scheduleOfflineOperation:^(OCBookmark * _Nonnull bookmark, dispatch_block_t  _Nonnull completionHandler) {
				OCVault *vault = [[OCVault alloc] initWithBookmark:bookmark];
				NSError *error = nil;
				OCDatabase *database = vault.database;

				[NSFileManager.defaultManager removeItemAtURL:database.databaseURL error:&error];
				OCFileOpLog(@"rm", error, @"Removed database at %@", database.databaseURL.path);

				[NSFileManager.defaultManager removeItemAtURL:database.thumbnailDatabaseURL error:&error];
				OCFileOpLog(@"rm", error, @"Removed thumbnail database at %@", database.thumbnailDatabaseURL.path);

				completionHandler();
			} forBookmark:self];
		}]
	]);
}

@end

