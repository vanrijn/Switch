//
//  SWCoreWindowController.m
//  Switch
//
//  Created by Scott Perry on 07/10/13.
//  Copyright © 2013 Scott Perry.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "SWCoreWindowController.h"

#import "NSSet+SWChaining.h"
#import "SWEventTap.h"
#import "SWHUDCollectionView.h"
#import "SWWindow.h"
#import "SWWindowThumbnailView.h"


@interface SWCoreWindowController () <SWHUDCollectionViewDataSource, SWHUDCollectionViewDelegate>

@property (nonatomic, assign, readwrite) BOOL interfaceLoaded;
@property (nonatomic, assign, readonly) NSScreen *screen;
@property (nonatomic, strong, readwrite) SWHUDCollectionView *collectionView;
@property (nonatomic, strong, readonly) NSMutableDictionary *collectionCells;

@end


@implementation SWCoreWindowController

#pragma mark - Initialization

- (id)initWithScreen:(NSScreen *)screen;
{
    BailUnless(self = [super initWithWindow:nil], nil);
    
    _collectionCells = [NSMutableDictionary new];
    _screen = screen;

    Check(![self isWindowLoaded]);
    (void)self.window;
    
    @weakify(self);
    [[SWEventTap sharedService] registerForEventsWithType:kCGEventMouseMoved object:self block:^(CGEventRef event) {
        dispatch_async(dispatch_get_main_queue(), ^{
            @strongify(self);

            NSPoint mouseLocationInWindow = [self private_pointInWindowFromScreen:[NSEvent mouseLocation]];
            if(NSPointInRect([self.collectionView convertPoint:mouseLocationInWindow fromView:nil], [self.collectionView bounds])) {
                NSEvent *mouseEvent = [NSEvent mouseEventWithType:NSMouseMoved location:mouseLocationInWindow modifierFlags:NSAlternateKeyMask timestamp:(NSTimeInterval)0 windowNumber:self.window.windowNumber context:(NSGraphicsContext *)nil eventNumber:0 clickCount:0 pressure:1.0];
                [self.collectionView mouseMoved:mouseEvent];
            }
        });
    }];
    
    return self;
}

- (void)dealloc;
{
    [[SWEventTap sharedService] removeBlockForEventsWithType:kCGEventMouseMoved object:self];
}

#pragma mark - NSWindowController

- (BOOL)isWindowLoaded;
{
    return self.interfaceLoaded;
}

- (void)loadWindow;
{
    SWTimeTask(SWCodeBlock({
        CGRect contentRect = self.screen.frame;
        NSWindow *switcherWindow = [[NSWindow alloc] initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO screen:self.screen];
        switcherWindow.movableByWindowBackground = NO;
        switcherWindow.hasShadow = NO;
        switcherWindow.opaque = NO;
        switcherWindow.backgroundColor = [NSColor clearColor];
        switcherWindow.ignoresMouseEvents = NO;
        switcherWindow.level = NSPopUpMenuWindowLevel;
        self.window = switcherWindow;
        
        CGRect displayRect = [switcherWindow convertRectFromScreen:contentRect];
        SWHUDCollectionView *collectionView = [[SWHUDCollectionView alloc] initWithFrame:displayRect];
        collectionView.dataSource = self;
        collectionView.delegate = self;
        self.collectionView = collectionView;
        
        self.window.contentView = self.collectionView;
        self.interfaceLoaded = YES;
    }), @"Setting up switcher window");
}

#pragma mark - SWCoreWindowController

- (void)updateWindowList:(NSOrderedSet *)windowList;
{
    SWTimeTask(SWCodeBlock({
        // Throw out any cells that aren't needed anymore.
        NSSet *removedWindows = [[NSSet setWithArray:self.collectionCells.allKeys] sw_minusSet:windowList.set];
        [self.collectionCells removeObjectsForKeys:removedWindows.allObjects];

        _windowList = windowList;
        [self.collectionView reloadData];
    }), @"Updating switcher window list");
}

- (void)selectWindow:(SWWindow *)window;
{
    NSUInteger index = [self.windowList indexOfObject:window];

    if (index < self.windowList.count) {
        [self.collectionView selectCellAtIndex:index];
    } else {
        [self.collectionView deselectCell];
    }
}

- (void)disableWindow:(SWWindow *)window;
{
    if (![self.windowList containsObject:window]) { return; }
    
    [self private_thumbnailForWindow:window].active = NO;
}

- (void)enableWindow:(SWWindow *)window;
{
    if (![self.windowList containsObject:window]) { return; }
    
    [self private_thumbnailForWindow:window].active = YES;
}

#pragma mark - SWHUDCollectionViewDataSource

- (CGFloat)HUDCollectionViewMaximumCellSize:(SWHUDCollectionView *)view;
{
    return kNNMaxWindowThumbnailSize;
}

- (NSUInteger)HUDCollectionViewNumberOfCells:(SWHUDCollectionView *)view;
{
    return self.windowList.count;
}

- (NSView *)HUDCollectionView:(SWHUDCollectionView *)view viewForCellAtIndex:(NSUInteger)index;
{
    BailUnless([view isEqual:self.collectionView], [[NSView alloc] initWithFrame:CGRectZero]);
    
    // Boundary method, index may not be in-bounds.
    SWWindow *window = index < self.windowList.count ? self.windowList[index] : nil;
    BailUnless(window, [[NSView alloc] initWithFrame:CGRectZero]);

    if (!self.collectionCells[window]) {
        self.collectionCells[window] = [[SWWindowThumbnailView alloc] initWithFrame:CGRectZero window:window];
    }

    return self.collectionCells[window];
}

#pragma mark - SWHUDCollectionViewDelegate

- (void)HUDCollectionView:(SWHUDCollectionView *)view didSelectCellAtIndex:(NSUInteger)index;
{
    if (!Check(index < self.windowList.count)) {
        index = self.windowList.count - 1;
    }
    id<SWCoreWindowControllerDelegate> delegate = self.delegate;
    [delegate coreWindowController:self didSelectWindow:self.windowList[index]];
}

- (void)HUDCollectionView:(SWHUDCollectionView *)view activateCellAtIndex:(NSUInteger)index;
{
    if (!Check(index < self.windowList.count)) {
        index = self.windowList.count - 1;
    }
    id<SWCoreWindowControllerDelegate> delegate = self.delegate;
    [delegate coreWindowController:self didActivateWindow:self.windowList[index]];
}

- (void)HUDCollectionViewClickOutsideCollection:(SWHUDCollectionView *)view;
{
    id<SWCoreWindowControllerDelegate> delegate = self.delegate;
    [delegate coreWindowControllerDidClickOutsideInterface:self];
}

#pragma mark - Private

- (SWWindowThumbnailView *)private_thumbnailForWindow:(SWWindow *)window;
{
    NSUInteger index = [self.windowList indexOfObject:window];

    if (index < self.windowList.count) {
        id thumb = [self.collectionView cellForIndex:index];

        if (!Check([thumb isKindOfClass:[SWWindowThumbnailView class]])) {
            return nil;
        } else {
            return thumb;
        }
    }

    BailUnless(NO, nil);
}

- (NSPoint)private_pointInWindowFromScreen:(NSPoint)point;
{
    NSRect inputRect = {
        .origin.x = point.x,
        .origin.y = point.y,
        .size.width = 0,
        .size.height = 0
    };

    return [self.window convertRectFromScreen:inputRect].origin;
}

@end
