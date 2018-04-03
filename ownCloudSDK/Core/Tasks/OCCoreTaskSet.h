//
//  OCCoreTaskSet.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 02.04.18.
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
#import "OCItem.h"

typedef NS_ENUM(NSUInteger, OCCoreTaskSetState)
{
	OCCoreTaskSetStateNew,
	OCCoreTaskSetStateStarted,
	OCCoreTaskSetStateSuccess,
	OCCoreTaskSetStateFailed
};

@interface OCCoreTaskSet : NSObject

@property(assign) OCCoreTaskSetState state;
@property(strong) NSArray <OCItem *> *items;
@property(strong) NSError *error;

- (void)updateWithError:(NSError *)error items:(NSArray <OCItem *> *)items;

@end
