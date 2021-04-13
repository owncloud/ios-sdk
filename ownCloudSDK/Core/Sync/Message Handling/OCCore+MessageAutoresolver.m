//
//  OCCore+MessageAutoresolver.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.03.20.
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

#import "OCCore+MessageAutoresolver.h"
#import "NSError+OCError.h"
#import "OCMessage.h"
#import "OCLogger.h"

@implementation OCCore (MessageAutoresolver)

- (BOOL)autoresolveMessage:(nonnull OCMessage *)message
{
	OCSyncIssue *syncIssue;

	if ([message.bookmarkUUID isEqual:_bookmark.uuid])
	{
		NSDate *authenticationValidationDate = self.bookmark.authenticationValidationDate;

		if ((syncIssue = message.syncIssue) != nil)
		{
			for (OCSyncIssueChoice *choice in syncIssue.choices)
			{
				NSError *autochoiceError;

				if ((autochoiceError = choice.autoChoiceForError) != nil)
				{
					if ([autochoiceError isOCError])
					{
						switch (autochoiceError.code)
						{
							// Authorization
							case OCErrorAuthorizationFailed:
								if ((autochoiceError.errorDate != nil) && (authenticationValidationDate != nil) &&
								    ([autochoiceError.errorDate timeIntervalSinceDate:authenticationValidationDate] <= 0)) // Error predates last auth data update
								{
									OCLog(@"Autoresolving syncIssue predating (%@) last authentication validation (%@): picking %@ for %@", autochoiceError.errorDate, authenticationValidationDate, choice.identifier, syncIssue);

									message.pickedChoice = choice;
									return (YES);
								}
							break;
						}
					}
				}
			}
		}
	}

	return (NO);
}

@end
