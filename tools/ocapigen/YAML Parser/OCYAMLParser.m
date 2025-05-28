//
//  OCYAMLParser.m
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

#import "OCYAMLParser.h"
#import "OCYAMLNode.h"

@interface OCYAMLParser ()
{
	NSMutableArray<NSString *> *_lines;
	NSMutableArray<OCYAMLNode *> *_nodeStack;

	NSMutableArray<OCYAMLNode *> *_resultNodes;
}

@end

@implementation OCYAMLParser

- (instancetype)initWithFileContents:(NSString *)yamlFileContents
{
	if ((self = [super init]) != nil)
	{
		// Split into lines
		_lines = [[yamlFileContents componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet] mutableCopy];

		// Remove empty lines
		[_lines removeObject:@""];

		// Node stack
		_nodeStack = NSMutableArray.new;
		_resultNodes = NSMutableArray.new;
	}

	return (self);
}

- (void)parse
{
	NSCharacterSet *whitespaceCharSet = NSCharacterSet.whitespaceCharacterSet;

	for (NSString *line in _lines)
	{
		NSUInteger lineLength = line.length;
		NSUInteger lineIndentLevel = 0;

		// Determine level of indentation
		for (NSUInteger idx=0; idx < lineLength; idx++)
		{
			NSString *idxChar = [line substringWithRange:NSMakeRange(idx, 1)];

			if ([idxChar isEqual:@" "])
			{
				lineIndentLevel++;
			}
			else
			{
				break;
			}
		}

		// Extract line content
		NSString *lineContent = [line substringFromIndex:lineIndentLevel];

		// Skip comments and empty contents
		if ([lineContent hasPrefix:@"#"] ||
		    [lineContent isEqual:@""])
		{
			continue;
		}

		// Handle lists
		if ([lineContent hasPrefix:@"-"])
		{
			OCYAMLNode *lastNode;

			if ((lastNode = _nodeStack.lastObject) != nil)
			{
				if (lineIndentLevel > lastNode.indentLevel)
				{
					NSMutableArray<NSString *> *listArray = nil;

					if (lastNode.value == nil)
					{
						listArray = NSMutableArray.new;
						lastNode.value = listArray;
					}
					else
					{
						if ([lastNode.value isKindOfClass:NSMutableArray.class])
						{
							listArray = lastNode.value;
						}
					}

					NSString *listLineContent = [[lineContent substringFromIndex:1] stringByTrimmingCharactersInSet:whitespaceCharSet];

					if (![listLineContent isEqual:@""])
					{
						[listArray addObject:listLineContent];
					}

					continue;
				}
			}
		}

		// Split contents
		NSRange splitPoint = [lineContent rangeOfString:@":"];

		if (splitPoint.location == NSNotFound)
		{
			NSLog(@"Skipping %@", lineContent);
			continue;
		}

		NSString *name = [lineContent substringToIndex:splitPoint.location];
		NSString *value = [[lineContent substringFromIndex:splitPoint.location+1] stringByTrimmingCharactersInSet:whitespaceCharSet];

		// Sanitize name
		if ([name hasPrefix:@"'"] && [name hasSuffix:@"'"] && (name.length > 1))
		{
			// Remove ''
			name = [name substringWithRange:NSMakeRange(1, name.length-2)];
		}
		if ([name hasPrefix:@"\""] && [name hasSuffix:@"\""] && (name.length > 1))
		{
			// Remove ''
			name = [name substringWithRange:NSMakeRange(1, name.length-2)];
		}

		// Sanitize value
		if ([value isEqual:@""]) { value = nil; }

		if ([value hasPrefix:@"'"] && [value hasSuffix:@"'"] && (value.length > 1))
		{
			// Remove ''
			value = [value substringWithRange:NSMakeRange(1, value.length-2)];
		}
		if ([value hasPrefix:@"\""] && [value hasSuffix:@"\""] && (value.length > 1))
		{
			// Remove ''
			value = [value substringWithRange:NSMakeRange(1, value.length-2)];
		}

		// Create node for line
		OCYAMLNode *node = [[OCYAMLNode alloc] initWithName:name value:value];
		node.indentLevel = lineIndentLevel;

		// Remove nodes from stack with higher or same indent level
		while ((_nodeStack.count > 0) && (_nodeStack.lastObject.indentLevel >= lineIndentLevel))
		{
			[_nodeStack removeLastObject];
		};

		// Add to parent node
		OCYAMLNode *parentNode = _nodeStack.lastObject;

		if (parentNode == nil)
		{
			[_resultNodes addObject:node];
		}
		else
		{
			[parentNode addChild:node];
		}

		// Push node onto stack
		[_nodeStack addObject:node];
	}
}

- (OCYAMLNode *)nodeForPath:(OCYAMLPath)path
{
	if ([path hasPrefix:@"#"]) {
		path = [path substringFromIndex:1];
	}

	if ([path hasPrefix:@"/"]) {
		path = [path substringFromIndex:1];
	} else {
		// No relative path support
		return (nil);
	}

	NSArray<NSString *> *segments = [path componentsSeparatedByString:@"/"];

	OCYAMLNode *node = nil;

	for (NSString *segName in segments)
	{
		if (node == nil)
		{
			for (OCYAMLNode *rootNode in _resultNodes)
			{
				if ([rootNode.name isEqual:segName])
				{
					node = rootNode;
					break;
				}
			}

			if (node != nil) { continue; }

			break;
		}

		if (node.childrenByName[segName] != nil)
		{
			node = node.childrenByName[segName];
		}
	}

	return (node);
}

- (OCYAMLNode *)nodeForReference:(OCYAMLReference)reference
{
	if (![reference hasPrefix:@"$ref:"]) {
		// Not a reference
		return (nil);
	}

	OCYAMLPath path = [reference substringFromIndex:5];
	path = [path stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\"' 	"]];

	if (path.length == 0)
	{
		return nil;
	}

	return ([self nodeForPath:path]);
}

@end
