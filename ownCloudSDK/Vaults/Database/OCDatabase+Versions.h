//
//  OCDatabase+Versions.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.03.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, OCDatabaseVersion) //!< Integer value indicating the version of the database schema used. Increased for every database update.
{
	OCDatabaseVersionUnknown,
	OCDatabaseVersion_11_6,

	OCDatabaseVersionLatest = OCDatabaseVersion_11_6
};
