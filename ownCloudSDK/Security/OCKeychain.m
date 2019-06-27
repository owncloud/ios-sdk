//
//  OCKeychain.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 16.02.18.
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

#import "OCKeychain.h"

@implementation OCKeychain

#pragma mark - Init & Dealloc
- (instancetype)initWithAccessGroupIdentifier:(NSString *)accessGroupIdentifier
{
	if ((self = [super init]) != nil)
	{
		_accessGroupIdentifier = accessGroupIdentifier;
	}
	
	return(self);
}

- (void)dealloc
{
}

- (NSMutableDictionary <NSString *, id> *)_queryType:(CFStringRef)queryType dictForAccount:(NSString *)account path:(NSString *)path
{
	NSMutableDictionary *queryDict = [NSMutableDictionary dictionary];

	if (account != nil)
	{
		queryDict[(id)kSecAttrAccount] = account;
	}

	if (path != nil)
	{
		queryDict[(id)kSecAttrPath] = path;
	}

	queryDict[(id)kSecClass] = (id)kSecClassInternetPassword;

	if (_accessGroupIdentifier != nil)
	{
		queryDict[(id)kSecAttrAccessGroup] = _accessGroupIdentifier;
		queryDict[(id)kSecAttrSynchronizable] = (id)kCFBooleanFalse;
	}
	
	if (queryType != NULL)
	{
		queryDict[(__bridge id)queryType]	= (id)kCFBooleanTrue;
		queryDict[(id)kSecMatchLimit]     	= (id)kSecMatchLimitOne;
	}

	return (queryDict);
}

- (NSDictionary<NSString *, id> *)_attributesOfItemForAccount:(NSString *)account path:(NSString *)path
{
	NSMutableDictionary <NSString *, id> *queryDict;
	NSDictionary <NSString *, id> *attrDict = nil;
	
	if ((queryDict = [self _queryType:kSecReturnAttributes dictForAccount:account path:path]) != nil)
	{
		OSStatus status;
		CFDictionaryRef outDict = nil;
		
		if ((status = SecItemCopyMatching((CFDictionaryRef)queryDict, (CFTypeRef *)&outDict)) == errSecSuccess)
		{
			attrDict = (NSDictionary *)CFBridgingRelease(outDict);
		}
	}

	return (attrDict);
}

- (NSData *)readDataFromKeychainItemForAccount:(NSString *)account path:(NSString *)path
{
	NSMutableDictionary <NSString *, id> *queryDict;
	CFDataRef outData = nil;
	
	if ((queryDict = [self _queryType:kSecReturnData dictForAccount:account path:path]) != nil)
	{
		OSStatus status;
		
		if ((status = SecItemCopyMatching((CFDictionaryRef)queryDict, (CFTypeRef *)&outData)) == errSecItemNotFound)
		{
			return (nil);
		}
	}

	return ((NSData *)CFBridgingRelease(outData));
}

- (NSError *)writeData:(NSData *)data toKeychainItemForAccount:(NSString *)account path:(NSString *)path
{
	NSDictionary<NSString *, id> *itemAttributesForExistingItem;
	OSStatus status = errSecSuccess;
	NSError *error = nil;
	
	if ((itemAttributesForExistingItem = [self _attributesOfItemForAccount:account path:path]) != nil)
	{
		// Item already exists. Update it.
		NSMutableDictionary <NSString *, id> *queryDict;
		
		if ((queryDict = [self _queryType:NULL dictForAccount:account path:path]) != nil)
		{
			if (data != nil)
			{
				status = SecItemUpdate( (CFDictionaryRef)queryDict,
				 		        (CFDictionaryRef)@{
								(id)kSecValueData : data
							});
			}
			else
			{
				status = SecItemDelete((CFDictionaryRef)queryDict);
			}
		}
	}
	else
	{
		// Create new item
		if (data != nil)
		{
			NSMutableDictionary <NSString *, id> *queryDict;
			CFTypeRef result = NULL;
			
			if ((queryDict = [self _queryType:NULL dictForAccount:account path:path]) != nil)
			{
				queryDict[(id)kSecValueData] = data;
				queryDict[(id)kSecAttrAccessible] = (id)kSecAttrAccessibleAfterFirstUnlock;

				status = SecItemAdd((CFDictionaryRef)queryDict, &result);
			}
		}
	}
	
	if (status != errSecSuccess)
	{
		error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
	}

	return (error);
}

- (NSError *)removeKeychainItemForAccount:(NSString *)account path:(NSString *)path
{
	return ([self writeData:nil toKeychainItemForAccount:account path:path]);
}

- (id)readObjectFromKeychainItemForAccount:(NSString *)account path:(NSString *)path allowedClasses:(NSSet<Class> *)allowedClasses rootClass:(Class)rootClass error:(NSError **)outError
{
	NSData *data;
	id decodedObject = nil;

	if ((data = [self readDataFromKeychainItemForAccount:account path:path]) != nil)
	{
		NSError *error = nil;

		decodedObject = [NSKeyedUnarchiver unarchivedObjectOfClasses:allowedClasses fromData:data error:&error];

		if (![decodedObject isKindOfClass:rootClass])
		{
			decodedObject = nil;
		}

		if (outError != nil)
		{
			*outError = error;
		}
	}

	return (decodedObject);
}

- (NSError *)writeObject:(id)object toKeychainItemForAccount:(NSString *)account path:(NSString *)path
{
	NSError *error = nil;

	if (object != nil)
	{
		NSData *data;

		if ((data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:&error]) != nil)
		{
			[self writeData:data toKeychainItemForAccount:account path:path];
		}
	}
	else
	{
		[self removeKeychainItemForAccount:account path:path];
	}

	return (error);
}

@end

