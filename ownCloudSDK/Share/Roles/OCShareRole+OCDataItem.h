//
//  OCShareRole+OCDataItem.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.04.23.
//  Copyright © 2023 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2023, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCShareRole.h"
#import "OCDataTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCShareRole (OCDataItem) <OCDataItem, OCDataItemVersioning>

@end

NS_ASSUME_NONNULL_END
