// WizardBypass v51 - CLEAN DIAGNOSTIC BUILD
// Only: auth flag bypass + drawInMTKView NOP + diagnostics
// No forced ObjC calls. Let normal app flow handle the menu.
//
// VULNERABILITY: Wizard stores auth state (byte_1B0B4A9) in writable
// __data segment without integrity checks. Any injected code can flip
// it. The license processor (sub_81E8B0) parses ASN1 cert data and
// writes the config — but the result sits unprotected in memory.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <signal.h>
#import <pthread.h>
#include "fishhook.h"

// ============================================================================
// SIGBUS/SIGSEGV HANDLER — catches anti-tamper 0xDEAD jumps
// ============================================================================
static volatile int g_dead_catches = 0;
static volatile uint64_t g_catch_lr = 0;
static volatile int g_catch_is_main = 0;

static void safe_landing_sleep(void) {
    while (1) { sleep(9999); }
}

static void anti_tamper_handler(int sig, siginfo_t *info, void *context) {
    ucontext_t *uc = (ucontext_t *)context;
    _STRUCT_MCONTEXT64 *mc = uc->uc_mcontext;
    uint64_t pc = mc->__ss.__pc;

    if (pc == 0xDEAD || pc == 0xdead) {
        g_dead_catches++;
        g_catch_lr = mc->__ss.__lr;
        g_catch_is_main = pthread_main_np();

        if (g_catch_is_main) {
            // Main thread: walk FP chain to find safe return
            uint64_t fp = mc->__ss.__fp;
            for (int i = 0; i < 5 && fp > 0x1000; i++) {
                uint64_t *frame = (uint64_t *)fp;
                uint64_t saved_lr = frame[1];
                if (saved_lr > 0x100000000 && saved_lr != 0xDEAD) {
                    mc->__ss.__pc = saved_lr;
                    mc->__ss.__fp = frame[0];
                    mc->__ss.__lr = saved_lr;
                    return;
                }
                fp = frame[0];
            }
            mc->__ss.__pc = (uint64_t)safe_landing_sleep;
            mc->__ss.__lr = (uint64_t)safe_landing_sleep;
        } else {
            mc->__ss.__pc = (uint64_t)safe_landing_sleep;
            mc->__ss.__lr = (uint64_t)safe_landing_sleep;
        }
        return;
    }
}

// ============================================================================
// DYLIB HIDING — hides WizardBypass from _dyld_image enumeration
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
// drawInMTKView NOP — prevents anti-tamper infinite loop
// ============================================================================
static int g_draw_count = 0;

static void setup_draw_nop(void) {
    Class metalClass = objc_getClass("AJFADSHFSAJXN");
    if (!metalClass) {
        NSLog(@"[WizardBypass] drawInMTKView: class not found (ok if not loaded yet)");
        return;
    }
    SEL drawSel = sel_registerName("drawInMTKView:");
    Method drawMethod = class_getInstanceMethod(metalClass, drawSel);
    if (!drawMethod) {
        NSLog(@"[WizardBypass] drawInMTKView: method not found");
        return;
    }
    IMP nopDraw = imp_implementationWithBlock(^(id self, id view) {
        g_draw_count++;
        if (g_draw_count <= 3 || g_draw_count % 5000 == 0) {
            NSLog(@"[WizardBypass] drawInMTKView NOP'd (call #%d)", g_draw_count);
        }
    });
    method_setImplementation(drawMethod, nopDraw);
    NSLog(@"[WizardBypass] drawInMTKView: NOP'd");
}

// ============================================================================
// WATCHDOG — monitors main thread health + reports anti-tamper catches
// ============================================================================
static volatile BOOL g_main_alive = NO;
static int g_last_catches = 0;

static void start_watchdog(intptr_t wizard_slide) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        for (int i = 0; i < 60; i++) {
            sleep(2);
            g_main_alive = NO;
            dispatch_async(dispatch_get_main_queue(), ^{ g_main_alive = YES; });
            sleep(1);

            // Read auth flag live
            uint8_t auth = *((uint8_t *)((uint64_t)wizard_slide + 0x1B0B4A9));

            if (g_main_alive) {
                NSLog(@"[WizardBypass] WATCHDOG tick %d: ALIVE | catches: %d | auth: %d",
                      i, g_dead_catches, auth);
            } else {
                NSLog(@"[WizardBypass] WATCHDOG tick %d: *** BLOCKED *** | catches: %d | auth: %d",
                      i, g_dead_catches, auth);
            }

            if (g_dead_catches > g_last_catches) {
                g_last_catches = g_dead_catches;
                NSLog(@"[WizardBypass] ANTI-TAMPER CATCH #%d (thread: %s, LR: 0x%llx, IDA: 0x%llx)",
                      g_dead_catches,
                      g_catch_is_main ? "MAIN" : "BG",
                      (unsigned long long)g_catch_lr,
                      (unsigned long long)(g_catch_lr - wizard_slide));
            }
        }
        NSLog(@"[WizardBypass] WATCHDOG done (60 ticks)");
    });
}

