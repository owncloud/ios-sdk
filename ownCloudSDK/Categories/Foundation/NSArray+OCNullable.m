//
//  NSArray+OCNullable.m
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

#import "NSArray+OCNullable.h"
#import "OCDiagnosticNode.h"
#import "OCMacros.h"

@implementation NSArray (OCNullable)

- (NSArray *)arrayByRemovingNullEntries
{
	Class nullClass = NSNull.class;

	return ([self filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
		OCDiagnosticNode *node = OCTypedCast(evaluatedObject, OCDiagnosticNode);

		return (![evaluatedObject isKindOfClass:nullClass] && ((node==nil) || ((node != nil) && !node.isEmpty)));
	}]]);
}

@end
