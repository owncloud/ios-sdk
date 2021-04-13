//
//  OCClaim.m
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

#import "OCClaim.h"
#import "OCProcessManager.h"
#import "OCCoreManager.h"

@implementation OCClaim

+ (instancetype)processClaimWithLockType:(OCClaimLockType)lockType
{
	return ([[self alloc] initWithProcessForLockType:lockType]);
}

+ (instancetype)explicitClaimWithIdentifier:(NSString *)identifier lockType:(OCClaimLockType)lockType
{
	return ([[self alloc] initWithExplicitIdentifier:identifier lockType:lockType]);
}

+ (instancetype)claimExpiringAtDate:(NSDate *)expiryDate withLockType:(OCClaimLockType)lockType
{
	return ([[self alloc] initWithExpiryDate:expiryDate lockType:lockType]);
}

+ (instancetype)claimForLifetimeOfCore:(OCCore *)core explicitIdentifier:(nullable OCClaimExplicitIdentifier)explicitIdentifier withLockType:(OCClaimLockType)lockType
{
	return ([[self alloc] initWithLifetimeOfCore:core explicitIdentifier:explicitIdentifier lockType:lockType]);
}

+ (instancetype)groupOfClaims:(NSArray<OCClaim *> *)groupClaims withOperator:(OCClaimGroupOperator)groupOperator
{
	return ([[self alloc] initWithGroupOfClaims:groupClaims withOperator:groupOperator]);
}

+ (instancetype)combining:(nullable OCClaim *)claim with:(nullable OCClaim *)otherClaim usingOperator:(OCClaimGroupOperator)groupRule
{
	if (claim == nil)
	{
		return (otherClaim);
	}
	else if (otherClaim == nil)
	{
		return (claim);
	}

	return ([claim combinedWithClaim:otherClaim usingOperator:groupRule]);
}

+ (instancetype)claimForProcessExpiringAtDate:(NSDate *)expiryDate withLockType:(OCClaimLockType)lockType
{
	return ([OCClaim combining:[OCClaim processClaimWithLockType:lockType] with:[OCClaim claimExpiringAtDate:expiryDate withLockType:lockType] usingOperator:OCClaimGroupOperatorAND]);
}

#pragma mark - Init & Dealloc
- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_identifier = [NSUUID UUID];
		_creationTimestamp = NSDate.timeIntervalSinceReferenceDate;
	}

	return(self);
}

- (instancetype)initWithProcessForLockType:(OCClaimLockType)typeOfLock
{
	if ((self = [self init]) != nil)
	{
		_type = OCClaimTypeProcess;
		_typeOfLock = typeOfLock;
		_processSession = OCProcessManager.sharedProcessManager.processSession;
	}

	return(self);
}

- (instancetype)initWithExplicitIdentifier:(NSString *)identifier lockType:(OCClaimLockType)lockType
{
	if ((self = [self init]) != nil)
	{
		_type = OCClaimTypeExplicit;
		_typeOfLock = lockType;
		_explicitIdentifier = identifier;
	}

	return(self);
}

- (instancetype)initWithExpiryDate:(NSDate *)expiryDate lockType:(OCClaimLockType)lockType
{
	if ((self = [self init]) != nil)
	{
		_type = OCClaimTypeExpires;
		_typeOfLock = lockType;
		_expiryDate = expiryDate;
	}

	return(self);
}

- (instancetype)initWithLifetimeOfCore:(OCCore *)core explicitIdentifier:(nullable OCClaimExplicitIdentifier)explicitIdentifier lockType:(OCClaimLockType)lockType
{
	if (!core.isManaged)
	{
		// Only OCCoreManager'd cores' coreRunIdentifiers can currently be checked by OCClaim, so if a core isn't managed, return a processClaim instead
		self = [self initWithProcessForLockType:lockType];
	}
	else
	{
		if ((self = [self init]) != nil)
		{
			_type = OCClaimTypeCoreLifetime;
			_typeOfLock = lockType;
			_coreRunIdentifier = core.runIdentifier;
			_processSession = OCProcessManager.sharedProcessManager.processSession;
		}
	}

	if (self != nil)
	{
		_explicitIdentifier = explicitIdentifier;
	}

	return(self);
}

