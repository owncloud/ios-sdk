//
//  OCThemeValues.m
//  ownCloudSDK
//
//  Created by Matthias Hühne on 08.02.23.
//  Copyright © 2023 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2023, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCThemeValues.h"
#import "OCResourceRequestURLItem.h"
#import "OCResourceRequest.h"

@interface OCThemeValues()
{
    NSDictionary<NSString *, id> *_common;
    NSDictionary<NSString *, id> *_ios;
}

@end

@implementation OCThemeValues

#pragma mark - Common
@dynamic logo;
@dynamic name;
@dynamic slogan;

- (instancetype)initWithRawJSON:(NSDictionary<NSString *,id> *)rawJSON
{
    if ((self = [super init]) != nil)
    {
        _rawJSON = rawJSON;
        _common = _rawJSON[@"common"];
        _ios = _rawJSON[@"ios"];
    }

    return (self);
}

- (void)retrieveLogoWithCore:(OCCore *)core ChangeHandler:(OCResourceRequestChangeHandler)changeHandler
{
    OCResourceRequest *iconResourceRequest = [OCResourceRequestURLItem requestURLItem:[NSURL URLWithString:[NSString stringWithFormat:@"https://ocis.ocis-web.latest.owncloud.works/%@", self.logo]] identifier:nil version:OCResourceRequestURLItem.daySpecificVersion structureDescription:@"icon" waitForConnectivity:YES changeHandler:changeHandler];
    iconResourceRequest.lifetime = OCResourceRequestLifetimeSingleRun;

    OCResourceManager *resourceManager = core.vault.resourceManager;
    [resourceManager startRequest:iconResourceRequest];
}

#pragma mark - Helpers
- (NSNumber *)_castOrConvertToNumber:(id)value
{
    if ([value isKindOfClass:[NSString class]])
    {
        value = @([((NSString *)value) longLongValue]);
    }

    return (OCTypedCast(value, NSNumber));
}

#pragma mark - Common
- (NSString *)logo
{
    return (OCTypedCast(_rawJSON[@"common"][@"logo"], NSString));
}

- (NSString *)name
{
    return (OCTypedCast(_rawJSON[@"common"][@"name"], NSString));
}

- (NSString *)slogan
{
    return (OCTypedCast(_rawJSON[@"common"][@"slogan"], NSString));
}


@end

