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

@implementation OCBookmark (Diagnostics)

- (NSArray<OCDiagnosticNode *> *)diagnosticNodesWithContext:(OCDiagnosticContext *)context
{
	return (@[
		[OCDiagnosticNode withLabel:OCLocalized(@"UUID") 			content:self.uuid.UUIDString],
		[OCDiagnosticNode withLabel:OCLocalized(@"Name") 			content:self.name],
		[OCDiagnosticNode withLabel:OCLocalized(@"URL") 			content:self.url.absoluteString],
		[OCDiagnosticNode withLabel:OCLocalized(@"Origin URL")			content:self.originURL.absoluteString],
		[OCDiagnosticNode withLabel:OCLocalized(@"Use Origin URL as URL") 	action:^(OCDiagnosticContext * _Nullable context) {
			if (self.originURL != nil)
			{
				self.url = self.originURL;
				self.originURL = nil;

				[[NSNotificationCenter defaultCenter] postNotificationName:OCBookmarkUpdatedNotification object:self];
			}
		}],

		[OCDiagnosticNode withLabel:OCLocalized(@"Certificate Date")		content:self.certificateModificationDate.description],
		[OCDiagnosticNode withLabel:OCLocalized(@"Invalidate Certificate") 	action:^(OCDiagnosticContext * _Nullable context) {
			self.certificate = [OCCertificate certificateWithCertificateData:[NSData new] hostName:self.url.host];
		}],

		[OCDiagnosticNode withLabel:OCLocalized(@"User Name")			content:self.userName],
		[OCDiagnosticNode withLabel:OCLocalized(@"Auth Method")			content:self.authenticationMethodIdentifier],
		[OCDiagnosticNode withLabel:OCLocalized(@"Auth Data")			content:[NSString stringWithFormat:@"%lu bytes", (unsigned long)self.authenticationData.length]],
		[OCDiagnosticNode withLabel:OCLocalized(@"Auth Validation Date")	content:self.authenticationValidationDate.description],

		[OCDiagnosticNode withLabel:OCLocalized(@"UserInfo")			content:self.userInfo.description],

		[OCDiagnosticNode withLabel:OCLocalized(@"Invalidate Login Data") 	action:^(OCDiagnosticContext * _Nullable context) {
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

		[OCDiagnosticNode withLabel:OCLocalized(@"Delete Authentication Data") 	action:^(OCDiagnosticContext * _Nullable context) {
			self.authenticationData = nil;
		}]
	]);
}

@end

