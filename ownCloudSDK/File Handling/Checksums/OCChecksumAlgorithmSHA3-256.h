//
//  OCChecksumAlgorithmSHA3-256.h
//  ownCloudSDK
//
//  Created by Matthias Hühne on 29.05.25.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2025, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "OCChecksumAlgorithm.h"

@interface OCChecksumAlgorithmSHA3 : OCChecksumAlgorithm

@end

extern OCChecksumAlgorithmIdentifier OCChecksumAlgorithmIdentifierSHA3_256;
