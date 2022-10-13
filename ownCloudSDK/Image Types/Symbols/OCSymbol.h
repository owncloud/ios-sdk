//
//  OCSymbol.h
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

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCSymbolName; //!< Name of a symbol to load. Abstraction through OCSymbol allows to add caching (if necessary) and customization options (such as weight, color, or rendering bundled sources) in a single string later on.

@interface OCSymbol : NSObject

+ (nullable UIImage *)iconForSymbolName:(nullable OCSymbolName)symbolName;

@end

NS_ASSUME_NONNULL_END
