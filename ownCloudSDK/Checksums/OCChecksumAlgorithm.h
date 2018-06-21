//
//  OCChecksumAlgorithm.h
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
#import "OCChecksum.h"

@interface OCChecksumAlgorithm : NSObject

#pragma mark - Registration and lookup
+ (OCChecksumAlgorithm *)algorithmForIdentifier:(OCChecksumAlgorithmIdentifier)identifier;
+ (void)registerAlgorithmClass:(Class)algorithm;

#pragma mark - Algorithm interface
@property(class,readonly,nonatomic) OCChecksumAlgorithmIdentifier identifier;

@property(class,readonly,nonatomic) dispatch_queue_t computationQueue;

- (void)computeChecksumForFileAtURL:(NSURL *)fileURL completionHandler:(OCChecksumComputationCompletionHandler)completionHandler;
- (void)verifyChecksum:(OCChecksum *)checksum forFileAtURL:(NSURL *)fileURL completionHandler:(OCChecksumVerificationCompletionHandler)completionHandler;

#pragma mark - Algorithm implementation
- (OCChecksum *)computeChecksumForInputStream:(NSInputStream *)inputStream error:(NSError **)error;

@end

#define OCChecksumAlgorithmAutoRegister	+(void)load{ \
						[OCChecksumAlgorithm registerAlgorithmClass:self]; \
				       	}
