//
//  OCSyncAction+Diagnostic.m
//  ownCloudSDK
//
//  Created by Felix Schwarz on 27.07.20.
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

#import "OCSyncAction+Diagnostic.h"

@implementation OCSyncAction (Diagnostic)

- (NSArray<OCDiagnosticNode *> *)diagnosticNodesWithContext:(OCDiagnosticContext *)context
{
	return (@[
		[OCDiagnosticNode withLabel:@"Class" content:NSStringFromClass(self.class)],
		[OCDiagnosticNode withLabel:@"Identifier" content:self.identifier],
		[OCDiagnosticNode withLabel:@"Localized Description" content:self.localizedDescription]
	]);
}

@end
