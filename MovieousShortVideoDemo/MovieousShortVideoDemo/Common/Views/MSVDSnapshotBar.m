//
//  MSVDSnapshotBar.m
//  MovieousShortVideoDemo
//
//  Created by Chris Wang on 2019/12/11.
//  Copyright © 2019 Movieous Team. All rights reserved.
//

#import "MSVDSnapshotBar.h"
#import "MSVClip+MSVD.h"

// 最多缓存多少张快照，缓存太多会导致内存消耗过多。
#define MaximumSnapshotCount    1000

@interface MSVDSnapshotBarMaskView : UIView

@property (nonatomic, assign) CGFloat leadingTransitionWidth;
@property (nonatomic, assign) CGFloat trailingTransitionWidth;
@property (nonatomic, assign) CGFloat leadingMargin;
@property (nonatomic, assign) CGFloat trailingMargin;

@end

@implementation MSVDSnapshotBarMaskView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = UIColor.clearColor;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    UIBezierPath *path = [UIBezierPath bezierPath];
    // 保证中间距离是 margin
    CGFloat leadingRatio = 1.0 / sin(atan2(self.bounds.size.height, MAX(_leadingMargin, _leadingTransitionWidth) - _leadingMargin));
    CGFloat trailingRatio = 1.0 / sin(atan2(self.bounds.size.height, MAX(_trailingMargin, _trailingTransitionWidth) - _trailingMargin));
    [path moveToPoint:CGPointMake(MAX(_leadingMargin * leadingRatio, _leadingTransitionWidth), 0)];
    [path addLineToPoint:CGPointMake(self.bounds.size.width - _trailingMargin * trailingRatio, 0)];
    [path addLineToPoint:CGPointMake(self.bounds.size.width - MAX(_trailingTransitionWidth, _trailingMargin * trailingRatio), self.bounds.size.height)];
    [path addLineToPoint:CGPointMake(_leadingMargin * leadingRatio, self.bounds.size.height)];
    [path closePath];
    [UIColor.whiteColor setFill];
    [path fill];
}

- (void)setLeadingTransitionWidth:(CGFloat)leadingTransitionWidth {
    _leadingTransitionWidth = leadingTransitionWidth;
    [self setNeedsDisplay];
}

- (void)setTrailingTransitionWidth:(CGFloat)trailingTransitionWidth {
    _trailingTransitionWidth = trailingTransitionWidth;
    [self setNeedsDisplay];
}

- (void)setLeadingMargin:(CGFloat)leadingMargin {
    _leadingMargin = leadingMargin;
    [self setNeedsDisplay];
}

- (void)setTrailingMargin:(CGFloat)trailingMargin {
    _trailingMargin = trailingMargin;
    [self setNeedsDisplay];
}

@end

@interface MSVDSnapshot : NSObject

@property (nonatomic, assign) MovieousTime timestamp;
@property (nonatomic, strong) UIImage *image;

@end

@implementation MSVDSnapshot

@end

static NSNotificationName MSVDSnapshotsCacheNewAvailableNotification = @"MSVDSnapshotsCacheNewAvailableNotification";
static NSString *kMSVDSnapshotsNewSnapshotKey = @"kMSVDSnapshotsNewSnapshotKey";

static NSMutableArray<MSVDSnapshotsCache *> *_snapshotsCachePool;

@interface MSVDSnapshotsCache ()

@property (nonatomic, strong) NSArray<MSVDSnapshot *> *snapshots;

- (void)lockForReading;
- (void)unlockForReading;

@end

@implementation MSVDSnapshotsCache {
    NSMutableArray<MSVDSnapshot *> *_snapshots;
    // 存储所有已经请求过生成且未失败的时间戳，以方便判断是否需要再次请求邻近的时间戳
    NSMutableArray<NSNumber *> *_pendingTimes;
    dispatch_queue_t _snapshotRefreshQueue;
    NSRecursiveLock *_snapshotsLock;
    MSVClip *_clip;
}

