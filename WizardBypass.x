// WizardBypass - v38 MINIMAL
// Only two patches: anti-tamper NOP + validation bypass
// No class scanning, no BOOL hooks, no NSUserDefaults, no custom UI

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <libkern/OSCacheControl.h>
#import <dlfcn.h>

// ============================================================================
// DELAYED HOOK - runs 3 seconds after launch on main queue
// ============================================================================
static void delayed_hook(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] v38b - delayed hook (binary patch)");
    NSLog(@"[WizardBypass] ========================================");

    // ========================================
    // PATCH 2: Redirect error display -> success display
    // IDA analysis:
    //   sub_B1F7F8 = showError "Invalid" (red circle)
    //   sub_B1F270 = showSuccess "Valid" (green check)
    // Write ARM64 B instruction at error func to jump to success func
    // ========================================
    intptr_t wizard_slide = 0;
    BOOL found_wizard = NO;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "Wizard.framework/Wizard")) {
            wizard_slide = _dyld_get_image_vmaddr_slide(i);
            NSLog(@"[WizardBypass] Wizard.framework slide: 0x%lx", (long)wizard_slide);
            found_wizard = YES;
            break;
        }
    }

    if (found_wizard) {
        uint64_t error_addr   = 0xB1F7F8 + wizard_slide;
        uint64_t success_addr = 0xB1F270 + wizard_slide;

        NSLog(@"[WizardBypass] Error func:   0x%llx", error_addr);
        NSLog(@"[WizardBypass] Success func: 0x%llx", success_addr);

        // ARM64 B instruction: 0x14000000 | (imm26)
        int64_t offset = (int64_t)(success_addr - error_addr);
        int32_t imm26 = (int32_t)(offset / 4) & 0x03FFFFFF;
        uint32_t branch_instr = 0x14000000 | imm26;

        NSLog(@"[WizardBypass] ARM64 B: 0x%08x (offset: %lld)", branch_instr, offset);

        kern_return_t kr = vm_protect(mach_task_self(),
            (vm_address_t)(error_addr & ~0xFFF), 0x1000, FALSE,
            VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);

        if (kr == KERN_SUCCESS) {
            *(uint32_t *)error_addr = branch_instr;
            sys_icache_invalidate((void *)error_addr, 4);
            NSLog(@"[WizardBypass] PATCH 2: error->success redirect ACTIVE");
            vm_protect(mach_task_self(),
                (vm_address_t)(error_addr & ~0xFFF), 0x1000, FALSE,
                VM_PROT_READ | VM_PROT_EXECUTE);
        } else {
            NSLog(@"[WizardBypass] WARNING: vm_protect failed: %d", kr);
        }
    } else {
        NSLog(@"[WizardBypass] WARNING: Wizard.framework not found");
    }

    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] v38 MINIMAL - done. App should run normally.");
    NSLog(@"[WizardBypass] ========================================");
}

// ============================================================================
// CONSTRUCTOR - runs at dylib load time
// ============================================================================
__attribute__((constructor))
static void wizard_bypass_init(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] v38b MINIMAL - init");
    NSLog(@"[WizardBypass] ========================================");

    // PATCH 1: Neutralize drawInMTKView: IMMEDIATELY
    // Must run before game renders first frame (0xDEAD anti-tamper)
    Class metalClass = objc_getClass("AJFADSHFSAJXN");
    if (metalClass) {
        SEL drawSel = sel_registerName("drawInMTKView:");
        Method drawMethod = class_getInstanceMethod(metalClass, drawSel);
        if (drawMethod) {
            IMP nopDraw = imp_implementationWithBlock(^(id self, id view) {
                // NOP — anti-tamper disabled
            });
            method_setImplementation(drawMethod, nopDraw);
            NSLog(@"[WizardBypass] PATCH 1: drawInMTKView: NEUTRALIZED (immediate)");
        } else {
            NSLog(@"[WizardBypass] WARNING: drawInMTKView: not found");
        }
    } else {
        NSLog(@"[WizardBypass] WARNING: AJFADSHFSAJXN not found yet - scheduling retry");
        // If class doesn't exist yet, retry in 0.5s
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            Class mc = objc_getClass("AJFADSHFSAJXN");
            if (mc) {
                SEL ds = sel_registerName("drawInMTKView:");
                Method dm = class_getInstanceMethod(mc, ds);
                if (dm) {
                    IMP nd = imp_implementationWithBlock(^(id self, id view) {});
                    method_setImplementation(dm, nd);
                    NSLog(@"[WizardBypass] PATCH 1: drawInMTKView: NEUTRALIZED (retry)");
                }
            }
        });
    }

    // Schedule binary patch after 3 seconds (Wizard needs to be fully loaded)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        delayed_hook();
    });

    NSLog(@"[WizardBypass] Binary patch scheduled in 3 seconds");
}
