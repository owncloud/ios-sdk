//
//  OCCore+NameConflicts.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 29.06.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCore.h"

typedef NS_ENUM(NSUInteger, OCCoreDuplicateNameStyle)
{
	OCCoreDuplicateNameStyleNone,		//!< No known duplicate name style / No duplicate name
	OCCoreDuplicateNameStyleCopy,		//!< Duplicate names follow the pattern File.jpg, File copy.jpg, File copy 2.jpg, ...
	OCCoreDuplicateNameStyleCopyLocalized,	//!< Duplicate names follow the pattern File.jpg, File Kopie.jpg, File Kopie 2.jpg, ...
	OCCoreDuplicateNameStyleBracketed,	//!< Duplicate names follow the pattern File.jpg, File (1).jpg, File (2).jpg, ...
	OCCoreDuplicateNameStyleNumbered	//!< Duplicate names follow the pattern File.jpg, File 2.jpg, File 3.jpg, ...
};

NS_ASSUME_NONNULL_BEGIN

typedef BOOL(^OCCoreUnusedNameSuggestionFilter)(NSString *suggestedName); //!< Block to filter suggestions. Return YES if a suggestion should be further considered, NO if it should not.

typedef void(^OCCoreUnusedNameSuggestionResultHandler)(NSString * _Nullable suggestedName, NSArray<NSString *> * _Nullable rejectedAndTakenNames); //!< Block to receive the suggestedName as well as an array of (filter-)rejected and (cache-)taken names.

@interface OCCore (NameConflicts)

- (void)suggestUnusedNameBasedOn:(NSString *)name atPath:(OCPath)path isDirectory:(BOOL)isDirectory usingNameStyle:(OCCoreDuplicateNameStyle)nameStyle filteredBy:(nullable OCCoreUnusedNameSuggestionFilter)filter resultHandler:(OCCoreUnusedNameSuggestionResultHandler)resultHandler; //!< Request a suggestion for an unused item name based on a given name and path, filtered by an optional block, returning a suggested name and an array of evaluated, but taken names. 

@end

NS_ASSUME_NONNULL_END
