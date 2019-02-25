//
//  OCProxyProgress.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 21.02.19.
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

#import <objc/runtime.h>

#import "OCProxyProgress.h"

static NSString *sProxyProgressObserver = @"OCProxyProgress";

#define CLONE_GRANULARITY ((int64_t)100000)

@interface OCProxyProgress ()
{
	NSProgress *_strongClonedProgress;
}

@end

@implementation OCProxyProgress

+ (NSProgress *)cloneProgress:(NSProgress *)progress
{
	OCProxyProgress *proxyProgress = [[self alloc] initWithProgress:progress]; // Setup, wherein proxyProgress becomes a strongly associated object of .clonedProgress

	NSProgress *clonedProgress = proxyProgress.clonedProgress; // Get cloned progress and retain a strong reference on the stack

	proxyProgress->_strongClonedProgress = nil; // Remove strong reference to clonedProgress held by proxyProgress

	return (clonedProgress);
}

#pragma mark - Init & Dealloc
- (instancetype)initWithProgress:(NSProgress *)progress
{
	if ((self = [super init]) != nil)
	{
		_observedProgress = progress;
		_strongClonedProgress = [NSProgress progressWithTotalUnitCount:CLONE_GRANULARITY];
		_clonedProgress = _strongClonedProgress;
		_clonedProgress.cancellationHandler = ^{
			[progress cancel];
		};
		_clonedProgress.pausingHandler = ^{
			[progress pause];
		};
		_clonedProgress.resumingHandler = ^{
			[progress resume];
		};

		objc_setAssociatedObject(_strongClonedProgress, (__bridge void *)sProxyProgressObserver, self, OBJC_ASSOCIATION_RETAIN);

		[self _addObservers];
	}

	return (self);
}

- (void)dealloc
{
	[self _removeObservers];
}

#pragma mark - Add/Remove observers
- (NSArray <NSString *> *)_observedKeyPaths
{
	return (@[ @"totalUnitCount", @"completedUnitCount", @"fractionCompleted", @"indeterminate", @"localizedDescription", @"localizedAdditionalDescription", @"cancellable", @"cancelled", ]);
}

- (void)_addObservers
{
	NSProgress *progress;

	if ((progress = self.observedProgress) != nil)
	{
		for (NSString *keyPath in [self _observedKeyPaths])
		{
			[progress addObserver:self forKeyPath:keyPath options:NSKeyValueObservingOptionInitial context:(__bridge void *)sProxyProgressObserver];
		}
	}
}

- (void)_removeObservers
{
	NSProgress *progress;

	if ((progress = self.observedProgress) != nil)
	{
		for (NSString *keyPath in [self _observedKeyPaths])
		{
			[progress removeObserver:self forKeyPath:keyPath context:(__bridge void *)sProxyProgressObserver];
		}
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
	if (context == (__bridge void *)sProxyProgressObserver)
	{
		if (_observedProgress.isIndeterminate)
		{
			_clonedProgress.completedUnitCount = 0;
			_clonedProgress.totalUnitCount = 0;
		}
		else
		{
			_clonedProgress.totalUnitCount = CLONE_GRANULARITY;
			_clonedProgress.completedUnitCount = (int64_t) (_observedProgress.fractionCompleted * ((double)CLONE_GRANULARITY));
		}

		if ([keyPath isEqualToString:@"cancelled"])
		{
			if (!_clonedProgress.cancelled && _observedProgress.cancelled)
			{
				_clonedProgress.cancellationHandler = nil;
				[_clonedProgress cancel];
			}
		}

		if ([keyPath isEqualToString:@"cancellable"] ||
		    [keyPath isEqualToString:@"localizedDescription"] ||
		    [keyPath isEqualToString:@"localizedAdditionalDescription"])
		{
			[_clonedProgress setValue:[_observedProgress valueForKeyPath:keyPath] forKeyPath:keyPath];
		}
		return;
	}

	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

@end
