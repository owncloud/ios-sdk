//
//  OCLogToggle.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 11.12.18.
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

#import "OCLogToggle.h"

@implementation OCLogToggle

- (instancetype)initWithIdentifier:(OCLogOption)identifier localizedName:(NSString *)localizedName
{
	if ((self = [super initWithIdentifier:(OCLogComponentIdentifier)identifier]) != nil)
	{
		_localizedName = localizedName;
	}

	return(self);
}

@end

OCLogComponentIdentifier OCLogOptionLogRequestsAndResponses = @"option.log-requests-and-responses";
OCLogComponentIdentifier OCLogOptionLogFileOperations = @"option.log-file-operations";
