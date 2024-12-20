//
//  NSString+CamelCase.m
//  ocapigen
//
//  Created by Felix Schwarz on 28.11.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "NSString+GeneratorTools.h"

@implementation NSString (CamelCase)

- (NSString *)withCapitalizedFirstChar
{
	if (self.length > 0) {
		return ([[[self substringToIndex:1] uppercaseString] stringByAppendingString:[self substringFromIndex:1]]);
	}

	return (self);
}

- (nullable NSArray<NSString *> *)valuesFromArrayString
{
	NSString *elementsString = [self stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"[] "]];
	NSArray<NSString *> *rawValues = [elementsString componentsSeparatedByString:@","];
	NSMutableArray<NSString *> *values = [NSMutableArray new];

	for (NSString *rawEnumValue in rawValues) {
		NSString *enumValue = [rawEnumValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		[values addObject:enumValue];
	}
	return (values);
}

@end
