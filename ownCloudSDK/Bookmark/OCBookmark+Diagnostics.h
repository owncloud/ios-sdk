//
//  OCBookmark+Diagnostics.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 14.08.20.
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

#import "OCBookmark.h"
#import "OCDiagnosticSource.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCBookmark (Diagnostics) <OCDiagnosticSource>

@end

NS_ASSUME_NONNULL_END
