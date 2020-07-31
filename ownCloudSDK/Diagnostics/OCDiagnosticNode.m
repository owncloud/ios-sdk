//
//  OCDiagnosticNode.m
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

#import "OCDiagnosticNode.h"

@implementation OCDiagnosticNode

+ (instancetype)withLabel:(NSString *)label content:(NSString *)content
{
	OCDiagnosticNode *node = [[self alloc] initWithType:OCDiagnosticNodeTypeInfo];

	node.label = label;
	node.content = content;

	return (node);
}

+ (instancetype)withLabel:(NSString *)label action:(OCDiagnosticNodeAction)action
{
	OCDiagnosticNode *node = [[self alloc] initWithType:OCDiagnosticNodeTypeAction];

	node.label = label;
	node.action = action;

	return (node);
}

+ (instancetype)withLabel:(NSString *)label children:(NSArray<OCDiagnosticNode *> *)children
{
	OCDiagnosticNode *node = [[self alloc] initWithType:OCDiagnosticNodeTypeGroup];

	node.label = label;
	node.children = children;

	return (node);
}

- (instancetype)initWithType:(OCDiagnosticNodeType)type
{
	if ((self = [super init]) != nil)
	{
		_type = type;
	}

	return (self);
}

- (BOOL)isEmpty
{
	switch (_type)
	{
		case OCDiagnosticNodeTypeInfo:
			return (_content == nil);
		break;

		case OCDiagnosticNodeTypeGroup:
			return (_children.count == 0);
		break;

		case OCDiagnosticNodeTypeAction:
			return (_action == nil);
		break;
	}

	return (NO);
}

- (instancetype)withIdentifier:(OCDiagnosticNodeIdentifier)identifier
{
	self.identifier = identifier;

	return (self);
}

- (nullable NSString *)_composeMarkdownWithLevel:(NSUInteger)level
{
	if (_type != OCDiagnosticNodeTypeGroup) { return(nil); }

	NSMutableString *markdown = [NSMutableString new];

	NSString *(^htmlify)(NSString *) = ^(NSString *text) {
		return ([[text stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"] stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"]);
	};

	if (level == 1)
	{
		[markdown appendFormat:@"%@ %@\n", [@"" stringByPaddingToLength:level withString:@"#" startingAtIndex:0], htmlify(self.label)];
	}
	[markdown appendFormat:@"<table>\n"];

	for (OCDiagnosticNode *node in _children)
	{
		if (!node.isEmpty)
		{
			switch (node.type)
			{
				case OCDiagnosticNodeTypeInfo:
					[markdown appendFormat:@"<tr><td nowrap valign=\"top\">%@</td><td><code>%@</code></td></tr>\n", htmlify(node.label), htmlify(node.content)];
				break;

				case OCDiagnosticNodeTypeAction:
				break;

				case OCDiagnosticNodeTypeGroup:
					[markdown appendFormat:@"<tr><td nowrap valign=\"top\">%@</td><td>\n%@\n</td></tr>\n", htmlify(node.label), [node _composeMarkdownWithLevel:level+1]];
				break;
			}
		}
	}

	[markdown appendFormat:@"</table>\n"];

	return (markdown);
}

- (nullable NSString *)composeMarkdown
{
	return ([self _composeMarkdownWithLevel:1]);
}

@end
