//
//  OCCodeFileSegment.m
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

#import "OCCodeFileSegment.h"
#import "OCCodeGenerator.h"

@interface OCCodeFileSegment ()
{
	NSString *_attributeHeaderLine;
}
@end

@implementation OCCodeFileSegment

- (instancetype)initWithAttributeHeaderLine:(nullable NSString *)attributeHeaderLine name:(OCCodeFileSegmentName)name file:(OCCodeFile *)file generator:(OCCodeGenerator *)generator
{
	if ((self = [super init]) != nil)
	{
		_name = name;
		_file = file;
		_generator = generator;
		self.attributeHeaderLine = attributeHeaderLine;
		_lines = [NSMutableArray new];

		if (attributeHeaderLine == nil)
		{
			_attributes = @{
				OCCodeFileSegmentAttributeName : name
			};
		}
	}

	return (self);
}

- (NSString *)attributeHeaderLine
{
	if (_attributeHeaderLine != nil)
	{
		return (_attributeHeaderLine);
	}

	return ([_generator encodeSegmentAttributesLineFrom:self]);
}

- (void)setAttributeHeaderLine:(NSString *)attributeHeaderLine
{
	_attributeHeaderLine = attributeHeaderLine;
	self.attributes = [_generator decodeSegmentAttributesLine:attributeHeaderLine];
}

- (BOOL)locked
{
	return (OCTypedCast(self.attributes[OCCodeFileSegmentAttributeLocked], NSNumber).boolValue);
}

- (void)setLocked:(BOOL)locked
{
	[self setAttribute:OCCodeFileSegmentAttributeLocked to:(locked ? (__bridge id)kCFBooleanTrue : (__bridge id)kCFBooleanFalse)];
}

- (void)setAttribute:(OCCodeFileSegmentAttribute)attribute to:(id)value
{
	if (![_attributes[attribute] isEqual:value])
	{
		NSMutableDictionary<OCCodeFileSegmentAttribute, id> *mutableAttributes = [_attributes mutableCopy];
		mutableAttributes[attribute] = value;
		_attributes = mutableAttributes;

		_attributeHeaderLine = nil;
	}
}

- (void)addLine:(NSString *)line, ...
{
	// Read-only blocks
	if (self.locked)
	{
		return;
	}

	va_list args;

	va_start(args, line);
	NSString *formattedLine = [[NSString alloc] initWithFormat:line arguments:args];
	va_end(args);

	[_lines addObject:formattedLine];
}

- (void)_loadLine:(NSString *)line;
{
	// This method is only used for loading
	[_lines addObject:line];
}

- (instancetype)clear
{
	if (self.locked)
	{
		return (nil);
	}

	[_lines removeAllObjects];

	return (self);
}

- (void)removeLastLineIfEmpty
{
	if ([_lines.lastObject isEqual:@""])
	{
		[_lines removeLastObject];
	}
}

- (NSString *)composedSegment
{
	NSString *newLine = [NSString stringWithFormat:@"\n"];
	NSString *jointLines = [self.lines componentsJoinedByString:newLine];

	if ([self.name isEqual:OCCodeFileSegmentNameLeadComment] &&
	    ((self.attributes.count == 0) || ((self.attributes.count == 1) && (self.attributes[OCCodeFileSegmentAttributeName] != nil))))
	{
		// Allow non-use of attribute header line for Lead Comment at the beginning of the file
		return (jointLines);
	}

	if (![jointLines hasPrefix:newLine])
	{
		jointLines = [jointLines stringByAppendingString:newLine];
	}

	return ([NSString stringWithFormat:@"%@\n%@", self.attributeHeaderLine, jointLines]);
}

- (BOOL)hasContent
{
	return ((self.lines.count > 0) || // Lines in "body"
		((self.attributes.count > 1) || ((self.attributes.count == 1) && (self.attributes[OCCodeFileSegmentAttributeName] == nil)))); // Attributes other than name
}

@end

OCCodeFileSegmentAttribute OCCodeFileSegmentAttributeName = @"name";
OCCodeFileSegmentAttribute OCCodeFileSegmentAttributeLocked = @"locked";
OCCodeFileSegmentAttribute OCCodeFileSegmentAttributeCustomPropertyTypes = @"customPropertyTypes";
OCCodeFileSegmentAttribute OCCodeFileSegmentAttributeCustomPropertyNames = @"customPropertyNames";

OCCodeFileSegmentName OCCodeFileSegmentNameLeadComment = @"lead comment";
OCCodeFileSegmentName OCCodeFileSegmentNameIncludes = @"includes";
OCCodeFileSegmentName OCCodeFileSegmentNameForwardDeclarations = @"forward declarations";
OCCodeFileSegmentName OCCodeFileSegmentNameTypeLeadIn = @"type start";
OCCodeFileSegmentName OCCodeFileSegmentNameTypeSerialization = @"type serialization";
OCCodeFileSegmentName OCCodeFileSegmentNameTypeStructSerialization = @"struct serialization";
OCCodeFileSegmentName OCCodeFileSegmentNameTypeNativeSerialization = @"type native serialization";
OCCodeFileSegmentName OCCodeFileSegmentNameTypeNativeDeserialization = @"type native deserialization";
OCCodeFileSegmentName OCCodeFileSegmentNameTypeDebugDescription = @"type debug description";
OCCodeFileSegmentName OCCodeFileSegmentNameTypeProperties = @"type properties";
OCCodeFileSegmentName OCCodeFileSegmentNameTypeProtected = @"type protected";
OCCodeFileSegmentName OCCodeFileSegmentNameTypeLeadOut = @"type end";
