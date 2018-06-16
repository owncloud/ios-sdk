//
//  OCConnectionIssueChoice.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 15.06.18.
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
#import "OCConnectionIssue.h"

typedef void(^OCConnectionIssueChoiceHandler)(OCConnectionIssue *issue, OCConnectionIssueChoice *choice);

typedef NS_ENUM(NSInteger,OCConnectionIssueChoiceType)
{
	OCConnectionIssueChoiceTypeCancel,
	OCConnectionIssueChoiceTypeRegular,
	OCConnectionIssueChoiceTypeDefault,
	OCConnectionIssueChoiceTypeDestructive
};

@interface OCConnectionIssueChoice : NSObject

@property(assign) OCConnectionIssueChoiceType type;

@property(strong) NSString *identifier;

@property(strong) NSString *label;
@property(copy) OCConnectionIssueChoiceHandler choiceHandler;

@property(strong) id<NSObject> userInfo;

+ (instancetype)choiceWithType:(OCConnectionIssueChoiceType)type identifier:(NSString *)identifier label:(NSString *)label userInfo:(id<NSObject>)userInfo handler:(OCConnectionIssueChoiceHandler)handler;

+ (instancetype)choiceWithType:(OCConnectionIssueChoiceType)type label:(NSString *)label handler:(OCConnectionIssueChoiceHandler)handler;

@end
