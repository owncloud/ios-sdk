//
//  NSString+TUSMetadata.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.04.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

typedef NSString* OCTUSMetadataKey;
typedef NSString* OCTUSMetadataString;
typedef NSDictionary<OCTUSMetadataKey,NSString*>* OCTUSMetadata;

NS_ASSUME_NONNULL_BEGIN

@interface NSString (TUSMetadata)

+ (nullable OCTUSMetadataString)stringFromTUSMetadata:(nullable OCTUSMetadata)metadata; //!< Creates an "Upload-Metadata"-styled string from an NSDictionary

@property(nullable,strong,readonly) OCTUSMetadata tusMetadata; //!< Returns an NSDictionary from an "Upload-Metadata"-styled string

@end

extern NSString *OCTUSMetadataNilValue; //!< Value for keys that should be encoded solely as keys, but without value

extern OCTUSMetadataKey OCTUSMetadataKeyFileName;
extern OCTUSMetadataKey OCTUSMetadataKeyChecksum;

NS_ASSUME_NONNULL_END
