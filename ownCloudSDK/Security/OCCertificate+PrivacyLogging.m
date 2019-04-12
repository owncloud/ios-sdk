//
//  OCCertificate+PrivacyLogging.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 12.04.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCertificate+PrivacyLogging.h"

@implementation OCCertificate (PrivacyLogging)

- (NSString *)privacyMaskedDescription
{
	return ([NSString stringWithFormat:@"<%@: %p%@>", NSStringFromClass(self.class), self, ((self.parentCertificate != nil) ? [NSString stringWithFormat:@", parent: %@", [self.parentCertificate privacyMaskedDescription]] : @"")]);
}

@end
