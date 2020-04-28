/*
 *
 * Based on ISRunLoopThread, as found at https://gist.github.com/felix-schwarz/9fa9055b6ade900f1f21
 *
 */

//
//  ISRunLoopThread.h
//
//  Created by Felix Schwarz on 13.09.14.
//  Copyright (c) 2014 IOSPIRIT GmbH. All rights reserved.
//

/*
#
# Copyright (c) 2014 Felix Schwarz (@felix_schwarz), IOSPIRIT GmbH (@iospirit)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
*/

#import <Foundation/Foundation.h>

@interface OCRunLoopThread : NSObject
{
	NSThread *thread;
	NSRunLoop *runLoop;
	NSString *name;
	NSUUID *_uuid;

	dispatch_semaphore_t _syncSemaphore;
}

@property(retain) NSString *name;

@property(readonly) NSThread *thread;
@property(readonly) NSRunLoop *runLoop;

@property(readonly) NSUUID *uuid;

@property(nonatomic,readonly) BOOL isCurrentThread;

+ (instancetype)mainRunLoopThread;
+ (instancetype)currentRunLoopThread;

+ (instancetype)runLoopThreadNamed:(NSString *)runLoopThreadName;

- (void)dispatchBlockToRunLoopAsync:(dispatch_block_t)block;

- (void)terminate;

@end