- (instancetype)initWithGroupOfClaims:(NSArray<OCClaim *> *)groupClaims withOperator:(OCClaimGroupOperator)groupOperator
{
	if ((self = [self init]) != nil)
	{
		_type = OCClaimTypeGroup;
		_groupClaims = groupClaims;
		_groupOperator = groupOperator;
	}

	return(self);
}

#pragma mark - Validation
- (BOOL)isValid
{
	BOOL isValid = NO;

	switch (_type)
	{
		case OCClaimTypeProcess:
			isValid = [[OCProcessManager sharedProcessManager] isSessionValid:_processSession usingThoroughChecks:YES];
		break;

		case OCClaimTypeExpires:
			isValid = ([_expiryDate timeIntervalSinceNow] > 0);
		break;

		case OCClaimTypeExplicit:
			isValid = YES;
		break;

		case OCClaimTypeCoreLifetime:
			if ((isValid = [[OCProcessManager sharedProcessManager] isSessionValid:_processSession usingThoroughChecks:YES]) == YES)
			{
				if ([[[OCProcessManager sharedProcessManager] processSession].uuid isEqual:_processSession.uuid])
				{
					isValid = [OCCoreManager.sharedCoreManager.activeRunIdentifiers containsObject:_coreRunIdentifier];
				}
			}
		break;

		case OCClaimTypeGroup:
			switch (_groupOperator)
			{
				case OCClaimGroupOperatorAND:
					isValid = (_groupClaims.count > 0);

					for (OCClaim *claim in _groupClaims)
					{
						if (!claim.isValid)
						{
							isValid = NO;
							break;
						}
					}
				break;

				case OCClaimGroupOperatorOR:
					isValid = NO;

					for (OCClaim *claim in _groupClaims)
					{
						if (claim.isValid)
						{
							isValid = YES;
							break;
						}
					}
				break;
			}
		break;
	}

	if (_inverted)
	{
		isValid = !isValid;
	}

	return (isValid);
}

- (OCClaimLockType)lockType
{
	OCClaimLockType lockType = _typeOfLock;

	if (_type == OCClaimTypeGroup)
	{
		lockType = OCClaimLockTypeNone;

		for (OCClaim *claim in _groupClaims)
		{
			if (claim.isValid)
			{
				OCClaimLockType claimLockType = claim.lockType;

				if (claimLockType > lockType)
				{
					lockType = claimLockType;
				}
			}
		}
	}

	return (lockType);
}

#pragma mark - Operations
- (OCClaim *)combinedWithClaim:(OCClaim *)claim usingOperator:(OCClaimGroupOperator)groupOperator
{
	NSArray <OCClaim *> *claims = nil;

	if (_type == OCClaimTypeGroup)
	{
		claims = [self.groupClaims arrayByAddingObject:claim];
	}
	else
	{
		claims = @[self, claim];
	}

	return ([[OCClaim alloc] initWithGroupOfClaims:claims withOperator:groupOperator]);
}

- (nullable OCClaim *)_removingClaimMatching:(BOOL(^)(OCClaim *matchClaim))claimMatcher
{
	return ([self _removingClaimsMatching:claimMatcher stopAfterFirstMatch:YES]);
}

- (nullable OCClaim *)_removingClaimsMatching:(BOOL(^)(OCClaim *matchClaim))claimMatcher stopAfterFirstMatch:(BOOL)stopAfterFirstMatch
{
	if (claimMatcher(self))
	{
		return (nil);
	}
	else if (_type == OCClaimTypeGroup)
	{
		NSMutableArray *filteredClaims = nil;

		for (OCClaim *claim in _groupClaims)
		{
			if (claimMatcher(claim))
			{
				if (filteredClaims == nil)
				{
					filteredClaims = [_groupClaims mutableCopy];
				}

				[filteredClaims removeObject:claim];

				if (stopAfterFirstMatch) { break; }
			}
		}

		if (filteredClaims != nil)
		{
			if (filteredClaims.count == 0)
			{
				return (nil);
			}
			else
			{
				return ([[OCClaim alloc] initWithGroupOfClaims:filteredClaims withOperator:_groupOperator]);
			}
		}
	}

	return (self);
}


- (nullable OCClaim *)removingClaimWithIdentifier:(OCClaimIdentifier)claimIdentifier
{
	return ([self _removingClaimMatching:^BOOL(OCClaim *matchClaim) {
		return ([matchClaim.identifier isEqual:claimIdentifier]);
	}]);
}

