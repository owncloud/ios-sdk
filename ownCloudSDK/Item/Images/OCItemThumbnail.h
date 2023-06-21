//
//  OCItemThumbnail.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 25.04.18.
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

#import "OCImage.h"
#import "OCTypes.h"
#import "OCItemVersionIdentifier.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCItemThumbnail : OCImage <NSSecureCoding>
{
	OCItemVersionIdentifier *_itemVersionIdentifier;
	NSString *_specID;
}

@property(strong,nullable) OCItemVersionIdentifier *itemVersionIdentifier;
@property(strong,nullable) NSString *specID;

@end

NS_ASSUME_NONNULL_END
