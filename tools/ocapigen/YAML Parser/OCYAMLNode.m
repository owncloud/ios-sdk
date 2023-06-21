//
//  OCYAMLNode.m
//  ocapigen
//
//  Created by Felix Schwarz on 26.01.22.
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

#import "OCYAMLNode.h"

@implementation OCYAMLNode

- (instancetype)initWithName:(NSString *)name value:(id)value
{
	if ((self = [super init]) != nil)
	{
		_name = name;
		_value = value;
		_childrenByName = NSMutableDictionary.new;
		_children = NSMutableArray.new;
	}

	return (self);
}

- (void)addChild:(OCYAMLNode *)child
{
	child.parentNode = self;

	_childrenByName[child.name] = child;
	[_children addObject:child];
}

- (OCYAMLPath)path
{
	NSString *path = self.name;
	OCYAMLNode *node = self.parentNode;

	do
	{
		path = [NSString stringWithFormat:@"%@/%@", node.name, path];

		node = node.parentNode;
	}while(node != nil);

	path = [@"#/" stringByAppendingString:path];

	return (path);
}

@end
