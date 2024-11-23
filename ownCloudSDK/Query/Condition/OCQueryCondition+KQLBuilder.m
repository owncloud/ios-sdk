//
//  OCQueryCondition+KQLBuilder.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 19.11.24.
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

#import "OCQueryCondition+KQLBuilder.h"
#import "OCLogger.h"
#import "OCMacros.h"
#import "NSString+OCSQLTools.h"

@interface NSString (KQLTools)
@end

@implementation NSString (KQLTools)

- (NSString *)stringByKQLEscaping
{
	return ([NSString stringWithFormat:@"\"%@\"", [self stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]]);
}

@end

@interface NSDate (KQLTools)
@end

@implementation NSDate (KQLTools)

- (NSString *)kqlRFC3339DateString
{
	NSDateFormatter *rfc3339DateFormatter;
	NSString *str;

	rfc3339DateFormatter = [[NSDateFormatter alloc] init];
	rfc3339DateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
	rfc3339DateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
	rfc3339DateFormatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZ";

	str = [rfc3339DateFormatter stringFromDate:self];

	/*
		Unfortunately, NSDateFormatter produces "0000" instead of "00:00" for time zones, mismatching what is otherwise widely used
		and failing conversion by golang's time.Parse(time.RFC3339, ..). We therefore have to account for this for as long as it is
		that way and insert ":" in the timezone part *if needed* ("2024-11-17T23:00:00+0000" => "2024-11-17T23:00:00+00:00")
		to be compatible with golang's time.RFC3339
		(as used in https://github.com/owncloud/ocis/blob/cff364c998355b1295793e9244e5efdfea064536/services/search/pkg/engine/bleve.go#L225)

		This can be verified with this golang snippet:
			package main

			import (
				"fmt"
				"time"
			)

			func main() {
				tOk, err := time.Parse(time.RFC3339, "2024-11-17T23:00:00+01:00")
				fmt.Printf("parsed as: %v (error: %v)\n", tOk, err)

				tFail, err := time.Parse(time.RFC3339, "2024-11-17T23:00:00+0100")
				fmt.Printf("parsed as: %v (error: %v)\n", tFail, err)
			}

		produces:
			parsed as: 2024-11-17 23:00:00 +0100 +0100 (error: <nil>)
			parsed as: 0001-01-01 00:00:00 +0000 UTC (error: parsing time "2024-11-17T23:00:00+0100" as "2006-01-02T15:04:05Z07:00": cannot parse "+0100" as "Z07:00")
	*/
	NSRange timezoneDelimiterPosition = [str rangeOfString:@"+" options:NSBackwardsSearch];
	if (timezoneDelimiterPosition.location == (str.length-5)) { // No ":" separating the timezone hours and minutes => add it
		str = [NSString stringWithFormat:@"%@:%@", [str substringToIndex:str.length-2], [str substringFromIndex:str.length-2]];
	}

	return (str);
}

@end

@implementation OCQueryCondition (KQLBuilder)

- (OCKQLString)kqlStringWithTypeAliasToKQLTypeMap:(NSDictionary<NSString *, NSString *> *)typeAliasToKQLTypeMap targetContent:(OCKQLSearchedContent)targetContent
{
	// Mappings as per as per https://github.com/owncloud/ocis/blob/21893235442194f790f8c369f3b695eba79a43b9/services/search/pkg/query/bleve/compiler.go#L13
	NSString *kqlString = [self _kqlStringWithColumnNameMap:@{
		OCItemPropertyNameName: 	@"name",
		OCItemPropertyNameLastModified: @"mtime",
		OCItemPropertyNameLastUsed:     @"mtime",     // not an exact match, but closest possible
		OCItemPropertyNameMIMEType: 	@"mediatype",
		OCItemPropertyNameTypeAlias:	@"mediatype", // conversion from local typeAlias to server-side alias taking place via typeAliasToKQLTypeMap
		OCItemPropertyNameType:		@"mediatype", // conversion from OCItemType taking place in -kqlStringWithColumnNameMap:typeAliasToKQLTypeMap:
		OCItemPropertyNameSize: 	@"size",
	} typeAliasToKQLTypeMap:typeAliasToKQLTypeMap targetContent:targetContent];

	return (kqlString);
}

- (NSString *)_convert:(id)obj smartQuote:(BOOL)smartQuote // smartQuote -> only quote types where it's possible and necessary, f.ex. don't quote numbers
{
	NSString *str = nil;

	if ([obj isKindOfClass:NSString.class]) {
		str = smartQuote ? [(NSString *)obj stringByKQLEscaping] : obj;
	}

	if ([obj isKindOfClass:NSNumber.class]) {
		str = ((NSNumber *)obj).stringValue;
	}

	if ([obj isKindOfClass:NSDate.class]) {
		str = ((NSDate *)obj).kqlRFC3339DateString;
	}

	return (str);
}

- (NSString *)_convertedValue
{
	return [self _convert:self.value smartQuote:YES];
}