+ (instancetype)createSnapshotCacheWithClip:(MSVClip *)clip {
    if (!_snapshotsCachePool) {
        _snapshotsCachePool = [NSMutableArray array];
    }
    for (MSVDSnapshotsCache *snapshotsCache in _snapshotsCachePool) {
        if ([snapshotsCache->_clip isSameSourceWithClip:clip]) {
            return snapshotsCache;
        }
    }
    MSVDSnapshotsCache *snapshotsCache = [[MSVDSnapshotsCache alloc] initWithClip:clip];
    [_snapshotsCachePool addObject:snapshotsCache];
    return snapshotsCache;
}

- (instancetype)initWithClip:(MSVClip *)clip {
    if (self = [super init]) {
        _clip = clip;
        _snapshots = [NSMutableArray array];
        _snapshotsLock = [NSRecursiveLock new];
        _pendingTimes = [NSMutableArray array];
        _snapshotRefreshQueue = dispatch_queue_create("video.movieous.snapshotRefresh", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    [_snapshotsCachePool removeObject:self];
}

- (void)refreshSnapshotsWithSnapshotCount:(NSUInteger)snapshotCount frameInterval:(MovieousTime)frameInterval {
    if (_pendingTimes.count >= MaximumSnapshotCount) {
        return;
    }
    MSVSnapshotGenerator *snapshotGenerator = _clip.snapshotGenerator;
    dispatch_async(_snapshotRefreshQueue, ^{
        NSMutableArray<NSNumber *> *requestedTimes = [NSMutableArray array];
        // 请求快照的最小时间间隔。
        MovieousTime minimumInterval = frameInterval / 2;
        // 决定要生成哪些缺的快照。
        for (int i = 0; i < snapshotCount && self->_pendingTimes.count < MaximumSnapshotCount; i++) {
            MovieousTime pendingTime = frameInterval * i;
            NSInteger indexToInsert = -1;
            if (self->_pendingTimes.count == 0) {
                indexToInsert = 0;
            } else {
                for (int j = 0; j < self->_pendingTimes.count; j++) {
                    MovieousTime timeA = self->_pendingTimes[j].doubleValue;
                    if (j == 0) {
                        if (pendingTime <= timeA) {
                            if (timeA - pendingTime >= minimumInterval) {
                                indexToInsert = 0;
                            } else {
                                break;
                            }
                        }
                    }
                    if (j < self->_pendingTimes.count - 1) {
                        MovieousTime timeB = self->_pendingTimes[j+1].doubleValue;
                        if (pendingTime >= timeA && pendingTime <= timeB) {
                            if (pendingTime - timeA >= frameInterval &&
                                timeB - pendingTime >= frameInterval) {
                                indexToInsert = j + 1;
                            }
                            break;
                        }
                    } else {
                        if (pendingTime - timeA >= minimumInterval) {
                            indexToInsert = j + 1;
                        }
                        break;
                    }
                }
            }
            if (indexToInsert >= 0) {
                [requestedTimes addObject:@(pendingTime)];
                [self->_pendingTimes insertObject:@(pendingTime) atIndex:indexToInsert];
            }
        }
        if (requestedTimes.count > 0) {
            snapshotGenerator.requestedTimeToleranceBefore = minimumInterval;
            snapshotGenerator.requestedTimeToleranceAfter = minimumInterval;
            MovieousWeakSelf
            [snapshotGenerator generateSnapshotsAsynchronouslyForTimes:requestedTimes completionHandler:^(MovieousTime requestedTime, UIImage * _Nullable image, MovieousTime actualTime, MSVSnapshotGeneratorResult result, NSError * _Nullable error) {
                if (!wSelf) {
                    return;
                }
                MovieousStrongSelf
                dispatch_async(strongSelf->_snapshotRefreshQueue, ^{
                    if (error) {
                        // 删掉记录，下次再重新请求。
                        for (int i = 0; i < strongSelf->_pendingTimes.count; i++) {
                            if (fabs(strongSelf->_pendingTimes[i].doubleValue - requestedTime) <= DBL_EPSILON) {
                                [strongSelf->_pendingTimes removeObjectAtIndex:i];
                                break;
                            }
                        }
                        NSLog(@"generate snapshot at %lld failed for: %@", requestedTime, error.localizedDescription);
                        return;
                    }
                    NSInteger indexToInsert = -1;
                    if (strongSelf->_snapshots.count == 0) {
                        indexToInsert = 0;
                    } else {
                        for (int j = 0; j < strongSelf->_snapshots.count; j++) {
                            MovieousTime timeA = strongSelf->_snapshots[j].timestamp;
                            if (j == 0) {
                                if (actualTime <= timeA) {
                                    if (timeA - actualTime >= minimumInterval) {
                                        indexToInsert = 0;
                                    } else {
                                        break;
                                    }
                                }
                            }
                            if (j < strongSelf->_snapshots.count - 1) {
                                MovieousTime timeB = strongSelf->_snapshots[j+1].timestamp;
                                if (actualTime >= timeA && actualTime <= timeB) {
                                    if (actualTime - timeA >= minimumInterval &&
                                        timeB - actualTime >= minimumInterval) {
                                        indexToInsert = j + 1;
                                    }
                                    break;
                                }
                            } else {
                                if (actualTime - timeA >= minimumInterval) {
                                    indexToInsert = j + 1;
                                }
                                break;
                            }
                        }
                    }
                    if (indexToInsert >= 0) {
                        // 更新为实际的时间。
                        for (int i = 0; i < strongSelf->_pendingTimes.count; i++) {
                            if (fabs(strongSelf->_pendingTimes[i].doubleValue - requestedTime) <= DBL_EPSILON) {
                                [strongSelf->_pendingTimes replaceObjectAtIndex:i withObject:@(actualTime)];
                                break;
                            }
                        }
                        MSVDSnapshot *snapshot = [MSVDSnapshot new];
                        snapshot.timestamp = actualTime;
                        snapshot.image = image;
                        [strongSelf->_snapshotsLock lock];
                        [strongSelf->_snapshots insertObject:snapshot atIndex:indexToInsert];
                        [strongSelf->_snapshotsLock unlock];
                        [NSNotificationCenter.defaultCenter postNotificationName:MSVDSnapshotsCacheNewAvailableNotification object:strongSelf userInfo:@{kMSVDSnapshotsNewSnapshotKey: snapshot}];
                    } else {
                        // 删掉。
                        for (int i = 0; i < strongSelf->_pendingTimes.count; i++) {
                            if (fabs(strongSelf->_pendingTimes[i].doubleValue - requestedTime) <= DBL_EPSILON) {
                                [strongSelf->_pendingTimes removeObjectAtIndex:i];
                                break;
                            }
                        }
                    }
                });
            }];
        }
    });
}

- (void)lockForReading {
    [_snapshotsLock lock];
}

- (void)unlockForReading {
    [_snapshotsLock unlock];
}

@end

@implementation MSVDSnapshotBar {
    NSMutableArray<UIImageView *> *_imageViewPool;
    NSMutableArray<UIImageView *> *_visibleImageViews;
    MovieousTime _frameInterval;
    CGRect _lastFrame;
    int _lastStartIndex;
    int _lastEndIndex;
    CGFloat _lastStartPoint;
    BOOL _needRefreshSnapshots;
    UIImage *_image;
    MSVDSnapshotBarMaskView *_maskView;
}

- (instancetype)init {
    if (self = [super init]) {
        _lastStartIndex = -1;
        _lastEndIndex = -1;
        _lastStartPoint = -1;
        self.clipsToBounds = YES;
        _maskView = [[MSVDSnapshotBarMaskView alloc] initWithFrame:self.bounds];
        self.maskView = _maskView;
        [self addObserver:self forKeyPath:@"center" options:NSKeyValueObservingOptionNew context:nil];
        [self addObserver:self forKeyPath:@"bounds" options:NSKeyValueObservingOptionNew context:nil];
    }
    return self;
}

- (instancetype)initWithSnapshotsCache:(MSVDSnapshotsCache *)snapshotsCache timeRange:(MovieousTimeRange)timeRange {
    if (self = [self init]) {
        _snapshotsCache = snapshotsCache;
        _timeRange = timeRange;
        _imageViewPool = [NSMutableArray array];
        _visibleImageViews = [NSMutableArray array];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(newSnapshotAvailable:) name:MSVDSnapshotsCacheNewAvailableNotification object:_snapshotsCache];
    }
    return self;
}

- (instancetype)initWithImage:(UIImage *)image originalWidthWhenLeftPanStarts:(CGFloat)originalWidthWhenLeftPanStarts {
    if (self = [self init]) {
        _image = image;
        _originalWidthWhenLeftPanStarts = originalWidthWhenLeftPanStarts;
        _imageViewPool = [NSMutableArray array];
        _visibleImageViews = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"center"];
    [self removeObserver:self forKeyPath:@"bounds"];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"center"] || [keyPath isEqualToString:@"bounds"]) {
        if (CGRectEqualToRect(_lastFrame, self.frame)) {
            return;
        }
        _lastFrame = self.frame;
        _maskView.frame = self.bounds;
        if (_snapshotsCache || _image) {
            _frameInterval = _timeRange.duration * self.bounds.size.height / self.bounds.size.width;
            [self refreshImageViewsForVisibleArea];
            if (_needRefreshSnapshots) {
                [self refreshSnapshots];
                _needRefreshSnapshots = NO;
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)setNeedRefreshSnapshots {
    _needRefreshSnapshots = YES;
}

- (void)refreshSnapshots {
    if (!_snapshotsCache) {
        return;
    }
    if (!NSThread.currentThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshSnapshots];
        });
        return;
    }
    // 快照边长。
    CGFloat sideLength = self.bounds.size.height;
    NSUInteger snapshotCount = ceil(self.bounds.size.width / sideLength);
    [_snapshotsCache refreshSnapshotsWithSnapshotCount:snapshotCount frameInterval:_frameInterval];
}

