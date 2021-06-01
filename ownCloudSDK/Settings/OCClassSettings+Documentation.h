//
//  OCClassSettings+Documentation.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 30.10.20.
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

#import "OCClassSettings.h"
#import "OCClassSettings+Metadata.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCClassSettingsDocumentationOption NS_TYPED_ENUM;

@interface OCClassSettings (Documentation)

- (NSArray<Class<OCClassSettingsSupport>> *)implementingClasses;
- (NSArray<Class<OCClassSettingsSupport>> *)snapshotClasses;

- (NSArray<NSDictionary<OCClassSettingsMetadataKey, id> *> *)documentationDictionaryWithOptions:(nullable NSDictionary<OCClassSettingsDocumentationOption, id> *)options;

@end

extern OCClassSettingsDocumentationOption OCClassSettingsDocumentationOptionExternalDocumentationFolders;
extern OCClassSettingsDocumentationOption OCClassSettingsDocumentationOptionOnlyJSONTypes;

NS_ASSUME_NONNULL_END
