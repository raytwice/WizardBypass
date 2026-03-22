// GBDBypass v1 — Set isActivated = 1
// GBDfix.dylib checks _isActivated (0x1440C8) in a 1-second timer.
// Server is supposed to set it to 1. We set it ourselves.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach-o/dyld.h>

__attribute__((constructor))
static void gbd_bypass_init(void) {
    NSLog(@"[GBDBypass] === v1 START ===");
    
    // Wait for GBDfix.dylib to initialize
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        
        // Find GBDfix.dylib slide
        intptr_t gbd_slide = 0;
        BOOL found = NO;
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char *name = _dyld_get_image_name(i);
            if (name && strstr(name, "GBDfix")) {
                gbd_slide = _dyld_get_image_vmaddr_slide(i);
                found = YES;
                NSLog(@"[GBDBypass] GBDfix.dylib found at slide: 0x%lx", (long)gbd_slide);
                break;
            }
        }
        
        if (!found) {
            NSLog(@"[GBDBypass] ERROR: GBDfix.dylib not found!");
            return;
        }
        
        // Set _isActivated = 1 (offset 0x1440C8 in __bss)
        uint8_t *isActivated = (uint8_t *)((uint64_t)gbd_slide + 0x1440C8);
        NSLog(@"[GBDBypass] _isActivated BEFORE: %d", *isActivated);
        *isActivated = 1;
        NSLog(@"[GBDBypass] _isActivated AFTER: %d", *isActivated);
        
        // Keep it set (in case something resets it)
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            while (1) {
                usleep(100000); // 100ms
                if (*isActivated != 1) {
                    *isActivated = 1;
                    NSLog(@"[GBDBypass] _isActivated RESTORED to 1");
                }
            }
        });
        
        NSLog(@"[GBDBypass] === ACTIVATED ===");
    });
}
