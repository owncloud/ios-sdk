//
//  OCSyncRecord.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.02.18.
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
#import "OCActivity.h"
#import "OCItem.h"

typedef NSString* OCSyncAction NS_TYPED_ENUM;
typedef NSString* OCSyncActionParameter NS_TYPED_ENUM;

@interface OCSyncRecord : NSObject <NSSecureCoding>
{
	OCSyncAction _action;
	NSDate *_timestamp;

	NSData *_archivedServerItemData;
	OCItem *_archivedServerItem;

	NSDictionary<OCSyncActionParameter, id> *_parameters;
}

@property(readonly) OCSyncAction action; //!< The action
@property(readonly) NSDate *timestamp; //!< Time the action was triggered

@property(readonly) OCItem *archivedServerItem; //!< Archived OCItem describing the (known) server item at the time the record was committed.

@property(readonly) NSDictionary<OCSyncActionParameter, id> *parameters; //!< Parameters specific to the respective sync action

@end

extern OCSyncAction OCSyncActionDeleteLocal; //!< Locally triggered deletion
extern OCSyncAction OCSyncActionDeleteRemote; //!< Remotely triggered deletion
extern OCSyncAction OCSyncActionMove;
extern OCSyncAction OCSyncActionCopy;
extern OCSyncAction OCSyncActionCreateFolder;
extern OCSyncAction OCSyncActionUpload;
extern OCSyncAction OCSyncActionDownload;

extern OCSyncActionParameter OCSyncActionParameterItem; // (OCItem *)
extern OCSyncActionParameter OCSyncActionParameterPath; // (OCPath)
extern OCSyncActionParameter OCSyncActionParameterSourcePath; // (OCPath)
extern OCSyncActionParameter OCSyncActionParameterTargetPath; // (OCPath)
