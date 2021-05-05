//
//  OCAuthenticationBrowserSessionCustomScheme.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.05.21.
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

#import "OCAuthenticationBrowserSession.h"

NS_ASSUME_NONNULL_BEGIN

@class OCAuthenticationBrowserSessionCustomScheme;

typedef dispatch_block_t _Nullable (^OCAuthenticationBrowserSessionCustomSchemeBusyPresenter)(OCAuthenticationBrowserSessionCustomScheme *browserSession, dispatch_block_t userCancelledAction); //!< Show a busy status to the user, with the ability to cancel. When cancelled, userCancelledAction should be called. Returns a block to dismiss the busy status. That block is always called when the browser session completes, but also when userCancelledAction is called.

@interface OCAuthenticationBrowserSessionCustomScheme : OCAuthenticationBrowserSession

@property(class,nonatomic,strong,nullable) OCAuthenticationBrowserSessionCustomScheme *activeSession;
@property(class,nonatomic,copy,nullable) OCAuthenticationBrowserSessionCustomSchemeBusyPresenter busyPresenter;

+ (BOOL)handleOpenURL:(NSURL *)url;

@property(readonly,strong,nonatomic,nullable) NSString *plainCustomScheme;
@property(readonly,strong,nonatomic,nullable) NSString *secureCustomScheme;

@end

extern OCClassSettingsKey OCClassSettingsKeyItemBrowserSessionCustomSchemePlain;
extern OCClassSettingsKey OCClassSettingsKeyItemBrowserSessionCustomSchemeSecure;

NS_ASSUME_NONNULL_END
