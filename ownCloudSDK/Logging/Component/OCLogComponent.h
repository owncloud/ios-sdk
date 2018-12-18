//
//  OCLogComponent.h
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCLogComponentIdentifier NS_TYPED_EXTENSIBLE_ENUM;

@interface OCLogComponent : NSObject
{
	OCLogComponentIdentifier _identifier;
	BOOL _enabled;
}

@property(strong,readonly) OCLogComponentIdentifier identifier;

@property(assign,nonatomic) BOOL enabled;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithIdentifier:(OCLogComponentIdentifier)identifier NS_DESIGNATED_INITIALIZER;

- (void)enabledChangedTo:(BOOL)enabled;

@end

NS_ASSUME_NONNULL_END
