//
//  OCActivity.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, OCActivityType)
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

@interface OCActivity : NSObject

@property(readonly) OCActivityType activityType; //!< Identifies the type of activity
@property(readonly) NSProgress *progress; //!< An NSProgress object if progress tracking is available, nil if it is not available.

@property(readonly) BOOL cancelled; //!< YES, if the activity has been cancelled.

- (void)cancel; //!< Cancel the activity

@end
