//
//  OCClassSettings.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 23.02.18.
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
#import "OCLogTag.h"

/*
	OCClassSettings provides a central mechanism for storing class-specific settings:
 
	- participating classes..
		- must conform to the OCClassSettingsSupport protocol
		- return a class settings identifier
		- return a dictionary with default settings for a class settings identifier
		- retrieve the current settings via [[OCClassSettings sharedSettings] settingsForClass:[self class]]

	- OCClassSettings can return the default settings defined by the class itself, but could also use the identifier to locate a class-specific custom settings dictionary in NSUserDefaults and MDM profiles
 
	- OCClassSettings thereby provides a central, flexible mechanism to modify the behaviour and default values of classes in the SDK (ready for customization and MDM)
*/

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCClassSettingsIdentifier NS_TYPED_EXTENSIBLE_ENUM;
typedef NSString* OCClassSettingsKey NS_TYPED_EXTENSIBLE_ENUM;

typedef NSString* OCClassSettingsFlatIdentifier; //!< Flat identifier, composed as "[OCClassSettingsIdentifier].[OCClassSettingsKey]". See NSString+OCClassSettings for convenience methods.

typedef NSString* OCClassSettingsMetadataKey NS_TYPED_EXTENSIBLE_ENUM;
typedef NSDictionary<OCClassSettingsMetadataKey,id>* OCClassSettingsMetadata;
typedef NSDictionary<OCClassSettingsKey,OCClassSettingsMetadata>* OCClassSettingsMetadataCollection;

typedef NSString* OCClassSettingsMetadataType NS_TYPED_EXTENSIBLE_ENUM;

typedef NSString* OCClassSettingsKeyStatus NS_TYPED_EXTENSIBLE_ENUM;

typedef NS_OPTIONS(NSInteger, OCClassSettingsFlag)
{
	OCClassSettingsFlagIsPrivate 	 	= (1 << 0), //!< If [OCClassSettingsSupport publicClassSettingsIdentifiers] is not implemented, allows flagging the value of the key as private (in the sense defined by [OCClassSettingsSupport publicClassSettingsIdentifiers])

	OCClassSettingsFlagAllowUserPreferences = (1 << 1), //! If [OCClassSettingsUserPreferencesSupport allowUserPreferenceForClassSettingsKey:] is not implemented, allows modifying the value for the key via user preferences

	OCClassSettingsFlagDenyUserPreferences  = (1 << 2)  //! If [OCClassSettingsUserPreferencesSupport allowUserPreferenceForClassSettingsKey:] is not implemented, denies modifying the value for the key via user preferences
};

@protocol OCClassSettingsSupport <NSObject>

@property(strong,readonly,class) OCClassSettingsIdentifier classSettingsIdentifier;
+ (nullable NSDictionary<OCClassSettingsKey, id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier;

@optional
+ (nullable NSArray<OCClassSettingsKey> *)publicClassSettingsIdentifiers; //!< Returns an array of OCClassSettingsKey whose values should be considered public (i.e. be ok to be logged in an overview). If not implemented, all OCClassSettingsKeys returned by defaultSettingsForIdentifier are considered public.

// Metadata support
+ (nullable OCClassSettingsMetadata)classSettingsMetadataForKey:(OCClassSettingsKey)key; //!< Returns the metadata for a specific OCClassSettingsKey. (used first, if implemented)
+ (nullable OCClassSettingsMetadataCollection)classSettingsMetadata; //!< Returns a collection of metadata, split by OCClassSettingsKey. (used if -classSettingsMetadataRecordForKey: is not implemented or returned nil).
+ (BOOL)classSettingsMetadataHasDynamicContentForKey:(OCClassSettingsKey)key; //!< If +classSettingsMetadataForKey: or +classSettingsMetadata returns dynamic content for a OCClassSettingsKey, it must implement this method and return YES here. If this method is not implemented - or the method returns NO for a OCClassSettingsKey, the returned metadata is considered static - and therefore can be cached for faster and more efficient access.

+ (nullable NSError *)validateValue:(nullable id)value forSettingsKey:(OCClassSettingsKey)key; //!< Optional validation of values for a specific OCClassSettingsKey. Return nil if validation has passed - or if no validation was performed. Standard validation is performed before calling this method.

@end

typedef NSString* OCClassSettingsSourceIdentifier NS_TYPED_ENUM;

@protocol OCClassSettingsSource <NSObject>

- (OCClassSettingsSourceIdentifier)settingsSourceIdentifier;
- (nullable NSDictionary<OCClassSettingsKey, id> *)settingsForIdentifier:(OCClassSettingsIdentifier)identifier;

@end

@interface OCClassSettings : NSObject <OCLogTagging>
{
	NSMutableDictionary<OCClassSettingsIdentifier,NSMutableArray<OCClassSettingsMetadataCollection> *> *_registeredMetaDataCollectionsByIdentifier;
	NSMutableDictionary<OCClassSettingsIdentifier,NSMutableDictionary<OCClassSettingsKey,id> *> *_registeredDefaultValuesByKeyByIdentifier;

	NSMutableDictionary<OCClassSettingsIdentifier,NSMutableDictionary<OCClassSettingsKey,id> *> *_validatedValuesByKeyByIdentifier;
	NSMutableDictionary<OCClassSettingsIdentifier,NSMutableDictionary<OCClassSettingsKey,id> *> *_actualValuesByKeyByIdentifier;

	NSMutableDictionary<OCClassSettingsIdentifier,NSMutableDictionary<OCClassSettingsKey,NSNumber *> *> *_flagsByKeyByIdentifier;
}

@property(class, readonly, strong, nonatomic) OCClassSettings *sharedSettings;

- (void)registerDefaults:(NSDictionary<OCClassSettingsKey, id> *)defaults metadata:(nullable OCClassSettingsMetadataCollection)metaData forClass:(Class<OCClassSettingsSupport>)theClass; //!< Registers additional defaults for a class. These are added to the defaults provided by the class itself. Can be used to provide additional settings from a subclass' +load method. A convenience method for this is available as +[NSObject registerOCClassSettingsDefaults:].

- (void)addSource:(id <OCClassSettingsSource>)source;
- (void)insertSource:(id <OCClassSettingsSource>)source before:(nullable OCClassSettingsSourceIdentifier)beforeSourceID after:(nullable OCClassSettingsSourceIdentifier)afterSourceID;
- (void)removeSource:(id <OCClassSettingsSource>)source;

- (void)clearSourceCache;

- (nullable NSDictionary<OCClassSettingsKey, id> *)settingsForClass:(Class<OCClassSettingsSupport>)theClass;

- (NSDictionary<OCClassSettingsIdentifier, NSDictionary<OCClassSettingsKey, NSArray<NSDictionary<OCClassSettingsSourceIdentifier, id> *> *> *> *)settingsSnapshotForClasses:(nullable NSArray<Class> *)classes onlyPublic:(BOOL)onlyPublic;
- (nullable NSString *)settingsSummaryForClasses:(nullable NSArray<Class> *)classes onlyPublic:(BOOL)onlyPublic;

@end

extern NSNotificationName OCClassSettingsChangedNotification; //!< Posted with object==nil if any value could have changed, posted with object==flatIdentifier if a specific setting has changed

NS_ASSUME_NONNULL_END

#import "NSObject+OCClassSettings.h"
#import "OCClassSettings+Validation.h"
#import "OCClassSettings+Metadata.h"
