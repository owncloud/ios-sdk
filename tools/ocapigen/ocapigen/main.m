//
//  main.m
//  ocapigen
//
//  Created by Felix Schwarz on 26.01.22.
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
#import "OCYAMLParser.h"
#import "OCSchema.h"
#import "OCCodeGeneratorObjC.h"

typedef NS_ENUM(NSInteger, CLParameter)
{
	CLParameterNone,
	CLParameterSourceYAMLFile,
	CLParameterTargetFolder,
	CLParameterTargetGenerator
};

int main(int argc, const char * argv[]) {
	@autoreleasepool {
		NSError *error = nil;
		NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
		CLParameter parameter = CLParameterNone;
		Class generatorClass = Nil;

		NSURL *srcYamlURL = nil;
		NSURL *targetFolderURL = nil;

		NSString *workingDirectoryPath = NSFileManager.defaultManager.currentDirectoryPath;

		NSLog(@"Working directory path: %@", workingDirectoryPath);

		for (NSString *argument in arguments)
		{
			if (parameter == CLParameterNone)
			{
				if ([argument isEqual:@"--yaml"])   { parameter = CLParameterSourceYAMLFile; }
				if ([argument isEqual:@"--target"]) { parameter = CLParameterTargetFolder; }
				if ([argument isEqual:@"--generator"]) { parameter = CLParameterTargetGenerator; }
			}
			else
			{
				switch (parameter)
				{
					case CLParameterNone:
					break;

					case CLParameterSourceYAMLFile:
						if ((srcYamlURL = [NSURL URLWithString:argument]) == nil)
						{
							srcYamlURL = [NSURL fileURLWithPath:argument];
						}
					break;

					case CLParameterTargetFolder:
						targetFolderURL = [NSURL fileURLWithPath:argument];
					break;

					case CLParameterTargetGenerator:
						if ([argument isEqual:@"objc"])
						{
							generatorClass = OCCodeGeneratorObjC.class;
						}
					break;
				}

				parameter = CLParameterNone;
			}
		}

		if ((srcYamlURL == nil) || (targetFolderURL == nil) || (generatorClass == Nil))
		{
			NSLog(@"error: missing parameters.");
			return (-1);
		}

		NSString *yamlFileContents = [NSString stringWithContentsOfURL:srcYamlURL encoding:NSUTF8StringEncoding error:&error];
		OCYAMLParser *parser = [[OCYAMLParser alloc] initWithFileContents:yamlFileContents];

		[parser parse];

		OCYAMLNode *schemasNode = [parser nodeForPath:@"#/components/schemas"];

		OCCodeGenerator *generator = [[generatorClass alloc] initWithTargetFolder:targetFolderURL];

		for (OCYAMLNode *schemaNode in schemasNode.children)
		{
			OCSchema *schema;

			if ((schema = [[OCSchema alloc] initWithYAMLNode:schemaNode parser:parser]) != nil)
			{
				[generator addSchema:schema];
			}

			// NSLog(@"%@", schemaNode.childrenByName[@"properties"].childrenByName.allKeys);
		}

		[generator generate];
	}

	return 0;
}
