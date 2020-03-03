//
//  OCWaitConditionIssue.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 06.01.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCWaitCondition.h"
#import "OCSyncIssue.h"
#import "OCProcessSession.h"

NS_ASSUME_NONNULL_BEGIN

@interface OCWaitConditionIssue : OCWaitCondition <NSSecureCoding>
{
	OCSyncIssue *_issue;
}

@property(strong) OCSyncIssue *issue;
@property(strong,nullable) OCProcessSession *processSession;
@property(assign) BOOL resolved;

+ (instancetype)waitForIssueResolution:(OCSyncIssue *)issue;

@end

NS_ASSUME_NONNULL_END
