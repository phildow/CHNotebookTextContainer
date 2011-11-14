//
//  CHNotebookTextContainer.m
//  Per Se
//
//  Created by Philip Dow on 12/25/10.
//  Copyright 2010 Philip Dow / Sprouted. All rights reserved.
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

#import "CHNotebookTextContainer.h"

enum {
	PDCustomLayoutXAxis = 0,
	PDCustomLayoutYAxis = 1
};

NSArray* PDArrayOfRectsSortedAlongAxis(NSArray* array, NSInteger axis) {
	// sorts the provided array by x- or y-origin
	// according to axis
	
	//NSAssert( (axis==0||axis==1), @"axis must be 0 for x-axis or 1 for y-axis");
	
	NSMutableArray *sortedArray = [NSMutableArray array];
	
	for ( NSValue *rectValue in array ) {
		NSRect aRect = [rectValue rectValue];
		BOOL inserted = NO;
		NSInteger i;
		
		for ( i = 0; i < sortedArray.count; i++ ) {
			NSRect sortedRect = [[sortedArray objectAtIndex:i] rectValue];
			
			if ( axis == PDCustomLayoutXAxis ) { // x-sort
				if ( aRect.origin.x < sortedRect.origin.x ) {
					[sortedArray insertObject:rectValue atIndex:i];
					inserted = YES;
					break;
				}
			}
			else if ( axis == PDCustomLayoutYAxis ) { //y-sort
				if ( aRect.origin.y < sortedRect.origin.y ) {
					[sortedArray insertObject:rectValue atIndex:i];
					inserted = YES;
					break;
				}
			}
		}
		
		// if we didn't insert, place it at the end
		if ( !inserted) [sortedArray addObject:rectValue];
	}
	
	return [[sortedArray copy] autorelease];
}

NSArray* PDArrayOfRectsMergedWithMarginAlongAxis(NSArray* array, CGFloat margin, NSInteger axis) {
	// merges contiguous rects in array given a margin of space
	// which may occur between them, according to axis
	//
	// rectangle A is contiguous with rectangle B along the x-axis
	// if a.origin.x + a.size.width + margin >= b.origin.x
	//
	// ** array must already be sorted along axis **
	
	//NSAssert( (axis==0||axis==1), @"axis must be 0 for x-axis or 1 for y-axis");
	
	NSMutableArray *mergedArray = [NSMutableArray array];
	NSInteger i;
	
	for ( i = 0; i < array.count; i++ ) {
		NSRect aRect = [[array objectAtIndex:i] rectValue];
		NSRect mergedRect = aRect;
		NSInteger j;
		
		// check every following rect for contiguity
		for ( j = i+1; j < array.count; j++ ) {
			NSRect nextRect = [[array objectAtIndex:j] rectValue];
			
			if ( axis == PDCustomLayoutXAxis ) {
				if ( mergedRect.origin.x + mergedRect.size.width + margin >= nextRect.origin.x ) {
					// adjust mergedRect in place so that it is used through the next path
					mergedRect = NSUnionRect(mergedRect, nextRect);
				}
				else {
					break;
				}
			}
			else if ( axis == PDCustomLayoutYAxis ) {
				if ( mergedRect.origin.y + mergedRect.size.height + margin >= nextRect.origin.y ) {
					// adjust mergedRect in place so that it is used through the next path
					// note that this may cause problems with layout #9
					mergedRect = NSUnionRect(mergedRect, nextRect);
				}
				else {
					break;
				}
			}
		}
		
		// add the merged rect to the array
		[mergedArray addObject:[NSValue valueWithRect:mergedRect]];
		
		// advance i as far as j-1
		// i is ++ before running through the loop again
		// noticed this was required when the last rectangle was not
		// being added to the returned array. unintended consequences?
		i = j-1;
	}
	
	return [[mergedArray copy] autorelease];
}

CGFloat PDNextAvailableYCoordinate(NSArray *array, CGFloat minimumWidth) {
	// returns the smallest y coordinate given the rects in array
	// ensures that at least an x-span of minimumWidth is available at this y
	// TODO: PDNextAvailableYCoordinate: implement minimumWidth
	CGFloat nextAvailable = CGFLOAT_MAX;
	
	for ( NSValue *aValue in array ) {
		NSRect rect = [aValue rectValue];
		if ( NSMaxY(rect) < nextAvailable )
			nextAvailable = NSMaxY(rect);
	}
	
	return nextAvailable;
}

// setLineFragmentPadding:

@implementation CHNotebookTextContainer

static CGFloat kCHNotebookTextContainerPadding = 20.0f;
static CGFloat kCHNotebookClippingRectMargin = 20.0f;

