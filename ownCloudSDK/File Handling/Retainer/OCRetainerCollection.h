//
//  OCRetainerCollection.h
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
#import "OCRetainer.h"

@interface OCRetainerCollection : NSObject <NSSecureCoding>
{
	NSMutableArray <OCRetainer *> *_retainers;
}

@property(readonly,nonatomic) BOOL isRetaining;

- (void)addRetainer:(OCRetainer *)retainer;

- (void)removeRetainer:(OCRetainer *)retainer;
- (void)removeRetainerWithUUID:(NSUUID *)uuid;
- (void)removeRetainerWithExplicitIdentifier:(NSString *)explicitIdentifier;

@end
