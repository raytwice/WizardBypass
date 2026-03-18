// WizardBypass v40 - DIAGNOSTIC BUILD
// Goal: find exactly what causes the freeze

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <libkern/OSCacheControl.h>
#import <dlfcn.h>
#import <signal.h>
#import <pthread.h>
#include "fishhook.h"

// ============================================================================
// SIGBUS HANDLER
// ============================================================================
static volatile int g_dead_catches = 0;

// Safe landing — anti-tamper threads get sent here
static void safe_landing_sleep(void) {
    // Keep thread alive but doing nothing forever
    while (1) { sleep(9999); }
}

static void safe_landing_return(void) {
    // Just return — for main thread
    return;
}

static void anti_tamper_handler(int sig, siginfo_t *info, void *context) {
    ucontext_t *uc = (ucontext_t *)context;
    _STRUCT_MCONTEXT64 *mc = uc->uc_mcontext;
    uint64_t pc = mc->__ss.__pc;

    if (pc == 0xDEAD || pc == 0xdead) {
        g_dead_catches++;

        // Check if main thread
        BOOL isMain = pthread_main_np();

        if (isMain) {
            // Main thread: return to safe_landing_return (just returns)
            mc->__ss.__pc = (uint64_t)safe_landing_return;
            mc->__ss.__lr = (uint64_t)safe_landing_return;
        } else {
            // Background thread: send to sleep forever
            mc->__ss.__pc = (uint64_t)safe_landing_sleep;
            mc->__ss.__lr = (uint64_t)safe_landing_sleep;
        }
        return;
    }
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
    if (g_hidden_index != UINT32_MAX) return orig_dyld_image_count() - 1;
    return orig_dyld_image_count();
}
static const char* hooked_dyld_get_image_name(uint32_t idx) {
    if (g_hidden_index != UINT32_MAX && idx >= g_hidden_index) return orig_dyld_get_image_name(idx + 1);
    return orig_dyld_get_image_name(idx);
}
static const struct mach_header* hooked_dyld_get_image_header(uint32_t idx) {
    if (g_hidden_index != UINT32_MAX && idx >= g_hidden_index) return orig_dyld_get_image_header(idx + 1);
    return orig_dyld_get_image_header(idx);
}
static intptr_t hooked_dyld_get_image_vmaddr_slide(uint32_t idx) {
    if (g_hidden_index != UINT32_MAX && idx >= g_hidden_index) return orig_dyld_get_image_vmaddr_slide(idx + 1);
    return orig_dyld_get_image_vmaddr_slide(idx);
}

static void setup_dylib_hiding(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "WizardBypass")) {
            g_hidden_index = i;
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
    NSLog(@"[WizardBypass] Dylib hiding active (idx: %u)", g_hidden_index);
}

// ============================================================================
// WATCHDOG — background thread monitors if main thread is alive
// ============================================================================
static volatile BOOL g_main_thread_alive = NO;

static void start_watchdog(void) {
    // Ping main thread every 2 seconds from background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i < 30; i++) {  // monitor for 60 seconds
            sleep(2);
            g_main_thread_alive = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                g_main_thread_alive = YES;
            });
            sleep(1);  // give main thread 1 second to respond
            if (g_main_thread_alive) {
                NSLog(@"[WizardBypass] WATCHDOG: main thread ALIVE (tick %d, catches: %d)", i, g_dead_catches);
            } else {
                NSLog(@"[WizardBypass] WATCHDOG: *** MAIN THREAD BLOCKED *** (tick %d, catches: %d)", i, g_dead_catches);
            }
        }
    });
}

// ============================================================================
// drawInMTKView: diagnostic hook (log, don't NOP)
// ============================================================================
static int g_draw_count = 0;
static IMP g_orig_drawInMTKView = NULL;

static void setup_draw_diagnostic(void) {
    Class metalClass = objc_getClass("AJFADSHFSAJXN");
    if (!metalClass) {
        NSLog(@"[WizardBypass] DIAG: AJFADSHFSAJXN not found");
        return;
    }
    SEL drawSel = sel_registerName("drawInMTKView:");
    Method drawMethod = class_getInstanceMethod(metalClass, drawSel);
    if (!drawMethod) {
        NSLog(@"[WizardBypass] DIAG: drawInMTKView: method not found");
        return;
    }

    g_orig_drawInMTKView = method_getImplementation(drawMethod);
    IMP nopDraw = imp_implementationWithBlock(^(id self, id view) {
        g_draw_count++;
        if (g_draw_count <= 3 || g_draw_count % 1000 == 0) {
            NSLog(@"[WizardBypass] drawInMTKView NOP'd (call #%d)", g_draw_count);
        }
        // DO NOT call original — it infinite-loops (anti-tamper)
    });
    method_setImplementation(drawMethod, nopDraw);
    NSLog(@"[WizardBypass] drawInMTKView: NOP'd (anti-tamper infinite loop blocked)");
}

