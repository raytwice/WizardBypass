#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

// Forward declarations for 8 Ball Pool classes
@interface TableLineView : NSObject
- (void)addLine:(CGPoint)start destination:(CGPoint)end color:(UIColor *)color width:(float)width gradientRatio:(float)ratio drawTips:(BOOL)tips;
- (void)addLine:(CGPoint)start destination:(CGPoint)end color:(UIColor *)color width:(float)width gradientRatio:(float)ratio drawTips:(BOOL)tips blend:(int)blend;
- (void)addLines:(CGPoint *)points numPoints:(int)count color:(UIColor *)color width:(float)width gradientRatio:(float)ratio connectToFirst:(BOOL)connect drawTips:(BOOL)tips;
@end

@interface TableViewV2LineController : NSObject
@property (nonatomic, strong) TableLineView *lineView;
@end

// Physics constants
static const float TABLE_WIDTH = 1000.0f;
static const float TABLE_HEIGHT = 500.0f;
static const float BALL_RADIUS = 15.0f;
static const int MAX_BOUNCES = 5;

// Helper function to calculate ball trajectory with bounces
static NSArray<NSValue *> *calculateTrajectory(CGPoint start, CGPoint direction, int maxBounces) {
    NSMutableArray<NSValue *> *points = [NSMutableArray array];

    CGPoint currentPos = start;
    CGPoint currentDir = direction;

    [points addObject:[NSValue valueWithCGPoint:currentPos]];

    for (int bounce = 0; bounce < maxBounces; bounce++) {
        // Calculate intersection with table boundaries
        float tMin = INFINITY;
        int hitWall = -1; // 0=top, 1=right, 2=bottom, 3=left

        // Check top wall
        if (currentDir.y < 0) {
            float t = (BALL_RADIUS - currentPos.y) / currentDir.y;
            if (t > 0 && t < tMin) {
                tMin = t;
                hitWall = 0;
            }
        }

        // Check bottom wall
        if (currentDir.y > 0) {
            float t = (TABLE_HEIGHT - BALL_RADIUS - currentPos.y) / currentDir.y;
            if (t > 0 && t < tMin) {
                tMin = t;
                hitWall = 2;
            }
        }

        // Check left wall
        if (currentDir.x < 0) {
            float t = (BALL_RADIUS - currentPos.x) / currentDir.x;
            if (t > 0 && t < tMin) {
                tMin = t;
                hitWall = 3;
            }
        }

        // Check right wall
        if (currentDir.x > 0) {
            float t = (TABLE_WIDTH - BALL_RADIUS - currentPos.x) / currentDir.x;
            if (t > 0 && t < tMin) {
                tMin = t;
                hitWall = 1;
            }
        }

        // No collision found, extend to edge
        if (hitWall == -1) {
            CGPoint endPoint = CGPointMake(currentPos.x + currentDir.x * 1000, currentPos.y + currentDir.y * 1000);
            [points addObject:[NSValue valueWithCGPoint:endPoint]];
            break;
        }

        // Calculate bounce point
        CGPoint bouncePoint = CGPointMake(currentPos.x + currentDir.x * tMin, currentPos.y + currentDir.y * tMin);
        [points addObject:[NSValue valueWithCGPoint:bouncePoint]];

        // Update position
        currentPos = bouncePoint;

        // Reflect direction based on wall hit
        if (hitWall == 0 || hitWall == 2) {
            // Top or bottom wall - reflect Y
            currentDir.y = -currentDir.y;
        } else {
            // Left or right wall - reflect X
            currentDir.x = -currentDir.x;
        }

        // Apply damping (energy loss on bounce)
        currentDir.x *= 0.95f;
        currentDir.y *= 0.95f;
    }

    return points;
}

// Hook into TableLineView to extend guidelines
%hook TableLineView

- (void)addLine:(CGPoint)start destination:(CGPoint)end color:(UIColor *)color width:(float)width gradientRatio:(float)ratio drawTips:(BOOL)tips {
    // Call original method
    %orig;

    // Calculate extended trajectory
    CGPoint direction = CGPointMake(end.x - start.x, end.y - start.y);
    float length = sqrtf(direction.x * direction.x + direction.y * direction.y);

    if (length > 0) {
        direction.x /= length;
        direction.y /= length;
    }

    // Get trajectory points with bounces
    NSArray<NSValue *> *trajectoryPoints = calculateTrajectory(end, direction, MAX_BOUNCES);

    // Draw extended lines with different colors for each bounce
    UIColor *colors[] = {
        [UIColor colorWithRed:1.0 green:1.0 blue:0.0 alpha:0.8], // Yellow
        [UIColor colorWithRed:1.0 green:0.5 blue:0.0 alpha:0.7], // Orange
        [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.6], // Red
        [UIColor colorWithRed:0.5 green:0.0 blue:1.0 alpha:0.5], // Purple
        [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.4]  // Blue
    };

    // Draw each segment with decreasing opacity
    for (int i = 0; i < trajectoryPoints.count - 1; i++) {
        CGPoint p1 = [trajectoryPoints[i] CGPointValue];
        CGPoint p2 = [trajectoryPoints[i + 1] CGPointValue];

        UIColor *segmentColor = colors[i % 5];
        float segmentWidth = width * (1.0f - (i * 0.15f)); // Decrease width with each bounce

        %orig(p1, p2, segmentColor, segmentWidth, ratio, NO);
    }
}

- (void)addLine:(CGPoint)start destination:(CGPoint)end color:(UIColor *)color width:(float)width gradientRatio:(float)ratio drawTips:(BOOL)tips blend:(int)blend {
    // Call original
    %orig;

    // Same extended trajectory logic
    CGPoint direction = CGPointMake(end.x - start.x, end.y - start.y);
    float length = sqrtf(direction.x * direction.x + direction.y * direction.y);

    if (length > 0) {
        direction.x /= length;
        direction.y /= length;
    }

    NSArray<NSValue *> *trajectoryPoints = calculateTrajectory(end, direction, MAX_BOUNCES);

    UIColor *colors[] = {
        [UIColor colorWithRed:1.0 green:1.0 blue:0.0 alpha:0.8],
        [UIColor colorWithRed:1.0 green:0.5 blue:0.0 alpha:0.7],
        [UIColor colorWithRed:1.0 green:0.0 blue:0.0 alpha:0.6],
        [UIColor colorWithRed:0.5 green:0.0 blue:1.0 alpha:0.5],
        [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.4]
    };

    for (int i = 0; i < trajectoryPoints.count - 1; i++) {
        CGPoint p1 = [trajectoryPoints[i] CGPointValue];
        CGPoint p2 = [trajectoryPoints[i + 1] CGPointValue];

        UIColor *segmentColor = colors[i % 5];
        float segmentWidth = width * (1.0f - (i * 0.15f));

        %orig(p1, p2, segmentColor, segmentWidth, ratio, NO, blend);
    }
}

%end

// Constructor
%ctor {
    NSLog(@"[8BP Extended Guidelines] Loaded successfully!");
}