- (nullable OCClaim *)removingClaimsWithExplicitIdentifier:(OCClaimExplicitIdentifier)explicitIdentifier
{
	return ([self _removingClaimsMatching:^BOOL(OCClaim *matchClaim) {
		return ([matchClaim.explicitIdentifier isEqual:explicitIdentifier]);
	} stopAfterFirstMatch:NO]);
}

- (nullable OCClaim *)cleanedUpClaim
{
	if (!self.isValid)
	{
		// Claim is invalid
		return (nil);
	}
	else
	{
		// Drop all invalid claims from Group[OR] claims
		if ((_type == OCClaimTypeGroup) && (_groupOperator == OCClaimGroupOperatorOR))
		{
			return ([self _removingClaimsMatching:^BOOL(OCClaim *matchClaim) {
				return (!matchClaim.isValid);
			} stopAfterFirstMatch:NO]);
		}
	}

	return (self);
}

#pragma mark - Secure Coding
+ (BOOL)supportsSecureCoding
{
	return (YES);
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]) != nil)
	{
		_type = (OCClaimType)[decoder decodeIntegerForKey:@"type"];

		_typeOfLock = (OCClaimLockType)[decoder decodeIntegerForKey:@"lockType"];

		_identifier = [decoder decodeObjectOfClass:[NSUUID class] forKey:@"identifier"];

		_creationTimestamp = [decoder decodeDoubleForKey:@"creationTimestamp"];

		_processSession = [decoder decodeObjectOfClass:[OCProcessSession class] forKey:@"processSession"];

		_explicitIdentifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"explicitIdentifier"];

		_expiryDate = [decoder decodeObjectOfClass:[NSDate class] forKey:@"expiryDate"];

		_coreRunIdentifier = [decoder decodeObjectOfClass:[NSUUID class] forKey:@"coreRunIdentifier"];

		_groupOperator = [decoder decodeIntegerForKey:@"groupOperator"];
		_groupClaims = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:NSArray.class, OCClaim.class, nil] forKey:@"groupClaims"];
	}

	return (self);
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:_type forKey:@"type"];

	[coder encodeInteger:_typeOfLock forKey:@"lockType"];

	[coder encodeObject:_identifier forKey:@"identifier"];

	[coder encodeDouble:_creationTimestamp forKey:@"creationTimestamp"];

	[coder encodeObject:_processSession forKey:@"processSession"];

	[coder encodeObject:_explicitIdentifier forKey:@"explicitIdentifier"];

	[coder encodeObject:_expiryDate forKey:@"expiryDate"];

	[coder encodeObject:_coreRunIdentifier forKey:@"coreRunIdentifier"];

	[coder encodeInteger:_groupOperator forKey:@"groupOperator"];
	[coder encodeObject:_groupClaims forKey:@"groupClaims"];
}

#pragma mark - Description
- (NSString *)description
{
	NSString *typeString = nil;
	NSString *typeDescription = nil;

	switch (_type)
	{
		case OCClaimTypeProcess:
			typeString = @"process";
			typeDescription = [NSString stringWithFormat:@", process: %@", _processSession];
		break;

		case OCClaimTypeExpires:
			typeString = @"expires";
			typeDescription = [NSString stringWithFormat:@", expires: %@", _expiryDate];
		break;

		case OCClaimTypeExplicit:
			typeString = @"explicit";
			typeDescription = [NSString stringWithFormat:@", explicitIdentifier: %@", _explicitIdentifier];
		break;

		case OCClaimTypeCoreLifetime:
			typeString = @"coreLifetime";
			typeDescription = [NSString stringWithFormat:@", coreRunIdentifier: %@, process: %@", _coreRunIdentifier, _processSession];
		break;

		case OCClaimTypeGroup:
			switch(_groupOperator)
			{
				case OCClaimGroupOperatorAND:
					typeString = @"group";
					typeDescription = [NSString stringWithFormat:@", AND-claims: %@", _groupClaims];
				break;

				case OCClaimGroupOperatorOR:
					typeString = @"group";
					typeDescription = [NSString stringWithFormat:@", OR-claims: %@", _groupClaims];
				break;
			}
		break;
	}

	return ([NSString stringWithFormat:@"<%@: %p, identifier: %@, type: %@, valid: %d, lockType:%lu%@>", NSStringFromClass(self.class), self, _identifier, typeString, self.isValid, (unsigned long)self.lockType, typeDescription]);
}

@end
