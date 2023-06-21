//
//  OCServerInstance.h
//  ownCloudSDK
//
//  Created by Felix Schwarz on 07.03.23.
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OCServerInstance : NSObject

@property(strong) NSURL *url;
@property(strong,nullable) NSDictionary<NSString *,NSString *> *titlesByLanguageCode;
@property(readonly,nullable,nonatomic) NSString *localizedTitle;

- (instancetype)initWithURL:(NSURL *)url;

@end

NS_ASSUME_NONNULL_END
