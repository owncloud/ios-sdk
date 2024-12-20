//
//  OCCodeFile.m
//  ocapigen
//
//  Created by Felix Schwarz on 27.01.22.
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

#import "OCCodeFile.h"

@implementation OCCodeFile

- (instancetype)initWithURL:(NSURL *)url generator:(nonnull OCCodeGenerator *)generator
{
	if ((self = [super init]) != nil)
	{
		_url = url;
		_segments = [NSMutableArray new];
		_generator = generator;

		[self read];
	}

	return (self);
}

- (void)read
{
	NSError *error = nil;
	NSString *contents = [NSString stringWithContentsOfURL:_url encoding:NSUTF8StringEncoding error:&error];

	NSArray<NSString *> *lines = [contents componentsSeparatedByString:[NSString stringWithFormat:@"\n"]];
	OCCodeFileSegment *segment = [[OCCodeFileSegment alloc] initWithAttributeHeaderLine:nil name:OCCodeFileSegmentNameLeadComment file:self generator:self.generator];

	[_segments addObject:segment];

	for (NSString *line in lines)
	{
		NSDictionary<OCCodeFileSegmentAttribute, id> *segmentHeaderAttributes;

		if ((segmentHeaderAttributes = [_generator decodeSegmentAttributesLine:line]) != nil)
		{
			if (![segmentHeaderAttributes[OCCodeFileSegmentAttributeName] isEqual:segment.name] || (segment.lines.count == 0))
			{
				[segment removeLastLineIfEmpty]; // remove extra trailing line

				segment = [[OCCodeFileSegment alloc] initWithAttributeHeaderLine:line name:segmentHeaderAttributes[OCCodeFileSegmentAttributeName] file:self generator:self.generator];
				[_segments addObject:segment];
			}
		}
		else
		{
			[segment _loadLine:line];
		}
	}
}

- (OCCodeFileSegment *)segmentForName:(OCCodeFileSegmentName)name
{
	return ([self segmentForName:name after:nil]);
}

- (OCCodeFileSegment *)segmentForName:(OCCodeFileSegmentName)name after:(OCCodeFileSegment *)afterSegment
{
	for (OCCodeFileSegment *segment in _segments)
	{
		if ([segment.name isEqual:name])
		{
			return (segment);
		}
	}

	OCCodeFileSegment *segment = [[OCCodeFileSegment alloc] initWithAttributeHeaderLine:nil name:name file:self generator:self.generator];
	segment.file = self;

	NSUInteger afterSegmentIdx = NSNotFound;

	if (afterSegment != nil)
	{
		afterSegmentIdx = [_segments indexOfObjectIdenticalTo:afterSegment];
	}

	if (afterSegmentIdx == NSNotFound)
	{
		[_segments addObject:segment];
	}
	else
	{
		[_segments insertObject:segment atIndex:afterSegmentIdx+1];
	}

	return (segment);
}

- (NSString *)composedFileContents
{
	NSMutableString *fileContents = [NSMutableString new];

	for (OCCodeFileSegment *segment in _segments)
	{
		if (segment.hasContent)
		{
			[fileContents appendFormat:@"%@\n", segment.composedSegment]; // add extra trailing line
		}
	}

	// Trim extraneous newlines from the end of the file
	while ([fileContents hasSuffix:@"\n\n"]) {
		[fileContents replaceCharactersInRange:NSMakeRange(fileContents.length-1, 1) withString:@""];
	}

	// Add one new line at the end
	[fileContents appendFormat:@"\n"];

	return (fileContents);
}

- (NSError *)write
{
	NSError *error=nil;

	[[self composedFileContents] writeToURL:_url atomically:YES encoding:NSUTF8StringEncoding error:&error];

	return (error);
}

@end
