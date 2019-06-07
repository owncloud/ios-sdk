//
//  OCPKCE.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 04.06.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCPKCECodeVerifier;
typedef NSString* OCPKCECodeChallenge;
typedef NSString* OCPKCEMethod NS_TYPED_ENUM;

@interface OCPKCE : NSObject

@property(nullable,strong,nonatomic) OCPKCECodeVerifier codeVerifier;
@property(nullable,strong,nonatomic) OCPKCEMethod method;
@property(nullable,strong,nonatomic,readonly) OCPKCECodeChallenge codeChallenge;

@end

extern OCPKCEMethod OCPKCEMethodPlain;
extern OCPKCEMethod OCPKCEMethodS256;

NS_ASSUME_NONNULL_END
