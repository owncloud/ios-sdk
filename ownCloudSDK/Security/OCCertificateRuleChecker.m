//
//  OCCertificateRuleChecker.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 12.04.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCCertificateRuleChecker.h"
#import "OCMacros.h"
#import "OCLogger.h"

@implementation OCCertificateRuleChecker

+ (instancetype)ruleWithCertificate:(OCCertificate *)certificate newCertificate:(OCCertificate *)newCertificate rule:(NSString *)rule
{
	OCCertificateRuleChecker *ruleChecker = [self new];

	ruleChecker.certificate = certificate;
	ruleChecker.otherCertificate = newCertificate;
	ruleChecker.rule = rule;

	return (ruleChecker);
}

#pragma mark - Evaluation
- (void)evaluateRuleWithCompletionHandler:(void(^)(BOOL passedCheck))completionHandler
{
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
		if ([self.rule isEqual:@"never"])
		{
			completionHandler(NO);
		}
		else
		{
			BOOL result = NO;

			@try {
				NSPredicate *predicate = [NSPredicate predicateWithFormat:self.rule, nil];
				result = [predicate evaluateWithObject:self];
			} @catch (NSException *exception) {
				OCLogError(@"evaluation of rule %@ threw an exception: %@", self.rule, exception);
			} @finally {
				completionHandler(result);
			}
		}
	});
}

- (BOOL)evaluateRule
{
	__block BOOL passedCheck = NO;

	OCSyncExec(evaluationDone, {
		[self evaluateRuleWithCompletionHandler:^(BOOL passed) {
			passedCheck = passed;

			OCSyncExecDone(evaluationDone);
		}];
	});

	return (passedCheck);
}

#pragma mark - Computed values
- (id)valueForKey:(NSString *)key
{
	// Protect against infinite recursion attack
	if ([key isEqual:@"evaluateRule"])
	{
		return (@(NO));
	}

	return ([super valueForKey:key]);
}

- (id)valueForUndefinedKey:(NSString *)key
{
	if ([key isEqualToString:@"bookmarkCertificate"])
	{
		return (_certificate);
	}

	if ([key isEqualToString:@"newCertificate"])
	{
		return (_otherCertificate);
	}

	if ([key isEqualToString:@"serverCertificate"])
	{
		return (_otherCertificate);
	}

	return ([super valueForUndefinedKey:key]);
}

- (instancetype)check
{
	// Returns self, to allow putting all computed values into their own namespace
	return (self);
}

- (BOOL)certificatesHaveIdenticalParents
{
	NSArray <OCCertificate *> *certificateChain = [self.certificate chainInReverse:NO];
	NSArray <OCCertificate *> *certificateNewChain = [self.otherCertificate chainInReverse:NO];

	if ((certificateChain != nil) && (certificateNewChain != nil) && (certificateChain.count > 1) && (certificateNewChain.count == certificateChain.count))
	{
		__block BOOL haveIdenticalParents = YES;

		[certificateChain enumerateObjectsUsingBlock:^(OCCertificate * _Nonnull certificate, NSUInteger idx, BOOL * _Nonnull stop) {
			if (idx != 0)
			{
				if (![certificate isEqual:certificateNewChain[idx]])
				{
					haveIdenticalParents = NO;
					*stop = YES;
				}
			}
		}];

		return (haveIdenticalParents);
	}

	return (NO);
}

- (BOOL)parentCertificatesHaveIdenticalPublicKeys
{
	NSArray <OCCertificate *> *certificateChain = [self.certificate chainInReverse:NO];
	NSArray <OCCertificate *> *certificateNewChain = [self.otherCertificate chainInReverse:NO];

	if ((certificateChain != nil) && (certificateNewChain != nil) && (certificateChain.count > 1) && (certificateNewChain.count == certificateChain.count))
	{
		__block BOOL haveParentsWithIdenticalPublicKeys = YES;

		[certificateChain enumerateObjectsUsingBlock:^(OCCertificate * _Nonnull certificate, NSUInteger idx, BOOL * _Nonnull stop) {
			if (idx != 0)
			{
				NSData *certificatePublicKeyData = certificate.publicKeyData;
				NSData *certificateNewPublicKeyData = certificateNewChain[idx].publicKeyData;

				if (![certificatePublicKeyData isEqual:certificateNewPublicKeyData])
				{
					haveParentsWithIdenticalPublicKeys = NO;
					*stop = YES;
				}
			}
		}];

		return (haveParentsWithIdenticalPublicKeys);
	}

	return (NO);
}

@end

@implementation OCCertificate (RuleChecker)

- (NSString *)validationResult
{
	__block NSString *validationResultString = @"none";

	OCSyncExec(validateCertificate, {
		[self evaluateWithCompletionHandler:^(OCCertificate * _Nonnull certificate, OCCertificateValidationResult validationResult, NSError * _Nonnull error) {
			switch (validationResult)
			{
				case OCCertificateValidationResultNone:
				break;

				case OCCertificateValidationResultError:
					validationResultString = @"error";
				break;

				case OCCertificateValidationResultReject:
					validationResultString = @"reject";
				break;

				case OCCertificateValidationResultPromptUser:
					validationResultString = @"promptUser";
				break;

				case OCCertificateValidationResultPassed:
					validationResultString = @"passed";
				break;

				case OCCertificateValidationResultUserAccepted:
					validationResultString = @"userAccepted";
				break;
			}

			OCSyncExecDone(validateCertificate);
		}];
	});

	return (validationResultString);
}

- (BOOL)passedValidationOrIsUserAccepted
{
	__block BOOL validatedOK = NO;

	OCSyncExec(validateCertificate, {
		[self evaluateWithCompletionHandler:^(OCCertificate * _Nonnull certificate, OCCertificateValidationResult validationResult, NSError * _Nonnull error) {
			validatedOK = ((validationResult == OCCertificateValidationResultPassed) || (validationResult == OCCertificateValidationResultUserAccepted));

			OCSyncExecDone(validateCertificate);
		}];
	});

	return (validatedOK);
}

- (NSData *)publicKeyData
{
	return ([self publicKeyDataWithError:NULL]);
}

@end
