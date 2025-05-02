//
//  NSError+OCChecksum.h
//  ownCloudSDK
//
//  Created by Matthias Hühne on 30.04.25.
//  Copyright © 2025 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2025, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OCChecksumErrorCode)
{
    OCChecksumErrorCodeEVPMDCTXFailed = 1,
    OCChecksumErrorCodeEVPDIGESTINITEX
};

extern NSErrorDomain OCChecksumErrorDomain;

NS_ASSUME_NONNULL_END
