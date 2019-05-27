//
//  OCRecipientSearchController.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 13.03.19.
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

#import "OCRecipientSearchController.h"
#import "OCRateLimiter.h"
#import "OCCore+Internal.h"
#import "OCMacros.h"

@interface OCRecipientSearchController ()
{
	OCRateLimiter *_rateLimiter;
	OCItemType _itemType;
	NSUInteger _activeRetrievalCounter;

	NSUInteger _lastSearchID;
	NSUInteger _searchIDCounter;
}

@end

@implementation OCRecipientSearchController

- (instancetype)initWithCore:(OCCore *)core item:(nonnull OCItem *)item
{
	if ((self = [self init]) != nil)
	{
		_core = core;

		_itemType = item.type;
		_rateLimiter = [[OCRateLimiter alloc] initWithMinimumTime:0.5];
		_maximumResultCount = 50;
	}

	return (self);
}

- (void)setSearchTerm:(NSString *)searchTerm
{
	if (OCNANotEqual(searchTerm, _searchTerm))
	{
		_searchTerm = searchTerm;

		[self search];
	}
}

- (void)setShareTypes:(NSArray<OCShareTypeID> *)shareTypes
{
	_shareTypes = shareTypes;

	[self search];
}

- (void)setIsWaitingForResults:(BOOL)isWaitingForResults
{
	if (_isWaitingForResults != isWaitingForResults)
	{
		_isWaitingForResults = isWaitingForResults;

		if ((_delegate!=nil) && [_delegate respondsToSelector:@selector(searchController:isWaitingForResults:)])
		{
			[_delegate searchController:self isWaitingForResults:_isWaitingForResults];
		}
	}
}

- (void)search
{
	[_rateLimiter runRateLimitedBlock:^{
		[self _search];
	}];
}

- (void)_search
{
	OCCore *core;

	if ((core = _core) != nil)
	{
		NSUInteger searchID;

		@synchronized(self)
		{
			_activeRetrievalCounter++;

			if (_activeRetrievalCounter == 1)
			{
				self.isWaitingForResults = YES;
				[core beginActivity:@"Search for recipients"];
			}

			searchID = _searchIDCounter++;
		}

		[core.connection retrieveRecipientsForItemType:_itemType ofShareType:self.shareTypes searchTerm:self.searchTerm maximumNumberOfRecipients:self.maximumResultCount completionHandler:^(NSError * _Nullable error, NSArray<OCRecipient *> * _Nullable recipients) {
			@synchronized(self)
			{
				self->_activeRetrievalCounter--;

				if (self->_activeRetrievalCounter == 0)
				{
					self.isWaitingForResults = NO;
					[core endActivity:@"Search for recipients"];
				}

				if (searchID < self->_lastSearchID)
				{
					// Ignore search results that are older than already received search results, so that a "large" search that returns after a subsequent "short" search can't overwrite more recent, more specific results for a different search term
					return;
				}

				self->_lastSearchID = searchID;
			}

			self.recipients = recipients;

			if ((self.delegate!=nil) && [self.delegate respondsToSelector:@selector(searchControllerHasNewResults:error:)])
			{
				[self.delegate searchControllerHasNewResults:self error:error];
			}
		}];
	}
}

@end
