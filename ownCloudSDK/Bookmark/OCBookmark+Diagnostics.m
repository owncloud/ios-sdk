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
#import "OCMacros.h"

@implementation OCBookmark (Diagnostics)

- (NSArray<OCDiagnosticNode *> *)diagnosticNodesWithContext:(OCDiagnosticContext *)context
{
	return (@[
		[OCDiagnosticNode withLabel:OCLocalized(@"UUID") 			content:self.uuid.UUIDString],
		[OCDiagnosticNode withLabel:OCLocalized(@"Name") 			content:self.name],
		[OCDiagnosticNode withLabel:OCLocalized(@"URL") 			content:self.url.absoluteString],
		[OCDiagnosticNode withLabel:OCLocalized(@"Origin URL")			content:self.originURL.absoluteString],

		[OCDiagnosticNode withLabel:OCLocalized(@"Certificate Date")		content:self.certificateModificationDate.description],

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
		}]
	]);
}

@end