// ============================================================================
// DELAYED HOOK
// ============================================================================
static void delayed_hook(void) {
    NSLog(@"[WizardBypass] === DELAYED HOOK START ===");

    // Binary patch
    intptr_t wizard_slide = 0;
    BOOL found = NO;
    uint32_t real_count = orig_dyld_image_count ? orig_dyld_image_count() : _dyld_image_count();
    for (uint32_t i = 0; i < real_count; i++) {
        const char *name = orig_dyld_get_image_name ? orig_dyld_get_image_name(i) : _dyld_get_image_name(i);
        if (name && strstr(name, "Wizard.framework/Wizard")) {
            wizard_slide = orig_dyld_get_image_vmaddr_slide ?
                orig_dyld_get_image_vmaddr_slide(i) : _dyld_get_image_vmaddr_slide(i);
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
            NSLog(@"[WizardBypass] PATCH FAILED: %d", kr);
        }
    }

    NSLog(@"[WizardBypass] About to fake auth token...");
    [[NSUserDefaults standardUserDefaults] setObject:@"premium" forKey:@"auth-token-type"];
    NSLog(@"[WizardBypass] Auth token faked");

    NSLog(@"[WizardBypass] About to create ABVJSMGADJS...");
    Class abvClass = objc_getClass("ABVJSMGADJS");
    if (!abvClass) {
        NSLog(@"[WizardBypass] ERROR: ABVJSMGADJS class not found!");
        return;
    }

    id controller = [[abvClass alloc] init];
    NSLog(@"[WizardBypass] ABVJSMGADJS created: %@", controller);

    if (!controller) {
        NSLog(@"[WizardBypass] ERROR: controller is nil!");
        return;
    }

    // Kill timers BEFORE calling methods
    Ivar timerIvar1 = class_getInstanceVariable(abvClass, "_qmshnfuas");
    Ivar timerIvar2 = class_getInstanceVariable(abvClass, "_nvjsafhsa");
    if (timerIvar1) {
        NSTimer *t = object_getIvar(controller, timerIvar1);
        if (t) [t invalidate];
        object_setIvar(controller, timerIvar1, nil);
        NSLog(@"[WizardBypass] Timer 1 killed");
    }
    if (timerIvar2) {
        NSTimer *t = object_getIvar(controller, timerIvar2);
        if (t) [t invalidate];
        object_setIvar(controller, timerIvar2, nil);
        NSLog(@"[WizardBypass] Timer 2 killed");
    }

    NSLog(@"[WizardBypass] About to call PADSGFNDSAHJ...");
    SEL padSel = sel_registerName("PADSGFNDSAHJ");
    if ([controller respondsToSelector:padSel]) {
        ((void (*)(id, SEL))objc_msgSend)(controller, padSel);
        NSLog(@"[WizardBypass] PADSGFNDSAHJ returned OK");
    } else {
        NSLog(@"[WizardBypass] PADSGFNDSAHJ: does not respond!");
    }

    NSLog(@"[WizardBypass] About to call IKAFHFDSAJ...");
    SEL ikaSel = sel_registerName("IKAFHFDSAJ");
    if ([controller respondsToSelector:ikaSel]) {
        ((void (*)(id, SEL))objc_msgSend)(controller, ikaSel);
        NSLog(@"[WizardBypass] IKAFHFDSAJ returned OK");
    } else {
        NSLog(@"[WizardBypass] IKAFHFDSAJ: does not respond!");
    }

    NSLog(@"[WizardBypass] === DELAYED HOOK COMPLETE ===");
    NSLog(@"[WizardBypass] draws: %d, catches: %d", g_draw_count, g_dead_catches);
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
__attribute__((constructor))
static void wizard_bypass_init(void) {
    NSLog(@"[WizardBypass] === v40 DIAGNOSTIC BUILD ===");

    // Signal handler first
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = anti_tamper_handler;
    sa.sa_flags = SA_SIGINFO;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);
    NSLog(@"[WizardBypass] Signal handler installed");

    // Dylib hiding
    setup_dylib_hiding();

    // Diagnostic hook on drawInMTKView
    setup_draw_diagnostic();

    // Watchdog (background thread)
    start_watchdog();

    // Delayed hook in 3 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        delayed_hook();
    });

    NSLog(@"[WizardBypass] === INIT COMPLETE ===");
}
