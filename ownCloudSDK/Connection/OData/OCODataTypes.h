//
//  OCODataTypes.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 10.02.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import <Foundation/Foundation.h>

typedef NSString* OCODataEntityID;
typedef NSString* OCODataProperty;
typedef NSString* OCODataFilterString;

typedef NSString* OCODataLibreGraphID;
typedef NSDictionary<OCODataLibreGraphID,id>* OCODataLibreGraphObjects;

typedef NSString *OCODataOptionKey;
typedef NSDictionary<OCODataOptionKey,id> *OCODataOptions;
