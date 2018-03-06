//
//  OCMacros.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 03.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#ifndef OCMacros_h
#define OCMacros_h

#define OCLocalizedString(key,comment) NSLocalizedStringFromTableInBundle(key, @"Localized", [NSBundle bundleForClass:[self class]], comment)

#endif /* OCMacros_h */
