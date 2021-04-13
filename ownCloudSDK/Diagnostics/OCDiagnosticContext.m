//
//  OCDiagnosticContext.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.07.20.
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

#import "OCDiagnosticContext.h"

@implementation OCDiagnosticContext

- (instancetype)initWithCore:(nullable OCCore *)core
{
	if ((self = [super init]) != nil)
	{
		self.core = core;
	}

	return (self);
}

- (OCVault *)vault
{
	if (_vault == nil)
	{
		return (_core.vault);
	}

	return (_vault);
}

- (OCDatabase *)database
{
	if (_database == nil)
	{
		return (_core.vault.database);
	}

	return (_database);
}

@end
