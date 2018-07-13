//
//  OCMockTestClass+OCMocking.h
//  ownCloudMockingTests
//
//  Created by Felix Schwarz on 11.07.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "OCMockTestClass.h"
#import "OCMockManager.h"

@interface OCMockTestClass (OCMocking)

+ (BOOL)ocm_returnsTrue;

- (BOOL)ocm_returnsFalse;

@end

typedef BOOL(^OCMockMockTestClassReturnsTrueBlock)(void);
extern OCMockLocation OCMockLocationMockTestClassReturnsTrue;

typedef BOOL(^OCMockMockTestClassReturnsFalseBlock)(void);
extern OCMockLocation OCMockLocationMockTestClassReturnsFalse;
