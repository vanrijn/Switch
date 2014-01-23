//
//  SWWindowGroup.m
//  Switch
//
//  Created by Scott Perry on 12/24/13.
//  Copyright © 2013 Scott Perry.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "SWWindowGroup.h"

#import "SWApplication.h"
#import "SWWindow.h"


@implementation SWWindowGroup

#pragma mark Initialization

- (instancetype)initWithWindows:(NSOrderedSet *)windows mainWindow:(SWWindow *)mainWindow;
{
    NSParameterAssert([windows containsObject:mainWindow]);

    if (!(self = [super init])) { return nil; }
    
    _windows = [windows copy];
    _mainWindow = mainWindow;
    
    return self;
}

#pragma mark NSObject

- (NSUInteger)hash;
{
    return self.mainWindow.windowID;
}

- (BOOL)isEqual:(id)object;
{
    if (![object isKindOfClass:[SWWindowGroup class]]) {
        return NO;
    }
    
    if (![[object windows] isEqual:self.windows]) {
        return NO;
    }
    
    if (![[object mainWindow] isEqual:self.mainWindow]) {
        return NO;
    }
    
    return YES;
}

- (NSString *)description;
{
    return [NSString stringWithFormat:@"<%u (%@), %lu windows total>", self.mainWindow.windowID, self.mainWindow.name, self.windows.count];
}

- (instancetype)copyWithZone:(NSZone *)zone;
{
    Check(!zone);
    return self;
}

#pragma mark SWWindow

- (SWApplication *)application;
{
    return self.mainWindow.application;
}

- (NSString *)name;
{
    return self.mainWindow.name;
}

- (NSRect)frame;
{
    NSPoint min = self.mainWindow.frame.origin, max = self.mainWindow.frame.origin;
    
    for (SWWindow *window in self.windows) {
        min.x = MIN(min.x, window.frame.origin.x);
        min.y = MIN(min.y, window.frame.origin.y);
        max.x = MAX(max.x, window.frame.origin.x + window.frame.size.width);
        max.y = MAX(max.y, window.frame.origin.y + window.frame.size.height);
    }
    
    return (NSRect){.origin = min, .size.width = max.x - min.x, .size.height = max.y - min.y};
}

#pragma mark SWWindowGroup

- (BOOL)isRelatedToLowerGroup:(SWWindowGroup *)group;
{
    BOOL isSameApp = [self.application isEqual:group.application];
    
    BOOL isSaveDialog = NO;
    for (SWWindow *window in self.windows) {
        #pragma message "Check if the height is 10 or 20 on a retina machine"
        #pragma message "This is liable to catch non-save dialogs as well. Should there be a frame check?"
        if ([window.windowDescription[(__bridge NSString *)kCGWindowAlpha] doubleValue] < 1.0 && window.frame.size.height < 21.0 && self.windows.count > 1) {
            isSaveDialog = YES;
            break;
        }
        
        if ([window.application.name isEqualToString:@"com.apple.security.pboxd"]
        || [window.application.name isEqualToString:@"com.apple.appkit.xpc.openAndSav"])
        {
            isSaveDialog = YES;
            /** XXX: in case of recursive calls, should check to make sure the window that the save dialog refers to is not already included in the group. Example:
             
             (lldb) po [windowGroupList[7] windows]
             {(
             0x6080002268c0 <48051 ((null))>,
             0x608000225be0 <48050 ()>,
             0x608000226900 <48045 (Save)>,
             0x608000226500 <48046 (Save)>,
             0x608000226520 <48043 (Untitled.txt)>
             )}
             
             (lldb) po [((NSOrderedSet *)[windowGroupList[7] windows])[2] application]
             0x6080002268e0 <82769 (com.apple.appkit.xpc.openAndSavePanelService)>
             (lldb) p (NSRect)[((NSOrderedSet *)[windowGroupList[7] windows])[2] frame]
             (NSRect) $8 = (x=222, y=69), (width=489, height=319)

             (lldb) po [((NSOrderedSet *)[windowGroupList[7] windows])[3] application]
             0x608000226560 <82763 (TextEdit)>
             (lldb) p (NSRect)[((NSOrderedSet *)[windowGroupList[7] windows])[3] frame]
             (NSRect) $7 = (x=222, y=69), (width=490, height=319)
             
             (lldb) p (NSRect)[((NSOrderedSet *)[windowGroupList[7] windows])[4] frame]
             (NSRect) $9 = (x=147, y=47), (width=640, height=412)
             
             */
            break;
        }
    }
    
    return isSameApp && isSaveDialog;
}

@end
