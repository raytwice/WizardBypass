// WizardBypass v38c - MINIMAL + DYLIB HIDING
// 1. Hide WizardBypass.dylib from image enumeration (anti-tamper bypass)
// 2. NOP drawInMTKView: (anti-tamper in Metal render)
// 3. Binary patch error->success (validation bypass)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <libkern/OSCacheControl.h>
#import <dlfcn.h>
#include "fishhook.h"

// ============================================================================
// DYLIB HIDING - hide WizardBypass.dylib from _dyld image enumeration
// This prevents the anti-tamper from detecting our injection
// ============================================================================

static uint32_t g_hidden_index = UINT32_MAX;
static uint32_t g_real_count = 0;

// Original function pointers
static uint32_t (*orig_dyld_image_count)(void);
static const char* (*orig_dyld_get_image_name)(uint32_t);
static const struct mach_header* (*orig_dyld_get_image_header)(uint32_t);
static intptr_t (*orig_dyld_get_image_vmaddr_slide)(uint32_t);

static uint32_t hooked_dyld_image_count(void) {
    if (g_hidden_index != UINT32_MAX)
        return orig_dyld_image_count() - 1;
    return orig_dyld_image_count();
}

static const char* hooked_dyld_get_image_name(uint32_t idx) {
    if (g_hidden_index != UINT32_MAX && idx >= g_hidden_index)
        return orig_dyld_get_image_name(idx + 1);
    return orig_dyld_get_image_name(idx);
}

static const struct mach_header* hooked_dyld_get_image_header(uint32_t idx) {
    if (g_hidden_index != UINT32_MAX && idx >= g_hidden_index)
        return orig_dyld_get_image_header(idx + 1);
    return orig_dyld_get_image_header(idx);
}

static intptr_t hooked_dyld_get_image_vmaddr_slide(uint32_t idx) {
    if (g_hidden_index != UINT32_MAX && idx >= g_hidden_index)
        return orig_dyld_get_image_vmaddr_slide(idx + 1);
    return orig_dyld_get_image_vmaddr_slide(idx);
}

static void setup_dylib_hiding(void) {
    // Find our dylib index using REAL functions (before hooking)
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "WizardBypass")) {
            g_hidden_index = i;
            NSLog(@"[WizardBypass] Hiding dylib at index %u: %s", i, name);
            break;
        }
    }

    // Hook all dyld enumeration functions
    struct rebinding rebindings[] = {
        {"_dyld_image_count", (void *)hooked_dyld_image_count, (void **)&orig_dyld_image_count},
        {"_dyld_get_image_name", (void *)hooked_dyld_get_image_name, (void **)&orig_dyld_get_image_name},
        {"_dyld_get_image_header", (void *)hooked_dyld_get_image_header, (void **)&orig_dyld_get_image_header},
        {"_dyld_get_image_vmaddr_slide", (void *)hooked_dyld_get_image_vmaddr_slide, (void **)&orig_dyld_get_image_vmaddr_slide},
    };
    rebind_symbols(rebindings, 4);
    NSLog(@"[WizardBypass] Dylib hiding active (hidden index: %u)", g_hidden_index);
}

// ============================================================================
// DELAYED HOOK - binary patch after Wizard fully loads
// ============================================================================
static void delayed_hook(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] v38c - delayed hook (patches)");
    NSLog(@"[WizardBypass] ========================================");

    // PATCH 1: NOP drawInMTKView: (backup — in case it wasn't hooked in constructor)
    Class metalClass = objc_getClass("AJFADSHFSAJXN");
    if (metalClass) {
        SEL drawSel = sel_registerName("drawInMTKView:");
        Method drawMethod = class_getInstanceMethod(metalClass, drawSel);
        if (drawMethod) {
            IMP nopDraw = imp_implementationWithBlock(^(id self, id view) {});
            method_setImplementation(drawMethod, nopDraw);
            NSLog(@"[WizardBypass] PATCH 1: drawInMTKView: NOP'd");
        }
    }

    // PATCH 2: Redirect error->success (IDA-guided binary patch)
    // Find Wizard.framework using ORIGINAL dyld functions (not hooked)
    intptr_t wizard_slide = 0;
    BOOL found = NO;
    uint32_t real_count = orig_dyld_image_count ? orig_dyld_image_count() : _dyld_image_count();
    for (uint32_t i = 0; i < real_count; i++) {
        const char *name = orig_dyld_get_image_name ? orig_dyld_get_image_name(i) : _dyld_get_image_name(i);
        if (name && strstr(name, "Wizard.framework/Wizard")) {
            wizard_slide = orig_dyld_get_image_vmaddr_slide ?
                orig_dyld_get_image_vmaddr_slide(i) : _dyld_get_image_vmaddr_slide(i);
            NSLog(@"[WizardBypass] Wizard.framework slide: 0x%lx", (long)wizard_slide);
            found = YES;
            break;
        }
    }

    if (found) {
        uint64_t error_addr   = 0xB1F7F8 + wizard_slide;  // showError "Invalid"
        uint64_t success_addr = 0xB1F270 + wizard_slide;  // showSuccess "Valid"

        // ARM64 B instruction
        int64_t offset = (int64_t)(success_addr - error_addr);
        int32_t imm26 = (int32_t)(offset / 4) & 0x03FFFFFF;
        uint32_t branch_instr = 0x14000000 | imm26;

        NSLog(@"[WizardBypass] Patching: 0x%llx -> 0x%llx (B 0x%08x)", error_addr, success_addr, branch_instr);

        kern_return_t kr = vm_protect(mach_task_self(),
            (vm_address_t)(error_addr & ~0xFFF), 0x1000, FALSE,
            VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);

        if (kr == KERN_SUCCESS) {
            *(uint32_t *)error_addr = branch_instr;
            sys_icache_invalidate((void *)error_addr, 4);
            NSLog(@"[WizardBypass] PATCH 2: error->success ACTIVE");
            vm_protect(mach_task_self(),
                (vm_address_t)(error_addr & ~0xFFF), 0x1000, FALSE,
                VM_PROT_READ | VM_PROT_EXECUTE);
        } else {
            NSLog(@"[WizardBypass] PATCH 2 FAILED: vm_protect %d", kr);
        }
    }

    NSLog(@"[WizardBypass] v38c done — app should run normally");
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
__attribute__((constructor))
static void wizard_bypass_init(void) {
    NSLog(@"[WizardBypass] ========================================");
    NSLog(@"[WizardBypass] v38c MINIMAL + DYLIB HIDING");
    NSLog(@"[WizardBypass] ========================================");

    // IMMEDIATE: Hide our dylib from anti-tamper detection
    setup_dylib_hiding();

    // IMMEDIATE: NOP drawInMTKView: if class exists
    Class metalClass = objc_getClass("AJFADSHFSAJXN");
    if (metalClass) {
        SEL drawSel = sel_registerName("drawInMTKView:");
        Method drawMethod = class_getInstanceMethod(metalClass, drawSel);
        if (drawMethod) {
            IMP nopDraw = imp_implementationWithBlock(^(id self, id view) {});
            method_setImplementation(drawMethod, nopDraw);
            NSLog(@"[WizardBypass] drawInMTKView: NOP'd (immediate)");
        }
    }

    // DELAYED: Binary patch after 3 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        delayed_hook();
    });

    NSLog(@"[WizardBypass] Init complete — hiding active, patches scheduled");
}
