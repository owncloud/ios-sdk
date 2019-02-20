//
//  OCActivity.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 24.01.19.
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

#import "OCActivity.h"
#import "OCActivityUpdate.h"
#import "NSError+OCError.h"

@implementation OCActivity

@synthesize identifier = _identifier;

@synthesize ranking = _ranking;

@synthesize localizedDescription = _localizedDescription;
@synthesize localizedStatusMessage = _localizedStatusMessage;

@synthesize progress = _progress;

@synthesize issue = _issue;

@synthesize isCancellable = _isCancellable;

+ (instancetype)withIdentifier:(OCActivityIdentifier)identifier description:(NSString *)description statusMessage:(nullable NSString *)statusMessage ranking:(NSInteger)ranking
{
	OCActivity *activity = [OCActivity new];

	activity.identifier = identifier;
	activity.localizedDescription = description;
	activity.localizedStatusMessage = statusMessage;
	activity.ranking = ranking;

	return (activity);
}

- (instancetype)initWithIdentifier:(OCActivityIdentifier)identifier
{
	if ((self = [super init]) != nil)
	{
		_identifier = identifier;
	}

	return (self);
}

- (void)cancel
{
	if (_isCancellable)
	{
		[self.progress cancel];
	}
}

- (NSError *)applyUpdate:(OCActivityUpdate *)update
{
	__block NSError *error = nil;

	if (update.type != OCActivityUpdateTypeProperty)
	{
		return (OCError(OCErrorInsufficientParameters));
	}

	[update.updatesByKeyPath enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull keyPath, id<NSObject> value, BOOL * _Nonnull stop) {
		NSError *applicationError = nil;

		if ([value isEqual:[NSNull null]])
		{
			value = nil;
		}

		if ((applicationError = [self applyValue:value forKeyPath:keyPath]) != nil)
		{
			error = applicationError;
			*stop = YES;
		}
	}];

	return (error);
}

- (NSError *)applyValue:(nullable id <NSObject>)value forKeyPath:(NSString *)keyPath
{
	// Entrypoint for subclassing
	[self setValue:value forKeyPath:keyPath];

	return (nil);
}

@end
