//
//  OCKeyValueStore.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.07.18.
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

/*
	The OCKeyValueStore provides a simple interface to persists, retrieve and delete objects on disk.
	Under the hood, it archives the objects and saves them to a file by the name of the key inside the
	rootURL.

	OCKeyValueStore is accessed through subscripting, i.e.

		OCKeyValueStore *keyValueStore;

		// Set value
		keyValueStore[@"example"] = [NSDate date];

		// Get value
		OCLogDebug(@"Example value: %@", keyValueStore[@"example"]);

		// Delete value
 		keyValueStore[@"example"] = nil;
*/

#import <Foundation/Foundation.h>
#import "OCLogger.h"

@interface OCKeyValueStore : NSObject <OCLogTagging>
{
	NSURL *_rootURL;
}

@property(readonly,strong) NSURL *rootURL;

@property(readonly,nonatomic,strong) NSArray <NSString *> *allKeys;

- (instancetype)initWithRootURL:(NSURL *)rootURL;

#pragma mark - Keyed subscripting support
- (id)objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(id)object forKeyedSubscript:(NSString *)key;

#pragma mark - Erase backing store
- (NSError *)eraseBackinngStore;

@end
