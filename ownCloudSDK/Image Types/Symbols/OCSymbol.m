//
//  OCSymbol.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 13.10.22.
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

#import "OCSymbol.h"

@implementation OCSymbol

+ (nullable UIImage *)iconForSymbolName:(OCSymbolName)symbolName
{
	if (symbolName == nil) { return (nil); }
	return ([[UIImage systemImageNamed:symbolName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]);
}

@end
