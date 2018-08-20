//
//  ChartTest.m
//  ZKChart
//
//  Created by mac on 2018/8/5.
//  Copyright © 2018年 mac. All rights reserved.
//

#import "ChartTest.h"
#import "KLineData.h"

@interface ChartTest ()<UIScrollViewDelegate>{
    UIView *bgView;
    
    //BaseShapeScaler
    CGFloat shapeWidth;
    CGFloat shapeInterval;
    CGSize contentSize;
}

@property (nonatomic, assign) CGFloat kLineProportion;  ///< 主图占比 默认 .6f

@property (nonatomic, readonly) NSArray <id <KLineAbstract, VolumeAbstract, QueryViewAbstract> > * kLineArray;    ///< k线数组
@property (nonatomic, assign) CGFloat kInterval;    ///< k线之间的间隔

@property (nonatomic, assign) NSInteger kLineCountVisibale;     ///< 一屏幕显示多少根k线     默认60
@property (nonatomic, assign) NSInteger kMaxCountVisibale;      ///< 屏幕最多显示多少k线     默认120
@property (nonatomic, assign) NSInteger kMinCountVisibale;      ///< 屏幕最少显示多少k线     默认20

//手势相关
@property (nonatomic, assign) BOOL isLoadingMore;       ///< 是否在刷新状态
@property (nonatomic, assign) BOOL isWaitPulling;       ///< 是否正在等待刷新

#pragma mark - 缩放手势
@property (nonatomic, assign) CGFloat currentZoom;  ///< 当前缩放比例
@property (nonatomic, assign) CGFloat zoomCenterSpacingLeft;    ///< 缩放中心K线位置距离左边的距离
@property (nonatomic, assign) NSUInteger zoomCenterIndex;     ///< 中心点k线

@end

@implementation ChartTest

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _currentZoom = -.001f;
    _kLineProportion = .6f;
    
    _kLineCountVisibale = 60;
    _kMaxCountVisibale = 120;
    _kMinCountVisibale = 20;
    
    //BaseShapeScaler
    _kInterval = 3;//k线间的距离
    float chartWidth = SCREEN_WIDTH-20;
    float chartHeight = 250;

    shapeInterval = _kInterval;//间隔
    shapeWidth = chartWidth / _kLineCountVisibale - _kInterval;//柱状图宽度

    //数据
    NSData *dataStock = [NSData dataWithContentsOfFile:[self stockWeekDataJsonPath]];
    NSArray *stockJson = [NSJSONSerialization JSONObjectWithData:dataStock options:0 error:nil];
    NSArray <KLineData *> *datas = [[[KLineData arrayForArray:stockJson class:[KLineData class]] reverseObjectEnumerator] allObjects];
    _kLineArray = datas;
    
    //UI
    bgView = [[UIView alloc] init];
    bgView.frame = CGRectMake(10, 100, chartWidth, chartHeight);
    [self.view addSubview:bgView];
    
    _backScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, chartWidth, chartHeight)];
    _backScrollView.showsHorizontalScrollIndicator = NO;
    _backScrollView.showsVerticalScrollIndicator = NO;
    _backScrollView.userInteractionEnabled = NO;
    [bgView addSubview:_backScrollView];
    
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0,chartWidth, chartHeight)];
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.delegate = self;
    [_scrollView.layer addSublayer:self.redVolumLayer];
    [_scrollView.layer addSublayer:self.greenVolumLayer];
    [bgView addSubview:_scrollView];
    //计算scrollview的contentsize
    contentSize = CGSizeMake((shapeInterval + shapeWidth) * _kLineArray.count, chartHeight);
    self.scrollView.contentSize = contentSize;
    self.backScrollView.contentSize = contentSize;
    
    //手势
    UIPinchGestureRecognizer * pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchesViewOnGesturer:)];
    [bgView addGestureRecognizer:pinchGestureRecognizer];
    
    //配置
    self.redVolumLayer.strokeColor = [UIColor redColor].CGColor;
    self.redVolumLayer.fillColor = [UIColor redColor].CGColor;
    self.greenVolumLayer.strokeColor = C_HEXA(0x3ebb3f,1.0).CGColor;
    self.greenVolumLayer.fillColor = C_HEXA(0x3ebb3f,1.0).CGColor;
    
    //确定redVolumLayer 和 greenVolumLayer的frame
    [self setVolumRect:CGRectMake(0, chartHeight*_kLineProportion, contentSize.width, chartHeight*(1-_kLineProportion))];//确定 redVolumLayer greenVolumLayer 的frame
    
    //定标器
    self.volumScaler = [[DBarScaler alloc] init];
    [self.volumScaler setObjAry:_kLineArray
                    getSelector:@selector(ggVolume)];
    self.volumScaler.rect = CGRectMake(0, 0, self.redVolumLayer.gg_width, self.redVolumLayer.gg_height);
    self.volumScaler.barWidth = shapeWidth;//lyh 最窄1?
    
    //更新视图
    [self updateSubLayer];
}
#pragma mark - 更新视图

