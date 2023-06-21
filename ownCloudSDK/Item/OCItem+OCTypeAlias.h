//
//  OCItem+OCTypeAlias.h
//  ownCloudApp
//
//  Created by Felix Schwarz on 12.09.22.
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

#import "OCItem.h"
#import "OCTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCItem (MIMETypeAliases)

@property(class, readonly,nonatomic) NSDictionary<OCMIMEType, OCTypeAlias> *mimeTypeToAliasesMap;

+ (nullable OCTypeAlias)typeAliasForMIMEType:(nullable OCMIMEType)mimeType;
+ (NSArray<OCMIMEType> *)mimeTypesMatching:(BOOL(^)(OCMIMEType mimeType, OCTypeAlias alias))matcher;

@property(readonly,nonatomic) OCTypeAlias typeAlias;

@end

extern OCTypeAlias OCTypeAliasMIMEPrefix; //!< If no OCTypeAlias is available for an OCMIMEType, the returned OCTypeAlias is (OCTypeAliasMIMEPrefix + mimeType)

NS_ASSUME_NONNULL_END
