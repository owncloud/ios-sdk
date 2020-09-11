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

@protocol OCClassSettingsSupport <NSObject>

@property(strong,readonly,class) OCClassSettingsIdentifier classSettingsIdentifier;
+ (nullable NSDictionary<OCClassSettingsKey, id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier;

@optional
+ (nullable NSArray<OCClassSettingsKey> *)publicClassSettingsIdentifiers; //!< Returns an array of OCClassSettingsKey whose values should be considered public (i.e. be ok to be logged in an overview). If not implemented, all OCClassSettingsKeys returned by defaultSettingsForIdentifier are considered public.

@end

typedef NSString* OCClassSettingsSourceIdentifier NS_TYPED_ENUM;

@protocol OCClassSettingsSource <NSObject>

- (OCClassSettingsSourceIdentifier)settingsSourceIdentifier;
- (nullable NSDictionary<OCClassSettingsKey, id> *)settingsForIdentifier:(OCClassSettingsIdentifier)identifier;

@end

@interface OCClassSettings : NSObject

@property(class, readonly, strong, nonatomic) OCClassSettings *sharedSettings;

- (void)registerDefaults:(NSDictionary<OCClassSettingsKey, id> *)defaults forClass:(Class<OCClassSettingsSupport>)theClass; //!< Registers additional defaults for a class. These are added to the defaults provided by the class itself. Can be used to provide additional settings from a subclass' +load method. A convenience method for this is available as +[NSObject registerOCClassSettingsDefaults:].

- (void)addSource:(id <OCClassSettingsSource>)source;
- (void)insertSource:(id <OCClassSettingsSource>)source before:(nullable OCClassSettingsSourceIdentifier)beforeSourceID after:(nullable OCClassSettingsSourceIdentifier)afterSourceID;
- (void)removeSource:(id <OCClassSettingsSource>)source;

- (void)clearSourceCache;

- (nullable NSDictionary<OCClassSettingsKey, id> *)settingsForClass:(Class<OCClassSettingsSupport>)theClass;

- (NSDictionary<OCClassSettingsIdentifier, NSDictionary<OCClassSettingsKey, NSArray<NSDictionary<OCClassSettingsSourceIdentifier, id> *> *> *> *)settingsSnapshotForClasses:(nullable NSArray<Class> *)classes onlyPublic:(BOOL)onlyPublic;
- (nullable NSString *)settingsSummaryForClasses:(nullable NSArray<Class> *)classes onlyPublic:(BOOL)onlyPublic;

@end

NS_ASSUME_NONNULL_END

#import "NSObject+OCClassSettings.h"
