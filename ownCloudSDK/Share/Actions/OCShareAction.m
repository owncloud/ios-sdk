//
//  OCShareAction.m
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

#import "OCShareAction.h"

// via https://github.com/owncloud/web/blob/16ac024fc931ff9131194643f6f78994cc757e2d/packages/web-client/src/helpers/share/types.ts#L9
OCShareActionID OCShareActionIDCreateUpload = @"libre.graph/driveItem/upload/create'";
OCShareActionID OCShareActionIDCreatePermissions = @"libre.graph/driveItem/permissions/create'";
OCShareActionID OCShareActionIDCreateChildren = @"libre.graph/driveItem/children/create'";
OCShareActionID OCShareActionIDReadBasic = @"libre.graph/driveItem/basic/read'";
OCShareActionID OCShareActionIDReadPath = @"libre.graph/driveItem/path/read'";
OCShareActionID OCShareActionIDReadQuota = @"libre.graph/driveItem/quota/read'";
OCShareActionID OCShareActionIDReadContent = @"libre.graph/driveItem/content/read'";
OCShareActionID OCShareActionIDReadChildren = @"libre.graph/driveItem/children/read'";
OCShareActionID OCShareActionIDReadDeleted = @"libre.graph/driveItem/deleted/read'";
OCShareActionID OCShareActionIDReadPermissions = @"libre.graph/driveItem/permissions/read'";
OCShareActionID OCShareActionIDReadVersions = @"libre.graph/driveItem/versions/read'";
OCShareActionID OCShareActionIDUpdatePath = @"libre.graph/driveItem/path/update'";
OCShareActionID OCShareActionIDUpdateDeleted = @"libre.graph/driveItem/deleted/update'";
OCShareActionID OCShareActionIDUpdatePermissions = @"libre.graph/driveItem/permissions/update'";
OCShareActionID OCShareActionIDUpdateVersions = @"libre.graph/driveItem/versions/update'";
OCShareActionID OCShareActionIDDeleteStandard = @"libre.graph/driveItem/standard/delete'";
OCShareActionID OCShareActionIDDeleteDeleted = @"libre.graph/driveItem/deleted/delete'";
OCShareActionID OCShareActionIDDeletePermissions = @"libre.graph/driveItem/permissions/delete";

