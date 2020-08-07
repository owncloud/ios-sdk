//
//  OCDiagnosticContext.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.07.20.
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

#import <Foundation/Foundation.h>
#import "OCDatabase.h"
#import "OCCore.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCDiagnosticContext : NSObject

@property(weak,nullable) OCCore *core;
@property(weak,nullable,nonatomic) OCVault *vault;
@property(weak,nullable,nonatomic) OCDatabase *database;

- (instancetype)initWithCore:(nullable OCCore *)core;

@end

NS_ASSUME_NONNULL_END
