//
//  OCClassSettingsFlatSource.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 22.03.18.
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
#import "OCClassSettings.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCClassSettingsFlatSource : NSObject <OCClassSettingsSource>
{
	NSMutableDictionary <OCClassSettingsIdentifier, NSMutableDictionary<OCClassSettingsKey, id> *> *_settingsByKeyByIdentifier;
}

- (void)parseFlatSettingsDictionary; //!< Forces parsing of flat settings dictionary

- (nullable NSDictionary <NSString *, id> *)flatSettingsDictionary; //!< Returns dictionary with keys in the form of [settingsIdentifier].[settingsKey] for *all* settings

NS_ASSUME_NONNULL_END

@end
