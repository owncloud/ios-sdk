//
//  OCClassSettings+Metadata.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 20.10.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2020, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCClassSettings.h"

NS_ASSUME_NONNULL_BEGIN

typedef NSString* OCClassSettingsAutoExpansion NS_TYPED_ENUM;

typedef NSString* OCClassSettingsMetadataOption NS_TYPED_ENUM;

@interface OCClassSettings (Metadata)

- (nullable NSDictionary<OCClassSettingsKey, id> *)defaultsForClass:(Class<OCClassSettingsSupport>)settingsClass;
- (nullable NSSet<OCClassSettingsKey> *)keysForClass:(Class<OCClassSettingsSupport>)settingsClass;

- (nullable OCClassSettingsMetadata)metadataForClass:(Class<OCClassSettingsSupport>)settingsClass key:(OCClassSettingsKey)key options:(nullable NSDictionary<OCClassSettingsMetadataOption, id> *)options;

- (OCClassSettingsFlag)flagsForClass:(Class<OCClassSettingsSupport>)settingsClass key:(OCClassSettingsKey)key;

@end

extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyType; //!< Expected type of value, expressed via a single OCClassSettingsMetadataType or an array of OCClassSettingsMetadataTypes.
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyKey; //!< Return-only key, with the OCClassSettingsKey as value.
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyIdentifier; //!< Return-only key, with the OCClassSettingsIdentifier of the setting as value.
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyFlatIdentifier; //!< Return-only key, with the OCClassSettingsFlatIdentifier of the setting as value.
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyClassName; //!< Return-only key, with the name of the Class associated with the settings.
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyLabel; //!< A label for the setting. If none is provided, the flat identifier is used.
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyDescription; //!< A description of the setting. If none is provided, a description should be made available in the settings-doc directory following the "[OCClassSettingsIdentifier].[OCClassSettingsKey].md" nomenclature
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyCategory; //!< The name of the category the setting should be listed under.
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyCategoryTag; //!< The name of the catagory as "tag" (without spaces and lowercase)
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeySubCategory; //!< The name of the sub-category the setting should be listed under.
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeySubCategoryTag; //!< The name of the sub-catagory as "tag" (without spaces and lowercase)
/// Possible values. Either of:
///
/// - a dictionary, where the keys represent possible values, and the value is the description (f.ex. { @"allow-all" : @"Allows all.", … })
///
/// - an array of dictionaries (f.ex. [ { OCClassSettingsMetadataKeyValue : @"allow-all", OCClassSettingsMetadataKeyDescription : @"Allows all." }, … ]), leaving room for a future expansion beyond fixed values.
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyPossibleValues;
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyValue; //!< Only for use in OCClassSettingsMetadataKeyPossibleValues dictionaries.
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyDocDefaultValue; //!< Return-only key, with the default value for documentation.
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyAutoExpansion; //!< None for no auto-expansion, Trailing for auto expansion if the value is identical to the end of a supported value. Defaults to None.
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyFlags; //!< NSNumber-representation of OCClassSettingsFlags flags
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyCustomValidationClass; //!< Name of the class to call +validateValue:forSettingsKey: on. Defaults to class a value is requested from, so this is only needed if validation should be handled by f.ex. a subclass.
extern OCClassSettingsMetadataKey OCClassSettingsMetadataKeyStatus; //!< Support status of the setting. If not specified, defaults to OCClassSettingsKeyStatusSupported.

extern OCClassSettingsMetadataType OCClassSettingsMetadataTypeBoolean;
extern OCClassSettingsMetadataType OCClassSettingsMetadataTypeInteger;
extern OCClassSettingsMetadataType OCClassSettingsMetadataTypeFloat;
extern OCClassSettingsMetadataType OCClassSettingsMetadataTypeDate;
extern OCClassSettingsMetadataType OCClassSettingsMetadataTypeString;
extern OCClassSettingsMetadataType OCClassSettingsMetadataTypeStringArray;
extern OCClassSettingsMetadataType OCClassSettingsMetadataTypeNumberArray;
extern OCClassSettingsMetadataType OCClassSettingsMetadataTypeArray;
extern OCClassSettingsMetadataType OCClassSettingsMetadataTypeDictionary;
extern OCClassSettingsMetadataType OCClassSettingsMetadataTypeDictionaryArray;
extern OCClassSettingsMetadataType OCClassSettingsMetadataTypeURLString;

extern OCClassSettingsKeyStatus OCClassSettingsKeyStatusRecommended; //!< Setting should be included in AppConfig.xml file for EMM vendors.
extern OCClassSettingsKeyStatus OCClassSettingsKeyStatusSupported; //!< Setting is available in the production/release version.
extern OCClassSettingsKeyStatus OCClassSettingsKeyStatusAdvanced; //!< Setting is available in the production/release version, but considered an expert option.
extern OCClassSettingsKeyStatus OCClassSettingsKeyStatusDebugOnly; //!< Setting is only available in the debug version.

extern OCClassSettingsAutoExpansion OCClassSettingsAutoExpansionNone; //!< Do not auto expand value to a possible value.
extern OCClassSettingsAutoExpansion OCClassSettingsAutoExpansionTrailing; //!< Do auto expand value to a possible value if the possible value ends with value.

extern OCClassSettingsMetadataOption OCClassSettingsMetadataOptionFillMissingValues; //!< If YES, missing values are added to the metadata dictionary.
extern OCClassSettingsMetadataOption OCClassSettingsMetadataOptionAddDefaultValue; //!< If YES, the default value is added to the metadata dictionary.
extern OCClassSettingsMetadataOption OCClassSettingsMetadataOptionSortPossibleValues; //!< If YES, sorts possible values alphabetically.
extern OCClassSettingsMetadataOption OCClassSettingsMetadataOptionExpandPossibleValues; //!< If YES, expands simple possible value dictionaries into array of dictionaries.
extern OCClassSettingsMetadataOption OCClassSettingsMetadataOptionAddCategoryTags; //!< If YES, adds a compact version of the category through lowercasing and removing spaces as "category tag"
extern OCClassSettingsMetadataOption OCClassSettingsMetadataOptionExternalDocumentationFolders; //!< Array of NSURLs of folders to check for external documentation

NS_ASSUME_NONNULL_END