- (void)newSnapshotAvailable:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        MSVDSnapshot *snapshot = notification.userInfo[kMSVDSnapshotsNewSnapshotKey];
        CGFloat sideLength = self.bounds.size.height;
        MovieousTime startTime = round(self->_visibleImageViews.firstObject.frame.origin.x / sideLength) * self->_frameInterval;
        MovieousTime endTime = startTime + round(self->_visibleImageViews.firstObject.frame.size.width / sideLength) * self->_frameInterval;
        if (snapshot.timestamp >= startTime - self->_frameInterval && snapshot.timestamp <= endTime + self->_frameInterval) {
            [self updateImagesForVisibleImageViews];
        }
    });
}

- (void)setVisibleArea:(MSVDSnapshotBarVisibleArea)visibleArea {
    _visibleArea = visibleArea;
    [self refreshImageViewsForVisibleArea];
}

- (void)setTimeRange:(MovieousTimeRange)timeRange {
    _timeRange = timeRange;
    if (_snapshotsCache || _image) {
        [self refreshImageViewsForVisibleArea];
    }
}

- (void)refreshImageViewsForVisibleArea {
    if (!NSThread.currentThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self refreshImageViewsForVisibleArea];
        });
        return;
    }
    // 片段全长的起点所在的坐标。
    CGFloat startPoint = 0;
    if (_snapshotsCache) {
        startPoint = -_timeRange.start * self.frame.size.height / _frameInterval;
    } else {
        if (_originalWidthWhenLeftPanStarts > 0) {
            startPoint = self.frame.size.width - _originalWidthWhenLeftPanStarts;
            startPoint -= ceil(startPoint / self.frame.size.height) * self.frame.size.height;
        }
    }
    // 可见的起点和终点相对于全长起点的坐标。
    CGFloat relativeVisibleStart = MAX(self.frame.origin.x, _visibleArea.x) - self.frame.origin.x - startPoint;
    CGFloat relativeVisibleEnd = MIN(self.frame.origin.x + self.frame.size.width, _visibleArea.x + _visibleArea.width) - self.frame.origin.x - startPoint;
    if (relativeVisibleEnd > relativeVisibleStart) {
        int startIndex = floor(relativeVisibleStart / self.frame.size.height);
        int endIndex = floor(relativeVisibleEnd / self.frame.size.height);
        if (_lastStartPoint == startPoint && _lastStartIndex == startIndex && _lastEndIndex == endIndex) {
            return;
        }
        _lastStartPoint = startPoint;
        _lastStartIndex = startIndex;
        _lastEndIndex = endIndex;
        NSMutableArray *visibleImageViews = _visibleImageViews;
        _visibleImageViews = [NSMutableArray array];
        for (int i = startIndex; i <= endIndex; i++) {
            UIImageView *imageView;
            if (visibleImageViews.count > 0) {
                imageView = visibleImageViews.lastObject;
                [visibleImageViews removeLastObject];
            } else if (_imageViewPool.count > 0) {
                imageView = _imageViewPool.lastObject;
                [_imageViewPool removeLastObject];
                [self addSubview:imageView];
            } else {
                imageView = [UIImageView new];
                imageView.clipsToBounds = YES;
                imageView.contentMode = UIViewContentModeScaleAspectFill;
                [self addSubview:imageView];
            }
            [_visibleImageViews addObject:imageView];
            imageView.frame = CGRectMake(startPoint + i * self.frame.size.height, 0, self.frame.size.height, self.frame.size.height);
        }
        for (UIImageView *imageView in visibleImageViews) {
            [imageView removeFromSuperview];
            [_imageViewPool addObject:imageView];
        }
        [self updateImagesForVisibleImageViews];
    }
}

