//
//  OCCancelAction.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 18.03.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef BOOL(^OCCancelActionHandler)(void);

@interface OCCancelAction : NSObject

@property(assign) BOOL cancelled;
@property(nonatomic,copy,nullable) OCCancelActionHandler handler;

- (BOOL)cancel;

@end

NS_ASSUME_NONNULL_END
