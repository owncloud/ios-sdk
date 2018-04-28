//
//  OCItemVersionIdentifier.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 26.04.18.
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
#import "OCTypes.h"

@interface OCItemVersionIdentifier : NSObject <NSSecureCoding, NSCopying>

@property(strong,readonly) OCFileID fileID; //!< Unique identifier of the item on the server (persists over lifetime of file, incl. across modifications) (files only)
@property(strong,readonly) OCFileETag eTag; //!< ETag of the item on the server (changes with every modification)

- (instancetype)initWithFileID:(OCFileID)fileID eTag:(OCFileETag)eTag;

@end
