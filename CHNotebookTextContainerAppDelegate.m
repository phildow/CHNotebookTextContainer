//
//  CHNotebookTextContainerAppDelegate.m
//  CHNotebookTextContainer
//
//  Created by Philip Dow on 11/14/11.
//  Copyright 2011 Philip Dow / Sprouted. All rights reserved.
//

/*

	Redistribution and use in source and binary forms, with or without modification, 
	are permitted provided that the following conditions are met:

	* Redistributions of source code must retain the above copyright notice, this list 
	of conditions and the following disclaimer.

	* Redistributions in binary form must reproduce the above copyright notice, this 
	list of conditions and the following disclaimer in the documentation and/or other 
	materials provided with the distribution.

	* Neither the name of the author nor the names of its contributors may be used to 
	endorse or promote products derived from this software without specific prior 
	written permission.

	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY 
	EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
	OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT 
	SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
	TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
	BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN 
	ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH 
	DAMAGE.

*/

/*
	For non-attribution licensing options refer to http://phildow.net/licensing/
*/

#import "CHNotebookTextContainerAppDelegate.h"
#import "CHNotebookTextContainer.h"

@implementation CHNotebookTextContainerAppDelegate

@synthesize textView;
@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application 
	
	// create the custom text container
	const CGFloat CHLargeNumberForText = 1.0e7; // Any larger dimensions and the text could become blurry.
												// TextEdit source code
	CHNotebookTextContainer *textContainer = [[[CHNotebookTextContainer alloc] 
			initWithContainerSize:NSMakeSize(CHLargeNumberForText, CHLargeNumberForText)]
			autorelease];
		
	// adopt attributes from existing text container
	[textContainer setHeightTracksTextView:[[self.textView textContainer] heightTracksTextView]];	
	[textContainer setWidthTracksTextView:[[self.textView textContainer] widthTracksTextView]];
	[textContainer setLineFragmentPadding:[[self.textView textContainer] lineFragmentPadding]];
	
	// replace the text container in place, text system handles internal associations
	[self.textView replaceTextContainer:textContainer];
	
	// add a couple of clipping paths, media appears in these frames
	NSRect mediaFrame1 = NSMakeRect(100,100,200,120);
	NSString *identifier1 = @"container.media.1";
	
	NSRect mediaFrame2 = NSMakeRect(180,150,200,120);
	NSString *identifier2 = @"container.media.2";
	
	[textContainer setClippingRect:mediaFrame1 forKey:identifier1];
	[textContainer setClippingRect:mediaFrame2 forKey:identifier2];
	
	// add a couple of image views w/ images in these frames
	// NSTextView works just fine with subviews
	
	NSImageView *imageView1 = [[[NSImageView alloc] initWithFrame:mediaFrame1] autorelease];
	[imageView1 setImage:[NSImage imageNamed:@"media1.png"]];
	[self.textView addSubview:imageView1];
	
	NSImageView *imageView2 = [[[NSImageView alloc] initWithFrame:mediaFrame2] autorelease];
	[imageView2 setImage:[NSImage imageNamed:@"media2.png"]];
	[self.textView addSubview:imageView2];
	
	// remove clipping paths by setting NSZeroRect for the associated key identifier
	// uncomment one or the other to see how the native text system handles embedded
	// images without adjustments to the container geometry
	
	// [textContainer setClippingRect:NSZeroRect forKey:identifier1];
	// [textContainer setClippingRect:NSZeroRect forKey:identifier2];
}

@end
