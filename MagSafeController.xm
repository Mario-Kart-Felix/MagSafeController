/* MagSafe Controller - Control MagSafe on iOS/iPadOS
 * Copyright (C) 2020 Tomasz Poliszuk
 *
 * MagSafe Controller is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * MagSafe Controller is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with MagSafe Controller. If not, see <https://www.gnu.org/licenses/>.
 */


@interface UIView (MagSafeController)
- (void)setCentersHorizontally:(bool)arg1;
@end

@interface UIImage (MagSafeController)
-(UIImage *)_flatImageWithColor:(UIColor *)color;
@end

@interface CSCoverSheetViewControllerBase : UIViewController
@end
@interface CSChargingViewController : CSCoverSheetViewControllerBase
@end

@interface SBUILegibilityLabel
	@property (getter=isHidden, nonatomic) bool hidden;
@end

@interface CSAccessory : NSObject
@property (nonatomic, retain) UIColor *primaryColor;
@property (nonatomic, retain) UIColor *secondaryColor;
@property (nonatomic) double alignmentPercent;
@end

@interface SBDashBoardViewControllerBase : UIViewController
@end
@interface SBDashBoardChargingViewController : SBDashBoardViewControllerBase
@end

NSString *const domainString = @"com.tomaszpoliszuk.magsafecontroller";
NSUserDefaults *tweakSettings;

static bool enableTweak;

static bool useNative;

static int selectedColor;
static int selectedLowPowerModeColor;

static int blurBackground;

static int boltScale;
static int ringScale;

static bool useSplashEffect;
static bool useChargingRingBackground;

static double lineWidth;

static int labelFontSize;

static double ringScaledWidth;

static double boltScaledWidth;
static double boltScaledHeight;

static double boltSizeWidth = 84;
static double boltSizeHeight = 124;

static double animationDuration = 2.75;

CAMediaTimingFunction * timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];

void TweakSettingsChanged() {
	tweakSettings = [[NSUserDefaults alloc] initWithSuiteName:domainString];

	enableTweak = [([tweakSettings objectForKey:@"enableTweak"] ?: @(YES)) boolValue];

	if (@available(iOS 14.1, *)) {
		useNative = [([tweakSettings objectForKey:@"useNative"] ?: @(YES)) boolValue];
	} else {
		useNative = NO;
	}

	selectedColor = [([tweakSettings valueForKey:@"selectedColor"] ?: @(0)) integerValue];
	selectedLowPowerModeColor = [([tweakSettings valueForKey:@"selectedLowPowerModeColor"] ?: @(1)) integerValue];

	blurBackground = [([tweakSettings valueForKey:@"blurBackground"] ?: @(2)) integerValue];

	boltScale = [([tweakSettings valueForKey:@"boltScale"] ?: @(100)) integerValue];
	ringScale = [([tweakSettings valueForKey:@"ringScale"] ?: @(100)) integerValue];

	useSplashEffect = [([tweakSettings objectForKey:@"useSplashEffect"] ?: @(YES)) boolValue];
	useChargingRingBackground = [([tweakSettings objectForKey:@"useChargingRingBackground"] ?: @(YES)) boolValue];

	labelFontSize = [([tweakSettings valueForKey:@"labelFontSize"] ?: @(24)) integerValue];

	lineWidth = [([tweakSettings valueForKey:@"lineWidth"] ?: @(24)) integerValue];
}

%group native

%hook CSPowerChangeObserver
- (bool)isConnectedToWirelessInternalChargingAccessory {
	bool origValue = %orig;
	if ( enableTweak ) {
		return YES;
	}
	return origValue;
}
- (void)setIsConnectedToWirelessInternalChargingAccessory:(bool)arg1 {
	if ( enableTweak ) {
		arg1 = YES;
	}
	%orig;
}
%end

%hook CSAccessoryConfiguration

