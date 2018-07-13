//
//  OCRetainerCollection.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.06.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

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