- (void)updateChart
{
    if (_kLineArray.count == 0) { return; }
    
    //渲染器  花布 颜色等属性pei k
//    [self baseConfigRendererAndLayer];
    
    [self kLineSubLayerRespond];
    
    // 指标层
//    [self updateKLineIndexLayer:_kLineIndexIndex];
//    [self updateVolumIndexLayer:_volumIndexIndex];
}

- (void)kLineSubLayerRespond
{
    [self baseConfigKLineLayer];
    [self updateSubLayer];
}

- (void)baseConfigKLineLayer{
    shapeWidth = bgView.gg_width / _kLineCountVisibale - _kInterval;
    shapeInterval = _kInterval;

    contentSize = CGSizeMake((shapeWidth+shapeInterval)*_kLineArray.count,  self.redVolumLayer.gg_height);
    contentSize.width = contentSize.width < bgView.gg_width ? bgView.gg_width : contentSize.width;
   
    self.scrollView.contentSize = contentSize;
    self.backScrollView.contentSize = contentSize;

    CGRect volumRect = self.volumFrame;
    [self setVolumRect:volumRect];
    
    self.volumScaler.rect = CGRectMake(0, 0, contentSize.width, self.redVolumLayer.gg_height);
    self.volumScaler.barWidth = shapeWidth;
}

#pragma mark - rect

#define INDEX_STRING_INTERVAL   0//12
#define KLINE_VOLUM_INTERVAL    0//15

- (CGRect)volumFrame
{
    CGFloat highMLine = self.minuteLineFrame.size.height;
    CGFloat volumTop = INDEX_STRING_INTERVAL * 2 + highMLine + KLINE_VOLUM_INTERVAL;
    return CGRectMake(0, volumTop, contentSize.width, bgView.frame.size.height - volumTop);

}

- (CGRect)minuteLineFrame
{
    return CGRectMake(0, INDEX_STRING_INTERVAL, bgView.frame.size.width, bgView.frame.size.height * _kLineProportion - INDEX_STRING_INTERVAL);
}

- (NSString *)stockWeekDataJsonPath{
    return [[NSBundle mainBundle] pathForResource:@"week_k_data_60087" ofType:@"json"];
}

#pragma mark - 实时更新
/** 柱状图实时更新 */
- (void)updateVolumLayerWithRange:(NSRange)range
{
    // 计算柱状图最大最小
    CGFloat max = FLT_MIN;
    CGFloat min = FLT_MAX;

    //除100000后得到max
    [_kLineArray getMax:&max min:&min selGetter:@selector(ggVolume) range:range base:0.1];
    
    // 更新成交量
    self.volumScaler.min = 0;
    self.volumScaler.max = max;
    [self.volumScaler updateScalerWithRange:range];//定标器 确定部分参数
    [self updateVolumLayer:range];//用贝塞尔曲线绘图
    
}

#pragma mark --------------------------------

/**
 * 成交量视图是否为红色
 *
 * @parm obj volumScaler.lineObjAry[idx]
 */

- (BOOL)volumIsRed:(id)obj
{
    return [self isRed:obj];
}

/** k线是否为红 */
- (BOOL)isRed:(id <KLineAbstract>)kLineObj
{
    return kLineObj.ggOpen > kLineObj.ggClose;
}


- (void)setFrame:(CGRect)frame
{
    _scrollView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
    _backScrollView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
}
//设置成交量层
- (void)setVolumRect:(CGRect)rect{
    self.redVolumLayer.frame = rect;
    self.greenVolumLayer.frame = rect;
}

/**
 * 视图滚动
 */
- (void)scrollViewContentSizeDidChange
{

    CGPoint contentOffset = self.scrollView.contentOffset;
    
    if (_scrollView.contentOffset.x < 0) {
        
        contentOffset = CGPointMake(0, 0);
    }
    
    if (_scrollView.contentOffset.x + _scrollView.frame.size.width > _scrollView.contentSize.width) {
        
        contentOffset = CGPointMake(_scrollView.contentSize.width - _scrollView.frame.size.width, 0);
    }

    [self.backScrollView setContentOffset:contentOffset];
    
    [self updateSubLayer];

}

#pragma mark - 实时更新

- (void)updateSubLayer
{
    // 计算显示的在屏幕中的k线
    NSInteger index = round(self.scrollView.contentOffset.x / (0+ shapeWidth+shapeInterval));
    NSInteger len = _kLineCountVisibale;
    if (index < 0) index = 0;
    if (index > _kLineArray.count) index = _kLineArray.count;
    if (index + _kLineCountVisibale > _kLineArray.count) { len = _kLineArray.count - index; }

    NSRange range = NSMakeRange(index, len);

    // 更新视图
    [self updateVolumLayerWithRange:range];
}


