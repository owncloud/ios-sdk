//
//  OCClassSettingsFlatSourceManagedConfiguration.h
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

#import "OCClassSettingsFlatSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCClassSettingsFlatSourceManagedConfiguration : OCClassSettingsFlatSource
{
	NSDictionary *_lastSettings;
}

@end

extern OCClassSettingsSourceIdentifier OCClassSettingsSourceIdentifierManaged;
extern NSNotificationName OCClassSettingsManagedSettingsChanged; //!< This notification is posted when a change in the managed settings (MDM) was detected.

NS_ASSUME_NONNULL_END
