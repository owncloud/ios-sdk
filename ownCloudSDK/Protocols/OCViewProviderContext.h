//
//  OCViewProviderContext.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 17.01.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

/*
	The View Provider Context can be used to pass a set of attributes to a view provider, f.ex. to allow further customization or hooks.
	OCViewProviders may only read but not alter the context, so the contact can be initialized once and then passed to an unlimited number of OCViewProviders, i.e. in a large list.
*/

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCViewProviderContextKey;

@interface OCViewProviderContext : NSObject

@property(strong,nullable) NSDictionary<OCViewProviderContextKey,id> *attributes;

@end

NS_ASSUME_NONNULL_END