- (OCKQLString)_kqlStringWithColumnNameMap:(NSDictionary<OCItemPropertyName, NSString *> *)propertyColumnNameMap typeAliasToKQLTypeMap:(NSDictionary<NSString *, NSString *> *)typeAliasToKQLTypeMap targetContent:(OCKQLSearchedContent)targetContent
{
	// Example "(name:"*ex*" OR content:"ex") AND mtime:last 30 days AND mediatype:("pdf" OR "presentation")"
	NSString *query = nil;
	NSString *kqlProperty = propertyColumnNameMap[self.property];
	NSString *unquotedValue = nil;
	NSString *smartQuotedValue = nil;

	if ([self.property isEqual:OCItemPropertyNameTypeAlias]) {
		// Convert type aliases to KQL types
		unquotedValue = typeAliasToKQLTypeMap[self.value];
	}

	if ([self.property isEqual:OCItemPropertyNameType]) {
		// Convert type to mime type
		if ([self.value isEqual:@(OCItemTypeFile)]) {
			unquotedValue = @"file";
		}
		if ([self.value isEqual:@(OCItemTypeCollection)]) {
			unquotedValue = @"folder";
		}
	}

	if (unquotedValue == nil) {
		// No pre-converted value -> use standard conversion
		unquotedValue = [self _convert:self.value smartQuote:NO];
		smartQuotedValue = [self _convert:self.value smartQuote:YES];
	} else if (smartQuotedValue == nil) {
		// No pre-quoted value -> use standard escaping
		smartQuotedValue = [unquotedValue stringByKQLEscaping];
	}

	switch (self.operator)
	{
		case OCQueryConditionOperatorPropertyGreaterThanValue:
			query = [[NSString alloc] initWithFormat:@"(%@>%@)", kqlProperty, smartQuotedValue];
		break;

		case OCQueryConditionOperatorPropertyLessThanValue:
			query = [[NSString alloc] initWithFormat:@"(%@<%@)", kqlProperty, smartQuotedValue];
		break;

		case OCQueryConditionOperatorPropertyEqualToValue:
			query = [[NSString alloc] initWithFormat:@"(%@:%@)", kqlProperty, smartQuotedValue];
		break;

		case OCQueryConditionOperatorPropertyNotEqualToValue:
			query = [[NSString alloc] initWithFormat:@"(%@<>%@)", kqlProperty, smartQuotedValue];
		break;

		case OCQueryConditionOperatorPropertyHasPrefix:
			query = [[NSString alloc] initWithFormat:@"(%@:%@)", kqlProperty, [[unquotedValue stringByAppendingString:@"*"] stringByKQLEscaping]];
		break;

		case OCQueryConditionOperatorPropertyHasSuffix:
			query = [[NSString alloc] initWithFormat:@"(%@:%@)", kqlProperty, [[@"*" stringByAppendingString:unquotedValue] stringByKQLEscaping]];
		break;

		case OCQueryConditionOperatorPropertyContains: {
			NSString *kqlValue = [[NSString stringWithFormat:@"*%@*", unquotedValue] stringByKQLEscaping];
			if ([self.property isEqual:OCItemPropertyNameName]) {
				if (targetContent & OCKQLSearchedContentItemName) {
					query = [[NSString alloc] initWithFormat:@"(name:%@)", kqlValue];
				}

				if (targetContent & OCKQLSearchedContentContents) {
					NSString *contentQuery = [[NSString alloc] initWithFormat:@"(content:%@)", kqlValue];

					if (query == nil) {
						query = contentQuery;
					} else {
						query = [NSString stringWithFormat:@"(%@ OR %@)", query, contentQuery];
					}
				}

				break;
			}
			query = [[NSString alloc] initWithFormat:@"(%@:%@)", kqlProperty, kqlValue];
		}
		break;

		case OCQueryConditionOperatorAnd:
		case OCQueryConditionOperatorOr: {
			NSArray <OCQueryCondition *> *conditions;

			if ((conditions = OCTypedCast(self.value, NSArray)) != nil)
			{
				NSMutableString *queryString = [NSMutableString new];
				NSString *operatorString = (self.operator == OCQueryConditionOperatorAnd) ? @"AND" : @"OR";

				if (conditions.count == 1)
				{
					// Simplify case where there is only one condition
					query = [conditions.firstObject _kqlStringWithColumnNameMap:propertyColumnNameMap typeAliasToKQLTypeMap:typeAliasToKQLTypeMap targetContent:targetContent];
				}
				else
				{
					for (OCQueryCondition *condition in conditions)
					{
						NSString *conditionQueryString = nil;

						if ((conditionQueryString = [condition _kqlStringWithColumnNameMap:propertyColumnNameMap typeAliasToKQLTypeMap:typeAliasToKQLTypeMap targetContent:targetContent]) != nil)
						{
							if (queryString.length > 0)
							{
								[queryString appendFormat:@" %@ %@", operatorString, conditionQueryString];
							}
							else
							{
								[queryString appendString:conditionQueryString];
							}
						}
					}

					query = [NSString stringWithFormat:@"(%@)", queryString];
				}
			}
			else
			{
				OCLogError(@"AND/OR condition value is not an array of conditions");
			}
		}
		break;

		case OCQueryConditionOperatorNegate: {
			OCQueryCondition *condition;

			if ((condition = OCTypedCast(self.value, OCQueryCondition)) != nil)
			{
				query = [NSString stringWithFormat:@"(NOT %@)", [condition _kqlStringWithColumnNameMap:propertyColumnNameMap typeAliasToKQLTypeMap:typeAliasToKQLTypeMap targetContent:targetContent]];
			}
			else
			{
				OCLogError(@"Negate condition value is not a condition");
			}
		}
		break;
	}

	// self.sortBy and self.maxResultCount are ignored for now

	return (query);
}

@end
