//
//  OCYAMLNode+GeneratorTools.h
//  ocapigen
//
//  Created by Felix Schwarz on 28.11.24.
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

#import "OCYAMLNode.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCYAMLNode (GeneratorTools)

@property(readonly,nonatomic,nullable,strong) NSArray<NSString *> *requiredProperties;

@end

NS_ASSUME_NONNULL_END
