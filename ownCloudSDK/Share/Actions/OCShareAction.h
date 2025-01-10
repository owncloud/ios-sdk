//
//  OCShareAction.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 17.12.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCShareTypes.h"

NS_ASSUME_NONNULL_BEGIN

extern OCShareActionID OCShareActionIDCreateUpload;
extern OCShareActionID OCShareActionIDCreatePermissions;
extern OCShareActionID OCShareActionIDCreateChildren;
extern OCShareActionID OCShareActionIDReadBasic;
extern OCShareActionID OCShareActionIDReadPath;
extern OCShareActionID OCShareActionIDReadQuota;
extern OCShareActionID OCShareActionIDReadContent;
extern OCShareActionID OCShareActionIDReadChildren;
extern OCShareActionID OCShareActionIDReadDeleted;
extern OCShareActionID OCShareActionIDReadPermissions;
extern OCShareActionID OCShareActionIDReadVersions;
extern OCShareActionID OCShareActionIDUpdatePath;
extern OCShareActionID OCShareActionIDUpdateDeleted;
extern OCShareActionID OCShareActionIDUpdatePermissions;
extern OCShareActionID OCShareActionIDUpdateVersions;
extern OCShareActionID OCShareActionIDDeleteStandard;
extern OCShareActionID OCShareActionIDDeleteDeleted;
extern OCShareActionID OCShareActionIDDeletePermissions;

NS_ASSUME_NONNULL_END
