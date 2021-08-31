//
//  OCClaim.h
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
#import "OCProcessSession.h"
#import "OCTypes.h"

typedef NS_ENUM(NSUInteger, OCClaimType)
{
	OCClaimTypeProcess,	//!< Temporary claim; automatically expires if the process adding the claim has been terminated.
	OCClaimTypeExpires,	//!< Time-limited claim; valid until a certain date.
	OCClaimTypeExplicit,	//!< Indefinite claim; valid until it's removed using the same explicitIdentifier.
	OCClaimTypeCoreLifetime,//!< Temporary claim; automatically expires if the process adding the claim has been terminated - or if the OCCore instance inside that process has been terminated (checkable only within the process adding it)
	OCClaimTypeGroup	//!< Claim determined by a group of other claims, combined with an operator
};

typedef NS_ENUM(NSUInteger, OCClaimLockType)
{
	OCClaimLockTypeNone,	//!< Not a lock

	OCClaimLockTypeDelete,	//!< Lock against deletion (for files: guarantee that *any* version of the file is available locally, updates allowed)
	OCClaimLockTypeRead,	//!< Lock against deletion and outdating (for files: guarantee that a version of the file is available locally, updates to latest version allowed and encouraged)
	OCClaimLockTypeWrite	//!< Lock against deletion, updates and writes (for files: guarantee that the existing, local version of the file is not updated or touched in any other way)
};

typedef NS_ENUM(NSUInteger, OCClaimGroupOperator)
{
	OCClaimGroupOperatorAND,//!< All claims in the group must be valid, otherwise the whole claim is invalid
	OCClaimGroupOperatorOR	//!< If any of the claims in the group is valid, the whole claim is valid
};

typedef NSUUID* OCClaimIdentifier;
typedef NSString* OCClaimExplicitIdentifier;

@class OCCore;

NS_ASSUME_NONNULL_BEGIN

@interface OCClaim : NSObject <NSSecureCoding>
{
	OCClaimLockType _typeOfLock;
}

#pragma mark - Metadata
@property(readonly,assign) OCClaimType type;	//!< The claim type
@property(readonly,assign,nonatomic) OCClaimLockType typeOfLock; //!< The level of locking the claim was put in place for (called typeOfLock because lockType seems to conflict with some Obj-C internals)
@property(readonly,strong) OCClaimIdentifier identifier; //!< The UUID of the claim (auto-generated on init)
@property(readonly,assign) NSTimeInterval creationTimestamp; //!< Timestamp of the creation of the claim

#pragma mark - Claim: process
@property(readonly,strong,nullable) OCProcessSession *processSession; //!< For OCClaimTypeProcess claims, the processSession this claim is tied to.

#pragma mark - Claim: explicit identifier
@property(readonly,strong,nullable) OCClaimExplicitIdentifier explicitIdentifier; //!< For OCClaimTypeExplicit claims, the explicit identifier of the claim.

#pragma mark - Claim: expiry date
@property(readonly,strong,nullable) NSDate *expiryDate; //!< For OCClaimTypeExpires claims, the date until which this claim is valid.

#pragma mark - Claim: core lifetime
@property(readonly,strong,nullable) OCCoreRunIdentifier coreRunIdentifier; //!< For OCClaimTypeCoreLifetime claims, the date until which this claim is valid.

#pragma mark - Claim: group
@property(readonly,assign) OCClaimGroupOperator groupOperator; //!< The operator to use to combine the claims in .groupClaims
@property(readonly,strong,nullable) NSArray<OCClaim *> *groupClaims; //!< The claims to group using .groupOperator

#pragma mark - Validation
@property(assign) BOOL inverted; //!< Inverts the validation result (YES -> NO, NO -> YES)
@property(readonly,nonatomic) BOOL isValid;

#pragma mark - Creation
+ (instancetype)processClaimWithLockType:(OCClaimLockType)lockType; //!< Temporary claim; automatically expires if the process adding the claim has been terminated.
+ (instancetype)explicitClaimWithIdentifier:(NSString *)identifier lockType:(OCClaimLockType)lockType; //!< Indefinite claim; valid until it's removed using the same explicitIdentifier.
+ (instancetype)claimExpiringAtDate:(NSDate *)expiryDate withLockType:(OCClaimLockType)lockType; //!< Time-limited claim; valid until a certain date.

+ (instancetype)claimForLifetimeOfCore:(OCCore *)core explicitIdentifier:(nullable OCClaimExplicitIdentifier)explicitIdentifier withLockType:(OCClaimLockType)lockType; //!< Temporary claim; automatically expires if the process adding the claim has been terminated - or if the OCCore instance inside that process has been terminated (checkable only within the process adding it). Allows adding an explicitIdentifier for simplified manual removal.

+ (instancetype)groupOfClaims:(NSArray<OCClaim *> *)groupClaims withOperator:(OCClaimGroupOperator)groupRule; //!< Creates a group claim whose validity is the result of checking the validity of the contained claims and combining them with the provided operator
+ (instancetype)combining:(nullable OCClaim *)claim with:(nullable OCClaim *)otherClaim usingOperator:(OCClaimGroupOperator)groupRule; //!< Creates a new claim representing the combination of up to two claims using an operator. Convenience method for handling nil claims.

+ (instancetype)claimForProcessExpiringAtDate:(NSDate *)expiryDate withLockType:(OCClaimLockType)lockType; //!< Time-limited claim; valid until the process adding the claim has been terminated or a certain date has passed, whatever comes first.

#pragma mark - Operations
- (OCClaim *)combinedWithClaim:(OCClaim *)claim usingOperator:(OCClaimGroupOperator)groupOperator; //!< Combines the receiving claim with another claim and returns a new claim
- (nullable OCClaim *)removingClaimWithIdentifier:(OCClaimIdentifier)claimIdentifier; //!< Removes a claim with the the provided claimID from the claim and returns a new claim - or nil if no claim is remaining
- (nullable OCClaim *)removingClaimsWithExplicitIdentifier:(OCClaimExplicitIdentifier)explicitIdentifier; //!< Removes all claims with the provided explicitIdentifier from the claim and returns a new claim - or nil if no claim is remaining

- (nullable OCClaim *)cleanedUpClaim; //!< Returns an OCClaim with all invalid claims removed: a) from groups using OR operator b) nil if the claim itself is invalid

- (nullable OCClaim *)claimWithFilter:(BOOL(^)(OCClaim *claim))claimFilter; //!< Returns the first matching claim. Is applied hierarchically.

@end

NS_ASSUME_NONNULL_END
