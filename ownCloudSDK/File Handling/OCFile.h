//
//  OCFile.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.06.18.
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
#import "OCChecksum.h"
#import "OCItem.h"

@interface OCFile : NSObject <NSSecureCoding>
{
	OCItem *_item;

	NSURL *_url;

	OCChecksum *_checksum;
}

@property(strong) OCItem *item;
@property(strong) NSURL *url;
@property(strong) OCChecksum *checksum;

@end
