//
//  OCChecksum.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.06.18.
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

@class OCChecksum;

typedef NSString* OCChecksumHeaderString;
typedef NSString* OCChecksumAlgorithmIdentifier NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString* OCChecksumString;

typedef void(^OCChecksumComputationCompletionHandler)(NSError *error, OCChecksum *computedChecksum);
typedef void(^OCChecksumVerificationCompletionHandler)(NSError *error, BOOL isValid, OCChecksum *actualChecksum);

@interface OCChecksum : NSObject <NSSecureCoding>
{
	OCChecksumAlgorithmIdentifier _algorithmIdentifier;
	OCChecksumString _checksum;
	OCChecksumHeaderString _headerString;
}

@property(readonly,strong) OCChecksumAlgorithmIdentifier algorithmIdentifier;
@property(readonly,strong) OCChecksumString checksum;

@property(readonly,strong,nonatomic) OCChecksumHeaderString headerString;

+ (instancetype)checksumFromHeaderString:(OCChecksumHeaderString)headerString;

- (instancetype)initFromHeaderString:(OCChecksumHeaderString)headerString;
- (instancetype)initWithAlgorithmIdentifier:(OCChecksumAlgorithmIdentifier)algorithmIdentifier checksum:(OCChecksumString)checksum;

#pragma mark - Computations
+ (void)computeForFile:(NSURL *)fileURL checksumAlgorithm:(OCChecksumAlgorithmIdentifier)algorithmIdentifier completionHandler:(OCChecksumComputationCompletionHandler)completionHandler;
- (void)verifyForFile:(NSURL *)fileURL completionHandler:(OCChecksumVerificationCompletionHandler)completionHandler;

@end
