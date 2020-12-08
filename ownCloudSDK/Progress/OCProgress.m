//
//  OCProgress.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 05.02.19.
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

#import "OCProgress.h"
#import "OCProgressManager.h"
#import "OCEvent.h"

@interface OCProgress ()
{
	NSUInteger _resolutionOffset;
}

@end

@implementation OCProgress

- (instancetype)init
{
	if ((self = [super init]) != nil)
	{
		_identifier = NSUUID.UUID.UUIDString;
		_cancellable = YES;
	}

	return (self);
}

- (instancetype)initWithPath:(OCProgressPath)path progress:(nullable NSProgress *)progress
{
	if ((self = [self init]) != nil)
	{
		_path = path;
		_progress = progress;
	}

	return (self);
}

- (instancetype)initWithSource:(id<OCProgressSource>)source pathElementIdentifier:(OCProgressPathElementIdentifier)identifier progress:(nullable NSProgress *)progress
{
	return ([self initWithPath:[[source progressBasePath] arrayByAddingObject:identifier] progress:progress]);
}

- (BOOL)nextPathElementIsLast
{
	@synchronized(self)
	{
		return (_resolutionOffset == (_path.count-1));
	}
}

- (OCProgressPathElementIdentifier)nextPathElement
{
	OCProgressPathElementIdentifier nextElement = nil;

	@synchronized (self)
	{
		if (_resolutionOffset < _path.count)
		{
			nextElement = [_path objectAtIndex:_resolutionOffset];
			_resolutionOffset ++;
		}
	}

	return (nextElement);
}

- (void)resetResolutionOffset //!< Resets the resolution offset to 0, so the resolution can be restarted.
{
	@synchronized (self)
	{
		_resolutionOffset = 0;
	}
}

- (NSProgress *)resolveWith:(id<OCProgressResolver>)resolver context:(OCProgressResolutionContext)context
{
	NSProgress *progress = nil;

	if (resolver == nil)
	{
		resolver = OCProgressManager.sharedProgressManager;
	}

	if ((context == nil) && ([resolver respondsToSelector:@selector(progressResolutionContext)]))
	{
		context = resolver.progressResolutionContext;
	}

	@synchronized(self)
	{
		if (_progress != nil)
		{
			progress = _progress;
		}
		else
		{
			id <OCProgressResolver> currentResolver = resolver;

			do
			{
				BOOL isLastPathElement = self.nextPathElementIsLast;
				BOOL performResolution = NO;

				// Check for routing capabilities
				if (!isLastPathElement)
				{
					if ([currentResolver respondsToSelector:@selector(resolverForPathElement:withContext:)])
					{
						// Routing available
						OCProgressPathElementIdentifier nextPathElement = nil;

						if ((nextPathElement = [self nextPathElement]) != nil)
						{
							if ((currentResolver = [currentResolver resolverForPathElement:nextPathElement withContext:context]) == nil)
							{
								// Resolution failed
								break;
							}
						}
						else
						{
							// Internal error
							break;
						}
					}
					else
					{
						// No routing available => resolve from here
						performResolution = YES;
					}
				}
				else
				{
					// Last path element. Resolution required.
					performResolution  = YES;
				}

				if (performResolution)
				{
					if ([currentResolver respondsToSelector:@selector(resolveProgress:withContext:)])
					{
						if ((progress = [currentResolver resolveProgress:self withContext:context]) == nil)
						{
							// Resolution failed
							break;
						}
					}
					else
					{
						// Resolution failed.
						break;
					}
				}
			} while((_resolutionOffset < _path.count) && (progress == nil));

			if (progress != nil)
			{
				self.progress = progress;
			}

			// Reset offset for next resolution
			[self resetResolutionOffset];
		}
	}

	return(progress);
}

- (nullable NSProgress *)resolveWith:(id<OCProgressResolver>)resolver
{
	return ([self resolveWith:resolver context:nil]);
}

- (void)cancel
{
	if (!_cancelled && _cancellable)
	{
		self.cancelled = YES;

		if (_cancellationHandler != nil)
		{
			_cancellationHandler();
		}
		else
		{
			[_progress cancel];
		}
	}
}

- (BOOL)cancelled
{
	return (_cancelled || _progress.isCancelled);
}

+ (BOOL)supportsSecureCoding
{
	return(YES);
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
	[coder encodeObject:_identifier forKey:@"identifier"];
	[coder encodeObject:_path forKey:@"path"];
	[coder encodeObject:_userInfo forKey:@"userInfo"];
	[coder encodeBool:_cancelled forKey:@"cancelled"];
	[coder encodeBool:_cancellable forKey:@"cancellable"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)decoder
{
	if ((self = [self init]) != nil)
	{
		_identifier = [decoder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
		_path = [decoder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:NSArray.class, NSString.class, nil] forKey:@"path"];
		_userInfo = [decoder decodeObjectOfClasses:OCEvent.safeClasses forKey:@"userInfo"];
		_cancelled = [decoder decodeBoolForKey:@"cancelled"];
		_cancellable = [decoder decodeBoolForKey:@"cancellable"];
	}

	return (self);
}

@end
