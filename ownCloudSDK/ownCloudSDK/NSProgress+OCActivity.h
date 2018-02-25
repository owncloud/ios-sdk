//
//  NSProgress+OCActivity.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.02.18.
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

typedef NS_ENUM(NSUInteger, OCActivityType)  //!< Identifies the type of activity
{
	OCActivityTypeNone,

	// File activities
	OCActivityTypeCreateFolder,
	OCActivityTypeCopy,
	OCActivityTypeMove,
	OCActivityTypeRename,
	OCActivityTypeDelete,
	OCActivityTypeDownload,
	OCActivityTypeUpload,

	// Metadata activities
	OCActivityTypeRetrieveThumbnail,
	OCActivityTypeRetrieveItemList
};

@interface NSProgress (OCActivity)

- (OCActivityType)activityType;
- (void)setActivityType:(OCActivityType)activityType;

@end
