//
//  OCDatabase+Versions.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.03.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, OCDatabaseVersion) //!< Integer value indicating the version of the database schema used. Increased for every database update.
{
	OCDatabaseVersionUnknown,
	OCDatabaseVersion_11_6,
	OCDatabaseVersion_12_0,

	OCDatabaseVersionLatest = OCDatabaseVersion_12_0
};
