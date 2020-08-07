//
//  OCDiagnosticNode.h
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

NS_ASSUME_NONNULL_BEGIN

@class OCDiagnosticContext;

typedef NS_ENUM(NSUInteger, OCDiagnosticNodeType)
{
	OCDiagnosticNodeTypeInfo,
	OCDiagnosticNodeTypeAction,
	OCDiagnosticNodeTypeGroup
};

typedef void(^OCDiagnosticNodeAction)(OCDiagnosticContext * _Nullable context);

typedef NSString* OCDiagnosticNodeIdentifier NS_TYPED_ENUM;

@interface OCDiagnosticNode : NSObject

@property(strong,nullable) OCDiagnosticNodeIdentifier identifier;

@property(readonly,nonatomic) OCDiagnosticNodeType type;

@property(strong,nullable) NSString *label;
@property(strong,nullable) NSString *content;

@property(copy,nullable) OCDiagnosticNodeAction action;

@property(strong,nonatomic,nullable) NSArray<OCDiagnosticNode *> *children;

@property(readonly,nonatomic) BOOL isEmpty;

+ (instancetype)withLabel:(NSString *)label content:(nullable NSString *)content;
+ (instancetype)withLabel:(NSString *)label action:(nullable OCDiagnosticNodeAction)action;
+ (instancetype)withLabel:(NSString *)label children:(nullable NSArray<OCDiagnosticNode *> *)children;

- (instancetype)withIdentifier:(nullable OCDiagnosticNodeIdentifier)identifier;

- (nullable NSString *)composeMarkdown;

@end

NS_ASSUME_NONNULL_END