- (CGSize)boltSize {
	CGSize origValue = %orig;
	if ( enableTweak ) {
		boltScaledWidth = boltSizeWidth * boltScale / 100;
		boltScaledHeight = boltSizeHeight * boltScale / 100;

		if ( boltScaledWidth > 0 ) {
			origValue.width = boltScaledWidth;
		}
		if ( boltScaledHeight > 0 ) {
			origValue.height = boltScaledHeight;
		}
	}
	return origValue;
}
- (double)ringDiameter {
	double origValue = %orig;
	if ( enableTweak ) {
		ringScaledWidth = 3 * ringScale;
		if ( ringScaledWidth > 0 ) {
			return ringScaledWidth;
		}
	}
	return origValue;
}
- (double)splashRingDiameter {
	double origValue = %orig;
	if ( enableTweak ) {
		if ( !useSplashEffect ) {
			return 0;
		}
		ringScaledWidth = 3 * ringScale;
		if ( ringScaledWidth > 0 ) {
			return ringScaledWidth*2.25;
		}
	}
	return origValue;
}
- (double)lineWidth {
	double origValue = %orig;
	if ( enableTweak ) {
		return lineWidth;
	}
	return origValue;
}

%end

%end

%group simulated

%hook CSChargingViewController
- (void)viewDidLoad {
	%orig;

	UIColor *elementsColor = [UIColor systemGreenColor];

	const bool lowPowerMode = [[NSProcessInfo processInfo] isLowPowerModeEnabled];

	if ( selectedColor == 1 ) {
		elementsColor = [UIColor systemYellowColor];
	} else if ( selectedColor == 2 ) {
		elementsColor = [UIColor systemRedColor];
	}
	if ( lowPowerMode ) {
		if ( selectedLowPowerModeColor == 1 ) {
			elementsColor = [UIColor systemYellowColor];
		} else if ( selectedLowPowerModeColor == 2 ) {
			elementsColor = [UIColor systemRedColor];
		}
	}

	ringScaledWidth = 3 * ringScale;

	boltScaledWidth = boltSizeWidth * boltScale / 100;
	boltScaledHeight = boltSizeHeight * boltScale / 100;

	NSNumber *currentBatteryLevel = [NSNumber numberWithFloat:[UIDevice currentDevice].batteryLevel];

	if ( useSplashEffect ) {
		UIView * splashCircle = [[UIView alloc] init];
		splashCircle.backgroundColor = [UIColor whiteColor];
		splashCircle.frame = CGRectMake(0, 0, ringScaledWidth, ringScaledWidth);
		splashCircle.center = self.view.center;
		splashCircle.layer.cornerRadius = ringScaledWidth/2;
		[self.view addSubview:splashCircle];
		splashCircle.layer.zPosition = 1;

		CAKeyframeAnimation *splashCircleAnimation			= [CAKeyframeAnimation animation];
		splashCircleAnimation.keyPath 						= @"transform.scale";
		splashCircleAnimation.values						= @[ @0, @1, @1.5, @2, @3, @3, @3, @3, @3, @3 ];
		splashCircleAnimation.duration						= animationDuration;
		splashCircleAnimation.timingFunctions				= @[ timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction ];

		CAKeyframeAnimation *splashCircleAnimationOpacity	= [CAKeyframeAnimation animation];
		splashCircleAnimationOpacity.keyPath 				= @"opacity";
		splashCircleAnimationOpacity.values					= @[ @0.25, @0.25, @0.25, @0.125, @0, @0, @0, @0, @0, @0 ];
		splashCircleAnimationOpacity.duration				= animationDuration;
		splashCircleAnimationOpacity.timingFunctions		= @[ timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction ];

		CAAnimationGroup *splashCircleAnimationGroup = [[CAAnimationGroup alloc] init];
		splashCircleAnimationGroup.animations = @[ splashCircleAnimation, splashCircleAnimationOpacity ];
		splashCircleAnimationGroup.duration = animationDuration;

		[splashCircle.layer addAnimation:splashCircleAnimationGroup forKey:@"splashCircleAnimationGroup"];
		splashCircle.layer.opacity = 0;
	}

	if ( boltScale > 0 ) {
		UIView *boltView = [[UIView alloc] initWithFrame:CGRectMake( CGRectGetMidX(self.view.frame)-boltScaledWidth/2, CGRectGetMidY(self.view.frame)-boltScaledHeight/2, boltScaledWidth, boltScaledHeight )];
		UIImage *boltImage = [[UIImage imageWithContentsOfFile:@"/Library/PreferenceBundles/MagSafeControllerSettings.bundle/icons/Bolt.png"] _flatImageWithColor:elementsColor];
		UIImageView *boltImageView = [[UIImageView alloc] initWithImage:boltImage];
		boltImageView.frame = boltView.bounds;

		CAKeyframeAnimation *boltZoomAnimation			= [CAKeyframeAnimation animation];
		boltZoomAnimation.keyPath 						= @"transform.scale";
		boltZoomAnimation.values						= @[ @0, @0, @1, @1, @1, @1, @1, @1, @1, @0 ];
		boltZoomAnimation.timingFunctions				= @[ timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction ];

		CAKeyframeAnimation *boltOpacityAnimation		= [CAKeyframeAnimation animation];
		boltOpacityAnimation.keyPath 					= @"opacity";
		boltOpacityAnimation.values						= @[ @0, @0, @1, @1, @1, @1, @1, @1, @1, @0 ];
		boltOpacityAnimation.timingFunctions			= @[ timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction ];

		CAAnimationGroup *boltAnimationGroup = [[CAAnimationGroup alloc] init];
		boltAnimationGroup.animations = @[ boltZoomAnimation, boltOpacityAnimation ];
		boltAnimationGroup.duration = animationDuration;

		[boltView addSubview:boltImageView];
		[self.view addSubview:boltView];
		boltView.layer.zPosition = 1;
		[boltView.layer addAnimation:boltAnimationGroup forKey:@"boltZoomAnimation"];
		boltView.layer.opacity = 0;
	}



	if ( useChargingRingBackground && ringScale > 0 ) {
		CAShapeLayer *chargingRingBackground	= [CAShapeLayer layer];
		chargingRingBackground.path				= [UIBezierPath bezierPathWithArcCenter:CGPointMake((ringScaledWidth/2), (ringScaledWidth/2)) radius:(ringScaledWidth/2) startAngle:(-M_PI/2) endAngle:(M_PI * 2 - M_PI_2) clockwise:YES].CGPath;
		chargingRingBackground.position			= CGPointMake(CGRectGetMidX(self.view.frame)-(ringScaledWidth/2), CGRectGetMidY(self.view.frame)-(ringScaledWidth/2));
		chargingRingBackground.fillColor		= [UIColor clearColor].CGColor;
		chargingRingBackground.strokeColor		= [UIColor systemGrayColor].CGColor;
		chargingRingBackground.lineWidth		= lineWidth;
		chargingRingBackground.lineCap			= kCALineCapRound;
		chargingRingBackground.lineJoin			= kCALineJoinRound;

		CAKeyframeAnimation *chargingRingStartBackgroundOutAnimation						= [CAKeyframeAnimation animation];
		chargingRingStartBackgroundOutAnimation.keyPath 									= @"strokeStart";
		chargingRingStartBackgroundOutAnimation.values										= @[ @0, @0, @0, @0, @1 ];
		chargingRingStartBackgroundOutAnimation.timingFunctions							= @[ timingFunction, timingFunction, timingFunction, timingFunction ];

		CAKeyframeAnimation *chargingRingEndBackgroundOutAnimation						= [CAKeyframeAnimation animation];
		chargingRingEndBackgroundOutAnimation.keyPath 									= @"strokeEnd";
		chargingRingEndBackgroundOutAnimation.values									= @[ @1, @1, @1, @1, @1 ];
		chargingRingEndBackgroundOutAnimation.timingFunctions							= @[ timingFunction, timingFunction, timingFunction, timingFunction ];

		CAKeyframeAnimation *chargingRingProgressBackgroundLineWidthAnimation		= [CAKeyframeAnimation animation];
		chargingRingProgressBackgroundLineWidthAnimation.keyPath					= @"lineWidth";
		chargingRingProgressBackgroundLineWidthAnimation.values						= @[ @0, [NSNumber numberWithFloat:lineWidth], [NSNumber numberWithFloat:lineWidth], [NSNumber numberWithFloat:lineWidth], [NSNumber numberWithFloat:lineWidth/2] ];
		chargingRingProgressBackgroundLineWidthAnimation.timingFunctions			= @[ timingFunction, timingFunction, timingFunction, timingFunction ];

		CAAnimationGroup *chargingRingBackgroundGroup = [[CAAnimationGroup alloc] init];
		chargingRingBackgroundGroup.animations = @[ chargingRingStartBackgroundOutAnimation, chargingRingEndBackgroundOutAnimation, chargingRingProgressBackgroundLineWidthAnimation ];
		chargingRingBackgroundGroup.duration = animationDuration;

		[self.view.layer addSublayer:chargingRingBackground];

		chargingRingBackground.zPosition = 1;

		[chargingRingBackground addAnimation:chargingRingBackgroundGroup forKey:@"chargingRingBackground"];

		chargingRingBackground.strokeStart = 1;
		chargingRingBackground.strokeEnd = 1;
		chargingRingBackground.lineWidth = lineWidth/2;
	}



	if ( ringScale > 0 ) {
		CAShapeLayer *chargingRingProgress		= [CAShapeLayer layer];
		chargingRingProgress.path				= [UIBezierPath bezierPathWithArcCenter:CGPointMake((ringScaledWidth/2), (ringScaledWidth/2)) radius:(ringScaledWidth/2) startAngle:(-M_PI/2) endAngle:(M_PI * 2 - M_PI_2) clockwise:YES].CGPath;
		chargingRingProgress.position			= CGPointMake(CGRectGetMidX(self.view.frame)-(ringScaledWidth/2), CGRectGetMidY(self.view.frame)-(ringScaledWidth/2));
		chargingRingProgress.fillColor			= [UIColor clearColor].CGColor;
		chargingRingProgress.strokeColor		= elementsColor.CGColor;
		chargingRingProgress.lineWidth			= lineWidth;
		chargingRingProgress.lineCap			= kCALineCapRound;
		chargingRingProgress.lineJoin			= kCALineJoinRound;

		CAKeyframeAnimation *chargingRingProgressAnimation							= [CAKeyframeAnimation animation];
		chargingRingProgressAnimation.keyPath 										= @"strokeEnd";
		chargingRingProgressAnimation.values										= @[ @0, @0, currentBatteryLevel, currentBatteryLevel, @1 ];
		chargingRingProgressAnimation.timingFunctions								= @[ timingFunction, timingFunction, timingFunction, timingFunction ];

		CAKeyframeAnimation *chargingRingProgressOutAnimation						= [CAKeyframeAnimation animation];
		chargingRingProgressOutAnimation.keyPath 									= @"strokeStart";
		chargingRingProgressOutAnimation.values										= @[ @0, @0, @0, @0, @1 ];
		chargingRingProgressOutAnimation.timingFunctions							= @[ timingFunction, timingFunction, timingFunction, timingFunction ];

		CAKeyframeAnimation *chargingRingProgressLineWidthAnimation					= [CAKeyframeAnimation animation];
		chargingRingProgressLineWidthAnimation.keyPath								= @"lineWidth";
		chargingRingProgressLineWidthAnimation.values								= @[ @0, [NSNumber numberWithFloat:lineWidth], [NSNumber numberWithFloat:lineWidth], [NSNumber numberWithFloat:lineWidth], [NSNumber numberWithFloat:lineWidth/2] ];
		chargingRingProgressLineWidthAnimation.timingFunctions						= @[ timingFunction, timingFunction, timingFunction, timingFunction ];

		CAAnimationGroup *group = [[CAAnimationGroup alloc] init];
		group.animations = @[ chargingRingProgressAnimation, chargingRingProgressOutAnimation, chargingRingProgressLineWidthAnimation ];
		group.duration = animationDuration;

		[self.view.layer addSublayer:chargingRingProgress];

		chargingRingProgress.zPosition = 1;


		[chargingRingProgress addAnimation:group forKey:@"chargingRingProgress"];

		chargingRingProgress.strokeStart = 1;
		chargingRingProgress.strokeEnd = 1;
		chargingRingProgress.lineWidth = lineWidth/2;
	}

	if ( labelFontSize > 0 ) {
		UILabel *labelElement = [[UILabel alloc] initWithFrame:CGRectMake( CGRectGetMidX(self.view.frame)-ringScaledWidth/2, CGRectGetMidY(self.view.frame)+ringScaledWidth/2+lineWidth, ringScaledWidth , labelFontSize*1.5 )];
		[labelElement setCentersHorizontally:YES];
		[labelElement setFont:[UIFont systemFontOfSize:labelFontSize weight:normal]];
		[self.view addSubview:labelElement];
		labelElement.layer.zPosition = 1;
		labelElement.textColor = [UIColor whiteColor];
		labelElement.text = [NSString stringWithFormat:@"%.f%% Charged", floor([[UIDevice currentDevice] batteryLevel] * 100)];
	}

	UIVisualEffect *blurEffect;
	blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
	if ( blurBackground == 1 ) {
		blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
	}
	UIVisualEffectView *visualEffectView;
	visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
	visualEffectView.frame = self.view.bounds;
	[self.view addSubview:visualEffectView];
}
%end

