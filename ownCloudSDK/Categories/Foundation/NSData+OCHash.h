//
//  NSData+OCHash.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 28.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

@interface NSData (OCHash)

- (NSData *)md5Hash;
- (NSData *)sha1Hash;
- (NSData *)sha256Hash;

- (NSString *)asHexStringWithSeparator:(NSString *)separator;
- (NSString *)asHexStringWithSeparator:(NSString *)separator lowercase:(BOOL)lowercase;

- (NSString *)asFingerPrintString;

@end

