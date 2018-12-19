//
//  OCSyncIssue.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.12.18.
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
#import "OCIssue.h"
#import "OCSyncIssueChoice.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCSyncIssue : NSObject <NSSecureCoding>

@property(readonly,strong) NSDate *creationDate;
@property(readonly,strong) NSUUID *uuid;

@property(assign) OCIssueLevel level;

@property(strong) NSString *localizedTitle;
@property(nullable,strong) NSString *localizedDescription;

@property(strong) NSArray <OCSyncIssueChoice *> *choices;

+ (instancetype)issueWithLevel:(OCIssueLevel)level title:(NSString *)title description:(nullable NSString *)description choices:(NSArray <OCSyncIssueChoice *> *)choices;

+ (instancetype)warningIssueWithTitle:(NSString *)title description:(nullable NSString *)description choices:(NSArray <OCSyncIssueChoice *> *)choices;
+ (instancetype)errorIssueWithTitle:(NSString *)title description:(nullable NSString *)description choices:(NSArray <OCSyncIssueChoice *> *)choices;

@end

NS_ASSUME_NONNULL_END
