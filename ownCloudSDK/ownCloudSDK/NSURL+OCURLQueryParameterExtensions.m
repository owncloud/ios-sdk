//
//  NSURL+OCURLQueryParameterExtensions.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 25.02.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

#import "NSURL+OCURLQueryParameterExtensions.h"

@implementation NSURL (OCURLQueryParameterExtensions)

- (NSURL *)urlByModifyingQueryParameters:(NSMutableArray <NSURLQueryItem *> *(^)(NSMutableArray <NSURLQueryItem *> *queryItems))queryItemsAction
{
	if (queryItemsAction==nil)
	{
		return(self);
	}
	else
	{
		NSURLComponents *urlComponents;
		
		if ((urlComponents = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:YES]) != nil)
		{
			NSMutableArray <NSURLQueryItem *> *queryItems;
			
			if (urlComponents.queryItems != nil)
			{
				queryItems = [NSMutableArray arrayWithArray:urlComponents.queryItems];
			}
			else
			{
				queryItems = [NSMutableArray array];
			}
			
			urlComponents.queryItems = queryItemsAction(queryItems);
		}
		
		return (urlComponents.URL);
	}
}

- (NSURL *)urlByAppendingQueryParameters:(NSDictionary<NSString *,NSString *> *)parameters replaceExisting:(BOOL)replaceExisting
{
	return ([self urlByModifyingQueryParameters:^NSMutableArray<NSURLQueryItem *> *(NSMutableArray<NSURLQueryItem *> *queryItems) {
			// Remove existing
			if (replaceExisting)
			{
				__block NSMutableIndexSet *removeItemsAtIndexes = nil;

				[queryItems enumerateObjectsUsingBlock:^(NSURLQueryItem * _Nonnull queryItem, NSUInteger idx, BOOL * _Nonnull stop) {
					if (parameters[queryItem.name] != nil)
					{
						if (removeItemsAtIndexes==nil) { removeItemsAtIndexes = [NSMutableIndexSet indexSet]; }
						
						[removeItemsAtIndexes addIndex:idx];
					}
				}];

				if (removeItemsAtIndexes != nil)
				{
					[queryItems removeObjectsAtIndexes:removeItemsAtIndexes];
				}
			}
	
			// Add items
			[parameters enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL *stop) {
				[queryItems addObject:[NSURLQueryItem queryItemWithName:name value:value]];
			}];
		
			return(queryItems);
		}]);
}

- (NSDictionary <NSString *,NSString *> *)queryParameters
{
	NSMutableDictionary <NSString *,NSString *> *queryParameters = nil;
	NSURLComponents *urlComponents;

	if ((urlComponents = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:YES]) != nil)
	{
		if (urlComponents.queryItems != nil)
		{
			queryParameters = [NSMutableDictionary dictionary];
			
			for (NSURLQueryItem *queryItem in urlComponents.queryItems)
			{
				[queryParameters setObject:((queryItem.value!=nil) ? queryItem.value : @"") forKey:queryItem.name];
			}
		}
	}
	
	return (queryParameters);
}

@end
