//
//  OCServerLocator.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 08.11.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2021, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>
#import "OCExtension.h"
#import "OCConnection.h"
#import "OCHTTPRequest.h"

typedef NSString* OCServerLocatorIdentifier NS_TYPED_EXTENSIBLE_ENUM;
typedef NSError *_Nullable (^OCServerLocatorRequestSender)(OCHTTPRequest *_Nonnull request);

NS_ASSUME_NONNULL_BEGIN

@interface OCServerLocator : NSObject <OCClassSettingsSupport>

#pragma mark - Locator retrieval
@property(class,nonatomic,readonly,strong,nullable) OCServerLocatorIdentifier useServerLocatorIdentifier;
+ (nullable OCServerLocator *)serverLocatorForIdentifier:(nullable OCServerLocatorIdentifier)useLocatorIdentifier;

#pragma mark - Properties
@property(strong,nullable) NSURL *url;
@property(strong,nullable) NSString *userName;

@property(strong,nullable) NSDictionary<OCConnectionSetupOptionKey, id> *options;

@property(copy) OCServerLocatorRequestSender requestSender;

- (NSError * _Nullable)locate;

@end

extern OCExtensionType OCExtensionTypeServerLocator;
extern OCClassSettingsIdentifier OCClassSettingsIdentifierServerLocator;
extern OCClassSettingsKey OCClassSettingsKeyServerLocatorUse;

NS_ASSUME_NONNULL_END
