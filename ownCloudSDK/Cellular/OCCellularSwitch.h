//
//  OCCellularSwitch.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.05.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCCellularSwitchIdentifier NS_TYPED_ENUM;

@interface OCCellularSwitch : NSObject
{
	BOOL _allowed;
	NSUInteger _maximumTransferSize;
}

@property(readonly,strong) OCCellularSwitchIdentifier identifier; //!< Globally unique identifier of the cellular switch

@property(readonly,strong,nullable) NSString *localizedName;	//!< Localized name of the switch. If non-nil, can be presented in Settings.
@property(readonly,strong,nullable) NSString *prefsKey;		//!< Key to use to load/save changes to user defaults.

@property(assign,nonatomic) BOOL allowed; 		    //!< YES if cellular access is allowed for transfers depending on this switch. Defaults to YES.
@property(assign,nonatomic) NSUInteger maximumTransferSize; //!< If 0, transfers of any size are allowed. If > 0, a limit per request/response up to which cellular transfer is allowed; transfers above that limit aren't allowed.

- (instancetype)initWithIdentifier:(OCCellularSwitchIdentifier)identifier localizedName:(nullable NSString *)localizedName prefsKey:(nullable NSString *)prefsKey defaultValue:(BOOL)defaultAllowed maximumTransferSize:(NSUInteger)maximumTransferSize;

- (instancetype)initWithIdentifier:(OCCellularSwitchIdentifier)identifier localizedName:(nullable NSString *)localizedName defaultValue:(BOOL)defaultAllowed maximumTransferSize:(NSUInteger)maximumTransferSize; //!< Convenience initializer constructing the prefsKey from the identifier

- (BOOL)allowsTransferOfSize:(NSUInteger)transferSize; //!< Method to determine if a transfer of a given size is allowed via this cellular switch. In most cases, however, you'll want to use -[OCCellularManager cellularAccessAllowedFor:…] instead.

@end

extern OCCellularSwitchIdentifier OCCellularSwitchIdentifierMain; //!< Main switch controlling ALL cellular access + limits
extern OCCellularSwitchIdentifier OCCellularSwitchIdentifierAvailableOffline; //!< Switch controlling ALL available offline transfers

extern NSNotificationName OCCellularSwitchUpdatedNotification; //!< Notification that's posted whenever the parameters of a cellular switch have changed

NS_ASSUME_NONNULL_END