/**
 * 局部更新成交量
 *
 * range 成交量更新k线的区域, CGRangeMAx(range) <= volumScaler.lineObjAry.count
 */
- (void)updateVolumLayer:(NSRange)range
{
    CGMutablePathRef refRed = CGPathCreateMutable();
    CGMutablePathRef refGreen = CGPathCreateMutable();
    
    for (NSInteger i = range.location; i < NSMaxRange(range); i++) {
        CGRect shape = self.volumScaler.barRects[i];
        NSObject * obj = self.volumScaler.lineObjAry[i];
        [self volumIsRed:obj] ? GGPathAddCGRect(refRed, shape) : GGPathAddCGRect(refGreen, shape);
    }
    
    self.redVolumLayer.path = refRed;
    CGPathRelease(refRed);
    
    self.greenVolumLayer.path = refGreen;
    CGPathRelease(refGreen);
}
#pragma mark - 手势

/** 放大手势 */
-(void)pinchesViewOnGesturer:(UIPinchGestureRecognizer *)recognizer
{
    self.scrollView.scrollEnabled = NO;     // 放大禁用滚动手势
    
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        
        _currentZoom = recognizer.scale;
        
        self.scrollView.scrollEnabled = YES;
    }
    else if (recognizer.state == UIGestureRecognizerStateBegan && _currentZoom != 0.0f) {
        
        recognizer.scale = _currentZoom;

        CGPoint touch1 = [recognizer locationOfTouch:0 inView:bgView];
        CGPoint touch2 = [recognizer locationOfTouch:1 inView:bgView];
        
        // 放大开始记录位置等数据
        CGFloat center_x = (touch1.x + touch2.x) / 2.0f;
        _zoomCenterIndex = [self pointConvertIndex:self.scrollView.contentOffset.x + center_x];
        _zoomCenterSpacingLeft = _zoomCenterIndex*(shapeWidth+shapeInterval) - self.scrollView.contentOffset.x;

    }
    else if (recognizer.state == UIGestureRecognizerStateChanged) {
        
        CGFloat tmpZoom;
        tmpZoom = recognizer.scale / _currentZoom;
        _currentZoom = recognizer.scale;
        NSInteger showNum = round(_kLineCountVisibale / tmpZoom);

        // 避免没必要计算
        if (showNum == _kLineCountVisibale) { return; }
        if (showNum >= _kLineCountVisibale && _kLineCountVisibale == _kMaxCountVisibale) return;
        if (showNum <= _kLineCountVisibale && _kLineCountVisibale == _kMinCountVisibale) return;
        
        // 极大值极小值
        _kLineCountVisibale = showNum;
        _kLineCountVisibale = _kLineCountVisibale < _kMinCountVisibale ? _kMinCountVisibale : _kLineCountVisibale;
        _kLineCountVisibale = _kLineCountVisibale > _kMaxCountVisibale ? _kMaxCountVisibale : _kLineCountVisibale;
        
        [self kLineSubLayerRespond];
        
        // 定位中间的k线
        CGFloat shape_x = (_zoomCenterIndex + .5) * shapeInterval + (_zoomCenterIndex + .5) * shapeWidth;
        CGFloat offsetX = shape_x - _zoomCenterSpacingLeft;
        
        if (offsetX < 0) { offsetX = 0; }
        if (offsetX > self.scrollView.contentSize.width - self.scrollView.frame.size.width) {
            offsetX = self.scrollView.contentSize.width - self.scrollView.frame.size.width;
        }
        self.scrollView.contentOffset = CGPointMake(offsetX, 0);
    }
}

/** 获取点对应的数据 */
- (NSInteger)pointConvertIndex:(CGFloat)x
{
    NSInteger idx = x / (shapeWidth + shapeInterval);
    return idx >= _kLineArray.count ? _kLineArray.count - 1 : idx;

}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self scrollViewContentSizeDidChange];
    
    if (scrollView.contentOffset.x < -40) {
        
        if (!self.isLoadingMore) {

            self.isWaitPulling = YES;
        }
    }
    
    if (self.isWaitPulling &&
        scrollView.contentOffset.x == 0) {

        self.isLoadingMore = YES;
        self.isWaitPulling = NO;
        //横屏用到
//        if (self.RefreshBlock) {
//            self.RefreshBlock();
//        }
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
//    CGFloat minMove = self.kLineScaler.shapeWidth + self.kLineScaler.shapeInterval;
//    self.scrollView.contentOffset = CGPointMake(round(self.scrollView.contentOffset.x / minMove) * minMove, 0);
    [self scrollViewContentSizeDidChange];
}

/** 结束刷新状态 */
- (void)endLoadingState
{
    self.isLoadingMore = NO;
}

#pragma mark - Lazy

GGLazyGetMethod(CAShapeLayer, redVolumLayer);
GGLazyGetMethod(CAShapeLayer, greenVolumLayer);
GGLazyGetMethod(DBarScaler, volumScaler);

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
