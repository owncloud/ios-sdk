//
//  ownCloudMocking.h
//  ownCloudMocking
//
//  Created by Felix Schwarz on 11.07.18.
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

#import <UIKit/UIKit.h>

//! Project version number for ownCloudMocking.
FOUNDATION_EXPORT double ownCloudMockingVersionNumber;

//! Project version string for ownCloudMocking.
FOUNDATION_EXPORT const unsigned char ownCloudMockingVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <ownCloudMocking/PublicHeader.h>
#import <ownCloudMocking/OCHostSimulator.h>
#import <ownCloudMocking/OCHostSimulatorResponse.h>

#import <ownCloudMocking/OCMockManager.h>
#import <ownCloudMocking/NSObject+OCMockManager.h>

#import <ownCloudMocking/OCAuthenticationMethod+OCMocking.h>
#import <ownCloudMocking/OCAuthenticationMethodBasicAuth+OCMocking.h>
#import <ownCloudMocking/OCMockTestClass.h>
#import <ownCloudMocking/OCMockTestClass+OCMocking.h>
#import <ownCloudMocking/OCConnection+OCMocking.h>
#import <ownCloudMocking/OCCoreManager+OCMocking.h>
#import <ownCloudMocking/OCQuery+OCMocking.h>