%end


%group simulated_old

//	This is awful way but does job for now :|
//	it's repeated everything from simulated group for diferent Class
//	TODO - find out how to call two different classes for different iOS versions in one run

%hook SBDashBoardChargingViewController
- (void)viewDidLoad {
	%orig;

	UIColor *elementsColor = [UIColor systemGreenColor];

	const bool lowPowerMode = [[NSProcessInfo processInfo] isLowPowerModeEnabled];

	if ( selectedColor == 1 ) {
		elementsColor = [UIColor systemYellowColor];
	} else if ( selectedColor == 2 ) {
		elementsColor = [UIColor systemRedColor];
	}
	if ( lowPowerMode ) {
		if ( selectedLowPowerModeColor == 1 ) {
			elementsColor = [UIColor systemYellowColor];
		} else if ( selectedLowPowerModeColor == 2 ) {
			elementsColor = [UIColor systemRedColor];
		}
	}

	ringScaledWidth = 3 * ringScale;

	boltScaledWidth = boltSizeWidth * boltScale / 100;
	boltScaledHeight = boltSizeHeight * boltScale / 100;

	NSNumber *currentBatteryLevel = [NSNumber numberWithFloat:[UIDevice currentDevice].batteryLevel];

	if ( useSplashEffect ) {
		UIView * splashCircle = [[UIView alloc] init];
		splashCircle.backgroundColor = [UIColor whiteColor];
		splashCircle.frame = CGRectMake(0, 0, ringScaledWidth, ringScaledWidth);
		splashCircle.center = self.view.center;
		splashCircle.layer.cornerRadius = ringScaledWidth/2;
		[self.view addSubview:splashCircle];
		splashCircle.layer.zPosition = 1;

		CAKeyframeAnimation *splashCircleAnimation			= [CAKeyframeAnimation animation];
		splashCircleAnimation.keyPath 						= @"transform.scale";
		splashCircleAnimation.values						= @[ @0, @1, @1.5, @2, @3, @3, @3, @3, @3, @3 ];
		splashCircleAnimation.duration						= animationDuration;
		splashCircleAnimation.timingFunctions				= @[ timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction ];

		CAKeyframeAnimation *splashCircleAnimationOpacity	= [CAKeyframeAnimation animation];
		splashCircleAnimationOpacity.keyPath 				= @"opacity";
		splashCircleAnimationOpacity.values					= @[ @0.25, @0.25, @0.25, @0.125, @0, @0, @0, @0, @0, @0 ];
		splashCircleAnimationOpacity.duration				= animationDuration;
		splashCircleAnimationOpacity.timingFunctions		= @[ timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction ];

		CAAnimationGroup *splashCircleAnimationGroup = [[CAAnimationGroup alloc] init];
		splashCircleAnimationGroup.animations = @[ splashCircleAnimation, splashCircleAnimationOpacity ];
		splashCircleAnimationGroup.duration = animationDuration;

		[splashCircle.layer addAnimation:splashCircleAnimationGroup forKey:@"splashCircleAnimationGroup"];
		splashCircle.layer.opacity = 0;
	}

	if ( boltScale > 0 ) {
		UIView *boltView = [[UIView alloc] initWithFrame:CGRectMake( CGRectGetMidX(self.view.frame)-boltScaledWidth/2, CGRectGetMidY(self.view.frame)-boltScaledHeight/2, boltScaledWidth, boltScaledHeight )];
		UIImage *boltImage = [[UIImage imageWithContentsOfFile:@"/Library/PreferenceBundles/MagSafeControllerSettings.bundle/icons/Bolt.png"] _flatImageWithColor:elementsColor];
		UIImageView *boltImageView = [[UIImageView alloc] initWithImage:boltImage];
		boltImageView.frame = boltView.bounds;

		CAKeyframeAnimation *boltZoomAnimation			= [CAKeyframeAnimation animation];
		boltZoomAnimation.keyPath 						= @"transform.scale";
		boltZoomAnimation.values						= @[ @0, @0, @1, @1, @1, @1, @1, @1, @1, @0 ];
		boltZoomAnimation.timingFunctions				= @[ timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction ];

		CAKeyframeAnimation *boltOpacityAnimation		= [CAKeyframeAnimation animation];
		boltOpacityAnimation.keyPath 					= @"opacity";
		boltOpacityAnimation.values						= @[ @0, @0, @1, @1, @1, @1, @1, @1, @1, @0 ];
		boltOpacityAnimation.timingFunctions			= @[ timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction, timingFunction ];

		CAAnimationGroup *boltAnimationGroup = [[CAAnimationGroup alloc] init];
		boltAnimationGroup.animations = @[ boltZoomAnimation, boltOpacityAnimation ];
		boltAnimationGroup.duration = animationDuration;

		[boltView addSubview:boltImageView];
		[self.view addSubview:boltView];
		boltView.layer.zPosition = 1;
		[boltView.layer addAnimation:boltAnimationGroup forKey:@"boltZoomAnimation"];
		boltView.layer.opacity = 0;
	}



	if ( useChargingRingBackground && ringScale > 0 ) {
		CAShapeLayer *chargingRingBackground	= [CAShapeLayer layer];
		chargingRingBackground.path				= [UIBezierPath bezierPathWithArcCenter:CGPointMake((ringScaledWidth/2), (ringScaledWidth/2)) radius:(ringScaledWidth/2) startAngle:(-M_PI/2) endAngle:(M_PI * 2 - M_PI_2) clockwise:YES].CGPath;
		chargingRingBackground.position			= CGPointMake(CGRectGetMidX(self.view.frame)-(ringScaledWidth/2), CGRectGetMidY(self.view.frame)-(ringScaledWidth/2));
		chargingRingBackground.fillColor		= [UIColor clearColor].CGColor;
		chargingRingBackground.strokeColor		= [UIColor systemGrayColor].CGColor;
		chargingRingBackground.lineWidth		= lineWidth;
		chargingRingBackground.lineCap			= kCALineCapRound;
		chargingRingBackground.lineJoin			= kCALineJoinRound;

		CAKeyframeAnimation *chargingRingStartBackgroundOutAnimation						= [CAKeyframeAnimation animation];
		chargingRingStartBackgroundOutAnimation.keyPath 									= @"strokeStart";
		chargingRingStartBackgroundOutAnimation.values										= @[ @0, @0, @0, @0, @1 ];
		chargingRingStartBackgroundOutAnimation.timingFunctions							= @[ timingFunction, timingFunction, timingFunction, timingFunction ];

		CAKeyframeAnimation *chargingRingEndBackgroundOutAnimation						= [CAKeyframeAnimation animation];
		chargingRingEndBackgroundOutAnimation.keyPath 									= @"strokeEnd";
		chargingRingEndBackgroundOutAnimation.values									= @[ @1, @1, @1, @1, @1 ];
		chargingRingEndBackgroundOutAnimation.timingFunctions							= @[ timingFunction, timingFunction, timingFunction, timingFunction ];

		CAKeyframeAnimation *chargingRingProgressBackgroundLineWidthAnimation		= [CAKeyframeAnimation animation];
		chargingRingProgressBackgroundLineWidthAnimation.keyPath					= @"lineWidth";
		chargingRingProgressBackgroundLineWidthAnimation.values						= @[ @0, [NSNumber numberWithFloat:lineWidth], [NSNumber numberWithFloat:lineWidth], [NSNumber numberWithFloat:lineWidth], [NSNumber numberWithFloat:lineWidth/2] ];
		chargingRingProgressBackgroundLineWidthAnimation.timingFunctions			= @[ timingFunction, timingFunction, timingFunction, timingFunction ];

		CAAnimationGroup *chargingRingBackgroundGroup = [[CAAnimationGroup alloc] init];
		chargingRingBackgroundGroup.animations = @[ chargingRingStartBackgroundOutAnimation, chargingRingEndBackgroundOutAnimation, chargingRingProgressBackgroundLineWidthAnimation ];
		chargingRingBackgroundGroup.duration = animationDuration;

		[self.view.layer addSublayer:chargingRingBackground];

		chargingRingBackground.zPosition = 1;

		[chargingRingBackground addAnimation:chargingRingBackgroundGroup forKey:@"chargingRingBackground"];

		chargingRingBackground.strokeStart = 1;
		chargingRingBackground.strokeEnd = 1;
		chargingRingBackground.lineWidth = lineWidth/2;
	}



	if ( ringScale > 0 ) {
		CAShapeLayer *chargingRingProgress		= [CAShapeLayer layer];
		chargingRingProgress.path				= [UIBezierPath bezierPathWithArcCenter:CGPointMake((ringScaledWidth/2), (ringScaledWidth/2)) radius:(ringScaledWidth/2) startAngle:(-M_PI/2) endAngle:(M_PI * 2 - M_PI_2) clockwise:YES].CGPath;
		chargingRingProgress.position			= CGPointMake(CGRectGetMidX(self.view.frame)-(ringScaledWidth/2), CGRectGetMidY(self.view.frame)-(ringScaledWidth/2));
		chargingRingProgress.fillColor			= [UIColor clearColor].CGColor;
		chargingRingProgress.strokeColor		= elementsColor.CGColor;
		chargingRingProgress.lineWidth			= lineWidth;
		chargingRingProgress.lineCap			= kCALineCapRound;
		chargingRingProgress.lineJoin			= kCALineJoinRound;

		CAKeyframeAnimation *chargingRingProgressAnimation							= [CAKeyframeAnimation animation];
		chargingRingProgressAnimation.keyPath 										= @"strokeEnd";
		chargingRingProgressAnimation.values										= @[ @0, @0, currentBatteryLevel, currentBatteryLevel, @1 ];
		chargingRingProgressAnimation.timingFunctions								= @[ timingFunction, timingFunction, timingFunction, timingFunction ];

		CAKeyframeAnimation *chargingRingProgressOutAnimation						= [CAKeyframeAnimation animation];
		chargingRingProgressOutAnimation.keyPath 									= @"strokeStart";
		chargingRingProgressOutAnimation.values										= @[ @0, @0, @0, @0, @1 ];
		chargingRingProgressOutAnimation.timingFunctions							= @[ timingFunction, timingFunction, timingFunction, timingFunction ];

		CAKeyframeAnimation *chargingRingProgressLineWidthAnimation					= [CAKeyframeAnimation animation];
		chargingRingProgressLineWidthAnimation.keyPath								= @"lineWidth";
		chargingRingProgressLineWidthAnimation.values								= @[ @0, [NSNumber numberWithFloat:lineWidth], [NSNumber numberWithFloat:lineWidth], [NSNumber numberWithFloat:lineWidth], [NSNumber numberWithFloat:lineWidth/2] ];
		chargingRingProgressLineWidthAnimation.timingFunctions						= @[ timingFunction, timingFunction, timingFunction, timingFunction ];

		CAAnimationGroup *group = [[CAAnimationGroup alloc] init];
		group.animations = @[ chargingRingProgressAnimation, chargingRingProgressOutAnimation, chargingRingProgressLineWidthAnimation ];
		group.duration = animationDuration;

		[self.view.layer addSublayer:chargingRingProgress];

		chargingRingProgress.zPosition = 1;


		[chargingRingProgress addAnimation:group forKey:@"chargingRingProgress"];

		chargingRingProgress.strokeStart = 1;
		chargingRingProgress.strokeEnd = 1;
		chargingRingProgress.lineWidth = lineWidth/2;
	}

	if ( labelFontSize > 0 ) {
		UILabel *labelElement = [[UILabel alloc] initWithFrame:CGRectMake( CGRectGetMidX(self.view.frame)-ringScaledWidth/2, CGRectGetMidY(self.view.frame)+ringScaledWidth/2+lineWidth, ringScaledWidth , labelFontSize*1.5 )];
		[labelElement setCentersHorizontally:YES];
		[labelElement setFont:[UIFont systemFontOfSize:labelFontSize weight:normal]];
		[self.view addSubview:labelElement];
		labelElement.layer.zPosition = 1;
		labelElement.textColor = [UIColor whiteColor];
		labelElement.text = [NSString stringWithFormat:@"%.f%% Charged", floor([[UIDevice currentDevice] batteryLevel] * 100)];
	}

	UIVisualEffect *blurEffect;
	blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
	if ( blurBackground == 1 ) {
		blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
	}
	UIVisualEffectView *visualEffectView;
	visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
	visualEffectView.frame = self.view.bounds;
	[self.view addSubview:visualEffectView];
}
%end
%end

