//
//  OCMessageTemplate.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 30.03.20.
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

#import "OCMessageTemplate.h"

static NSMutableDictionary<OCMessageTemplateIdentifier, OCMessageTemplate *> *sTemplatesByIdentifier;

@implementation OCMessageTemplate

+ (void)registerTemplates:(NSArray<OCMessageTemplate *> *)syncIssueTemplates
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sTemplatesByIdentifier = [NSMutableDictionary new];
	});

	@synchronized(self)
	{
		for (OCMessageTemplate *syncIssueTemplate in syncIssueTemplates)
		{
			[sTemplatesByIdentifier setObject:syncIssueTemplate forKey:syncIssueTemplate.identifier];
		}
	}
}

+ (nullable OCMessageTemplate *)templateForIdentifier:(OCMessageTemplateIdentifier)templateIdentifier
{
	@synchronized(self)
	{
		return ([sTemplatesByIdentifier objectForKey:templateIdentifier]);
	}
}

+ (nullable NSArray<OCMessageTemplate *> *)templates
{
	@synchronized(self)
	{
		return (sTemplatesByIdentifier.allValues);
	}
}

+ (instancetype)templateWithIdentifier:(OCMessageTemplateIdentifier)identifier categoryName:(nullable NSString *)categoryName choices:(NSArray<OCMessageChoice *> *)choices options:(nullable OCMessageTemplateOptions)options
{
	OCMessageTemplate *template = [OCMessageTemplate new];

	template.identifier = identifier;
	template.categoryName = categoryName;
	template.choices = choices;
	template.options = options;

	return (template);
}

@end
