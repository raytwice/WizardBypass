// WizardBypass v39 - SIGBUS HANDLER + DYLIB HIDING + PATCHES
// Ultimate defense: catch 0xDEAD crash and survive it

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <libkern/OSCacheControl.h>
#import <dlfcn.h>
#import <signal.h>
#include "fishhook.h"

// ============================================================================
// SIGBUS HANDLER — catches 0xDEAD anti-tamper and survives
// ============================================================================

static volatile int g_dead_catches = 0;

static void anti_tamper_handler(int sig, siginfo_t *info, void *context) {
    ucontext_t *uc = (ucontext_t *)context;
    _STRUCT_MCONTEXT64 *mc = uc->uc_mcontext;

    uint64_t pc = mc->__ss.__pc;

    if (pc == 0xDEAD || pc == 0xdead) {
        g_dead_catches++;

        // Walk FP chain to find a valid return address
        uint64_t fp = mc->__ss.__fp;

        // Try up to 5 frames to find a valid LR
        for (int i = 0; i < 5 && fp > 0x1000; i++) {
            uint64_t *frame = (uint64_t *)fp;
            uint64_t saved_fp = frame[0];
            uint64_t saved_lr = frame[1];

            if (saved_lr > 0x100000000 && saved_lr != 0xDEAD) {
                // Found a valid return address — resume there
                mc->__ss.__pc = saved_lr;
                mc->__ss.__fp = saved_fp;
                mc->__ss.__sp = fp + 16;
                mc->__ss.__lr = saved_lr;
                return; // resume execution
            }
            fp = saved_fp;
        }

        // Last resort: skip to a safe spot — just return
        // Set PC to a RET instruction gadget (we'll create one)
        // For now, just try the outermost frame
        mc->__ss.__pc = mc->__ss.__lr;
        if (mc->__ss.__pc == 0 || mc->__ss.__pc == 0xDEAD) {
            // Can't recover — but at least we tried
            _exit(0); // clean exit instead of crash
        }
    }
}

static void install_signal_handler(void) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = anti_tamper_handler;
    sa.sa_flags = SA_SIGINFO;
    sigemptyset(&sa.sa_mask);

    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL); // also catch SIGSEGV for 0xDEAD

    NSLog(@"[WizardBypass] SIGBUS/SIGSEGV handler installed (0xDEAD catcher)");
}

// ============================================================================
// DYLIB HIDING
// ============================================================================

static uint32_t g_hidden_index = UINT32_MAX;

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
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "WizardBypass")) {
            g_hidden_index = i;
            NSLog(@"[WizardBypass] Hiding dylib at index %u", i);
            break;
        }
    }

    struct rebinding rebindings[] = {
        {"_dyld_image_count", (void *)hooked_dyld_image_count, (void **)&orig_dyld_image_count},
        {"_dyld_get_image_name", (void *)hooked_dyld_get_image_name, (void **)&orig_dyld_get_image_name},
        {"_dyld_get_image_header", (void *)hooked_dyld_get_image_header, (void **)&orig_dyld_get_image_header},
        {"_dyld_get_image_vmaddr_slide", (void *)hooked_dyld_get_image_vmaddr_slide, (void **)&orig_dyld_get_image_vmaddr_slide},
    };
    rebind_symbols(rebindings, 4);
    NSLog(@"[WizardBypass] Dylib hiding active");
}