- (void)updateImagesForVisibleImageViews {
    if (!NSThread.currentThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateImagesForVisibleImageViews];
        });
        return;
    }
    if (_snapshotsCache) {
        [_snapshotsCache lockForReading];
        NSArray<MSVDSnapshot *> *snapshots = _snapshotsCache.snapshots;
        if (snapshots.count == 0) {
            [_snapshotsCache unlockForReading];
            return;
        }
        CGFloat startPoint = -_timeRange.start * self.frame.size.height / _frameInterval;
        // 用于存储当前循环到 _snapshot 的第几个项了。
        NSUInteger currentIndex = 0;
        for (int i = 0; i < _visibleImageViews.count; i++) {
            UIImageView *imageView = _visibleImageViews[i];
            MovieousTime desiredTime = _frameInterval * ((imageView.frame.origin.x - startPoint) / imageView.frame.size.height);
            MSVDSnapshot  *snapshot = snapshots[currentIndex];
            if (desiredTime <= snapshot.timestamp || currentIndex == snapshots.count - 1) {
                imageView.image = snapshot.image;
            } else {
                for (NSUInteger j = currentIndex; j < snapshots.count; j++) {
                    MSVDSnapshot *snapshotA = snapshots[j];
                    currentIndex = j;
                    if (j == snapshots.count - 1) {
                        imageView.image = snapshotA.image;
                    } else {
                        MSVDSnapshot *snapshotB = snapshots[j+1];
                        if (desiredTime >= snapshotA.timestamp && desiredTime <= snapshotB.timestamp) {
                            if (desiredTime - snapshotA.timestamp > snapshotB.timestamp - desiredTime) {
                                imageView.image = snapshotB.image;
                            } else {
                                imageView.image = snapshotA.image;
                            }
                            break;
                        }
                    }
                }
            }
        }
        [_snapshotsCache unlockForReading];
    } else {
        for (int i = 0; i < _visibleImageViews.count; i++) {
            UIImageView *imageView = _visibleImageViews[i];
            imageView.image = _image;
        }
    }
}

- (void)setLeadingTransitionWidth:(CGFloat)leadingTransitionWidth {
    _leadingTransitionWidth = leadingTransitionWidth;
    _maskView.leadingTransitionWidth = leadingTransitionWidth;
}

- (void)setTrailingTransitionWidth:(CGFloat)trailingTransitionWidth {
    _trailingTransitionWidth = trailingTransitionWidth;
    _maskView.trailingTransitionWidth = trailingTransitionWidth;
}

- (void)setLeadingMargin:(CGFloat)leadingMargin {
    _leadingMargin = leadingMargin;
    _maskView.leadingMargin = leadingMargin;
}

- (void)setTrailingMargin:(CGFloat)trailingMargin {
    _trailingMargin = trailingMargin;
    _maskView.trailingMargin = trailingMargin;
}

@end