@synthesize layoutClippings = _layoutClippings;

- (id)initWithContainerSize:(NSSize)aSize {
	if ( self = [super initWithContainerSize:aSize] ) {
		clipGrouping = NO;
		_layoutClippings = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void) dealloc {
	//DLog();
	[_layoutClippings release], _layoutClippings = nil;
	[super dealloc];
}

#pragma mark -

- (void) beginClipGrouping {
	clipGrouping = YES;
}

- (void) endClipGrouping {
	clipGrouping = NO;
}

#pragma mark -

- (void) removeAllClippingRects {
	[_layoutClippings removeAllObjects];
	if (!clipGrouping) { 
		[[self layoutManager] textContainerChangedGeometry:self];
	}
}

- (void) setClippingRect:(NSRect)aRect forKey:(id)aKey {
	
	// store the key
	// invalidate the area encompassed by this clipping rect
	// to force the layout manager to redraw the glyphs
	
	if ( aKey == nil )
		return;
	
		// i get a nil key when i add and undo media, simultaneously
		// creating a new entry, then add and undo another media
		// i should check for a nil key anyway, but this is a 
		// workaround for another more serious problem
	
	if ( NSEqualRects(aRect, NSZeroRect) )
		[_layoutClippings removeObjectForKey:aKey];
	else
		[_layoutClippings setObject:[NSValue valueWithRect:aRect] forKey:aKey];
	
	
	if (!clipGrouping) {
		[[self layoutManager] textContainerChangedGeometry:self];
	}
}

#pragma mark -
#pragma mark Calculating Text Layout

- (BOOL)isSimpleRectangularTextContainer {
	return ( [_layoutClippings count] == 0 );
}

- (NSRect)lineFragmentRectForProposedRect:(NSRect)proposedRect 
		sweepDirection:(NSLineSweepDirection)sweepDirection 
		movementDirection:(NSLineMovementDirection)movementDirection 
		remainingRect:(NSRectPointer)remainingRect {
	
	BOOL requiredModification = NO;
	NSRect reproposedRect;
	
	NSMutableArray *intersectingRects = [NSMutableArray array];
	
	// defer to super's implementation if vertical exceeds height
	if ( proposedRect.origin.y + proposedRect.size.height > self.containerSize.height ) {
		return [super lineFragmentRectForProposedRect:proposedRect 
				sweepDirection:sweepDirection 
				movementDirection:movementDirection 
				remainingRect:remainingRect];
	}
	
	
	// first pass: discover every clipping rect which intersects the proposed rect
	for ( NSValue *rectValue in [_layoutClippings objectEnumerator] ) {
		NSRect clippingRect = [rectValue rectValue];
		if ( NSIntersectsRect(proposedRect, clippingRect) ) {
			[intersectingRects addObject:rectValue];
		}
	}
	
	// if no intersections occur, defer to super
	if ( intersectingRects.count == 0 ) {
		return [super lineFragmentRectForProposedRect:proposedRect 
				sweepDirection:sweepDirection 
				movementDirection:movementDirection 
				remainingRect:remainingRect];	
	}
	else {
		
		// order the intersecting clipping rects along x-axis
		NSArray *orderedRects = PDArrayOfRectsSortedAlongAxis(intersectingRects,PDCustomLayoutXAxis);
		
		// merge contiguous rects including margin along x-axis
		NSArray *mergedRects = PDArrayOfRectsMergedWithMarginAlongAxis(orderedRects, kCHNotebookClippingRectMargin, PDCustomLayoutXAxis);
		
		// how many rects are we looking at?
		// if 1, does the rect cover the entire width of text container
		//	YES: zero the proposed rect and shift it down to the next available y coordinate
		//		 evaluating not the merged rects but individual rects for the closest y point
		//		 recursively run function on reproposed rect
		//
		//  NO or if > 1
		//	does the leftmost rect begin at the left edge of the proposed rect, including margin?
		//		YES: repropose rect from end of leftmost to beginning of next rect or border
		//			 remaining rect is a. from end of next rect to border or b. zero (border)
		//		NO:	 width is from left edge of proposed rect to beginning of first rect
		//			 remaining rect is from end of first rect to beginning of next rect or border
		//
		//	at any time if the remaining rect is less than margin, make zero rect
		//	this same algorithm will be executed recursively with each remaining rect
		//	and should work fine with it. does not matter if source is original or remaining rect
		
		if ( mergedRects.count == 1 ) {
			NSRect theRect = [[mergedRects objectAtIndex:0] rectValue];
			if ( theRect.origin.x <= kCHNotebookTextContainerPadding 
					&& theRect.size.width >= self.containerSize.width - kCHNotebookTextContainerPadding ) {
				
				// preserve the proposed x origin and height
				reproposedRect.origin.x = proposedRect.origin.x;
				reproposedRect.size.height = proposedRect.size.height;
				// maximum available width
				reproposedRect.size.width = self.containerSize.width;
				// offset the height to the next available y-coordinate
				// note that i use the ordered rects and not the merged rects
				reproposedRect.origin.y = PDNextAvailableYCoordinate(orderedRects,0);
				
				// and recursively run the reproposed rect through the same function
				reproposedRect = [self lineFragmentRectForProposedRect:reproposedRect
						sweepDirection:sweepDirection 
						movementDirection:movementDirection
						remainingRect:remainingRect];
				
				requiredModification = YES;
			}
		}
		
		
		if ( !requiredModification ) {
			// only modification thus far is down shift; if we haven't done this:
			//	does the leftmost rect begin at the left edge of the proposed rect, including margin?
			//		YES: reproposed rect from end of leftmost to beginning of next rect or border
			//			 remaining rect is a. zero (border) or b. from end of next rect to border
			//		NO:	 width is from left edge of proposed rect to beginning of first rect
			//			 remaining rect is from end of first rect to beginning of next rect or border
			
			// preserve the proposed y origin and height
			reproposedRect.origin.y = proposedRect.origin.y;
			reproposedRect.size.height = proposedRect.size.height;
			
			NSRect leftmostRect = [[mergedRects objectAtIndex:0] rectValue];
			
			// does the leftmost rect begin at the left edge of the proposed rect, including margin?
			if ( leftmostRect.origin.x <= proposedRect.origin.x + kCHNotebookTextContainerPadding ) {
				
				// reproposed rect from end of leftmost...
				reproposedRect.origin.x = leftmostRect.origin.x + leftmostRect.size.width;
				
				if ( mergedRects.count == 1 ) {
					// ... to the border
					reproposedRect.size.width = self.containerSize.width - reproposedRect.origin.x;
					// zero the remaining rect
					*remainingRect = NSZeroRect;
				}
				else {
					// ... to the beginning of the next rect
					NSRect nextRect = [[mergedRects objectAtIndex:1] rectValue];
					reproposedRect.size.width = nextRect.origin.x - reproposedRect.origin.x;
					// remaining rect is from end of next rect to border
					// preserving y-coordinate and height
					*remainingRect = NSMakeRect(nextRect.origin.x + nextRect.size.width,
												proposedRect.origin.y,
												self.containerSize.width - (nextRect.origin.x + nextRect.size.width),
												proposedRect.size.height);
				}
			}
			else {
				// preserve original x origin
				// width is from left edge of proposed rect to beginning of first rect
				reproposedRect.origin.x = proposedRect.origin.x;
				reproposedRect.size.width = leftmostRect.origin.x - reproposedRect.origin.x;
				
				// remaining rect is from end of first rect to beginning of next rect or border
				if ( mergedRects.count == 1 ) {
					*remainingRect = NSMakeRect(leftmostRect.origin.x + leftmostRect.size.width,
												proposedRect.origin.y,
												self.containerSize.width - (leftmostRect.origin.x + leftmostRect.size.width),
												proposedRect.size.height);
				}
				else {
					NSRect nextRect = [[mergedRects objectAtIndex:1] rectValue];
					*remainingRect = NSMakeRect(leftmostRect.origin.x + leftmostRect.size.width,
												proposedRect.origin.y,
												nextRect.origin.x - (leftmostRect.origin.x + leftmostRect.size.width),
												proposedRect.size.height);
				}
			}
			
			requiredModification = YES;
		}
		
		
		//	at any time if the remaining rect is less than margin, it is zero rect
		if ( remainingRect->size.width <= kCHNotebookTextContainerPadding ) {
			*remainingRect = NSZeroRect;
		}
		
		
		if ( requiredModification ) {
			return reproposedRect;
		}
		else {
			return [super lineFragmentRectForProposedRect:proposedRect 
					sweepDirection:sweepDirection 
					movementDirection:movementDirection 
					remainingRect:remainingRect];	
		}
	}
}

#pragma mark -
#pragma mark Mouse Hit Testing

- (BOOL)containsPoint:(NSPoint)aPoint {
	
	BOOL containsPoint = YES;
	
	for ( NSValue *rectValue in [_layoutClippings objectEnumerator] ) {
		NSRect clippingRect = [rectValue rectValue];
		if ( NSPointInRect(aPoint, clippingRect) ) {
			containsPoint = NO;
			break;
		}
	}
	
	return containsPoint;
}

@end