// ============================================================================
// DELAYED HOOK — binary patch
// ============================================================================
static void delayed_hook(void) {
    NSLog(@"[WizardBypass] v39 delayed hook — applying binary patch");

    // drawInMTKView: NOT NOP'd — signal handler catches 0xDEAD if needed
    // NOP'ing it freezes the UI since it's also the render loop

    // Binary patch error->success
    intptr_t wizard_slide = 0;
    BOOL found = NO;
    uint32_t real_count = orig_dyld_image_count ? orig_dyld_image_count() : _dyld_image_count();
    for (uint32_t i = 0; i < real_count; i++) {
        const char *name = orig_dyld_get_image_name ? orig_dyld_get_image_name(i) : _dyld_get_image_name(i);
        if (name && strstr(name, "Wizard.framework/Wizard")) {
            wizard_slide = orig_dyld_get_image_vmaddr_slide ?
                orig_dyld_get_image_vmaddr_slide(i) : _dyld_get_image_vmaddr_slide(i);
            NSLog(@"[WizardBypass] Wizard slide: 0x%lx", (long)wizard_slide);
            found = YES;
            break;
        }
    }

    if (found) {
        uint64_t error_addr   = 0xB1F7F8 + wizard_slide;
        uint64_t success_addr = 0xB1F270 + wizard_slide;

        int64_t offset = (int64_t)(success_addr - error_addr);
        int32_t imm26 = (int32_t)(offset / 4) & 0x03FFFFFF;
        uint32_t branch_instr = 0x14000000 | imm26;

        kern_return_t kr = vm_protect(mach_task_self(),
            (vm_address_t)(error_addr & ~0xFFF), 0x1000, FALSE,
            VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);

        if (kr == KERN_SUCCESS) {
            *(uint32_t *)error_addr = branch_instr;
            sys_icache_invalidate((void *)error_addr, 4);
            NSLog(@"[WizardBypass] PATCH: error->success ACTIVE");
            vm_protect(mach_task_self(),
                (vm_address_t)(error_addr & ~0xFFF), 0x1000, FALSE,
                VM_PROT_READ | VM_PROT_EXECUTE);
        } else {
            NSLog(@"[WizardBypass] PATCH FAILED: vm_protect %d", kr);
        }
    }

    NSLog(@"[WizardBypass] v39b ready (anti-tamper catches: %d)", g_dead_catches);

    // ========================================
    // PHASE 2: Trigger Wizard UI initialization
    // Without this, the app freezes waiting for server
    // ========================================

    // Fake auth token
    [[NSUserDefaults standardUserDefaults] setObject:@"premium" forKey:@"auth-token-type"];
    NSLog(@"[WizardBypass] Faked auth-token-type -> premium");

    // Create Wizard controller and trigger init
    Class abvClass = objc_getClass("ABVJSMGADJS");
    if (abvClass) {
        id controller = [[abvClass alloc] init];
        if (controller) {
            NSLog(@"[WizardBypass] Created ABVJSMGADJS: %@", controller);

            // Call PADSGFNDSAHJ (platform init)
            SEL padSel = sel_registerName("PADSGFNDSAHJ");
            if ([controller respondsToSelector:padSel]) {
                ((void (*)(id, SEL))objc_msgSend)(controller, padSel);
                NSLog(@"[WizardBypass] Called PADSGFNDSAHJ");
            }

            // Call IKAFHFDSAJ (show UI)
            SEL ikaSel = sel_registerName("IKAFHFDSAJ");
            if ([controller respondsToSelector:ikaSel]) {
                ((void (*)(id, SEL))objc_msgSend)(controller, ikaSel);
                NSLog(@"[WizardBypass] Called IKAFHFDSAJ");
            }
        }
    } else {
        NSLog(@"[WizardBypass] WARNING: ABVJSMGADJS not found");
    }
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
__attribute__((constructor))
static void wizard_bypass_init(void) {
    NSLog(@"[WizardBypass] v39 — SIGBUS HANDLER + DYLIB HIDING");

    // FIRST: Install signal handler (catches ANY 0xDEAD jump)
    install_signal_handler();

    // SECOND: Hide our dylib
    setup_dylib_hiding();

    // drawInMTKView: left alone — signal handler catches 0xDEAD if it fires
    NSLog(@"[WizardBypass] drawInMTKView: NOT NOP'd (signal handler protects)");

    // DELAYED: Binary patch
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        delayed_hook();
    });

    NSLog(@"[WizardBypass] Init complete — all defenses active");
}