// ============================================================================
// CONSTRUCTOR
// ============================================================================
__attribute__((constructor))
static void wizard_bypass_init(void) {
    NSLog(@"[WizardBypass] === v52 DIAGNOSTIC + AUTH ENFORCER ===");

    // 1. Signal handler (anti-tamper protection)
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = anti_tamper_handler;
    sa.sa_flags = SA_SIGINFO;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);
    NSLog(@"[WizardBypass] Signal handler installed");

    // 2. Dylib hiding
    setup_dylib_hiding();

    // 3. NOP drawInMTKView (prevent freeze)
    setup_draw_nop();

    // 4. Delayed auth bypass (5s — wait for Wizard to fully load)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[WizardBypass] === DELAYED BYPASS START ===");

        // Find Wizard slide
        intptr_t wizard_slide = 0;
        BOOL found = NO;
        uint32_t count = orig_dyld_image_count ? orig_dyld_image_count() : _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char *name = orig_dyld_get_image_name ? orig_dyld_get_image_name(i) : _dyld_get_image_name(i);
            if (name && strstr(name, "Wizard.framework/Wizard")) {
                wizard_slide = orig_dyld_get_image_vmaddr_slide ?
                    orig_dyld_get_image_vmaddr_slide(i) : _dyld_get_image_vmaddr_slide(i);
                found = YES;
                break;
            }
        }

        if (!found) {
            NSLog(@"[WizardBypass] ERROR: Wizard framework not found!");
            return;
        }

        NSLog(@"[WizardBypass] Wizard slide: 0x%lx", (long)wizard_slide);

        // Set auth flag = 1
        uint8_t *auth_flag = (uint8_t *)((uint64_t)wizard_slide + 0x1B0B4A9);
        NSLog(@"[WizardBypass] byte_1B0B4A9 BEFORE: %d", *auth_flag);
        *auth_flag = 1;
        NSLog(@"[WizardBypass] byte_1B0B4A9 AFTER: %d", *auth_flag);

        // Dump config region
        uint8_t *base = (uint8_t *)((uint64_t)wizard_slide + 0x1B0B470);
        NSLog(@"[WizardBypass] xmmword_1B0B470 dump:");
        NSLog(@"[WizardBypass]   +0x00: %02X %02X %02X %02X %02X %02X %02X %02X",
              base[0], base[1], base[2], base[3], base[4], base[5], base[6], base[7]);
        NSLog(@"[WizardBypass]   +0x38: %02X [%02X] %02X %02X (byte_1B0B4A9 = [%02X])",
              base[0x38], base[0x39], base[0x3A], base[0x3B], base[0x39]);

        // ================================================================
        // AUTH ENFORCER — background timer that keeps byte_1B0B4A9 = 1
        // sub_81E8B0 (license processor) resets it to 0 on every key submit.
        // We run from a BG thread so it works even if main thread is blocked.
        // ================================================================
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            static int enforce_count = 0;
            static int restore_count = 0;
            uint8_t *flag = (uint8_t *)((uint64_t)wizard_slide + 0x1B0B4A9);
            
            NSLog(@"[WizardBypass] AUTH ENFORCER started (50ms interval)");
            while (1) {
                usleep(50000); // 50ms = 20 checks/sec
                if (*flag != 1) {
                    *flag = 1;
                    restore_count++;
                    NSLog(@"[WizardBypass] AUTH ENFORCER: restored byte_1B0B4A9 = 1 (#%d)", restore_count);
                }
                enforce_count++;
                if (enforce_count % 200 == 0) { // Log every 10s
                    NSLog(@"[WizardBypass] AUTH ENFORCER alive (%d checks, %d restores)", 
                          enforce_count, restore_count);
                }
            }
        });

        NSLog(@"[WizardBypass] === BYPASS + ENFORCER ACTIVE ===");

        // Start watchdog
        start_watchdog(wizard_slide);
    });

    NSLog(@"[WizardBypass] === INIT COMPLETE ===");
}