%hook _SingleBatteryChargingView
-(void)_layoutBattery {
	%orig;
	MSHookIvar<UIView *>(self, "_batteryContainerView").hidden = YES;
	MSHookIvar<UIView *>(self, "_batteryBlurView").hidden = YES;
	MSHookIvar<UIView *>(self, "_batteryFillView").hidden = YES;
	MSHookIvar<UILabel *>(self, "_chargePercentLabel").hidden = YES;
}
%end


%ctor {
	TweakSettingsChanged();
	CFNotificationCenterAddObserver(
		CFNotificationCenterGetDarwinNotifyCenter(),
		NULL,
		(CFNotificationCallback)TweakSettingsChanged,
		CFSTR("com.tomaszpoliszuk.magsafecontroller.settingschanged"),
		NULL,
		CFNotificationSuspensionBehaviorDeliverImmediately
	);
	if ( enableTweak ) {
		if ( useNative ) {
			%init(native);
		} else {
			Class _singleBatteryChargingViewClass;
			if (@available(iOS 13, *)) {
				%init(simulated);
				_singleBatteryChargingViewClass = %c(_CSSingleBatteryChargingView);
			} else {
				%init(simulated_old);
				_singleBatteryChargingViewClass = %c(_SBLockScreenSingleBatteryChargingView);
			}
			%init(_SingleBatteryChargingView=_singleBatteryChargingViewClass);
		}
	}
}
