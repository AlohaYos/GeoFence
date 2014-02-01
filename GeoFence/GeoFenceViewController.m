//
//  GeoFenceViewController.m
//  GeoFence
//
//  Copyright (c) 2014 Newton Japan. All rights reserved.
//

#import "GeoFenceViewController.h"
#import "WebViewController.h"

#pragma mark - GeoFence distance

#define FENCE_1		100.0
#define FENCE_2		500.0
#define FENCE_3		1000.0

#pragma mark - Annotations

@interface CenterAnnotation : NSObject <MKAnnotation>
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@end

@implementation CenterAnnotation

- (id)initWithCoordinate:(CLLocationCoordinate2D)coord {
	if( nil != (self = [super  init]) ){
		self.coordinate = coord;
	}
	return self;
}

@end

@interface CenterAnnotationView : MKAnnotationView
@end

@implementation CenterAnnotationView
- (id)initWithAnnotation:(id <MKAnnotation>)annotation reuseIdentifier:(NSString*)reuseIdentifier
{
	self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
	if( self ){
		UIImage* image = [UIImage imageNamed:@"target"];
		self.frame = CGRectMake(self.frame.origin.x,self.frame.origin.y,image.size.width,image.size.height);
		self.image = image;
	}
	return self;
}
@end


#pragma mark - GeoFenceViewController

@interface GeoFenceViewController ()

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UISwitch *fenceSwitch;

@end

@implementation GeoFenceViewController {
	BOOL				_didLoadData;
	CLLocationManager	*_locationManager;
	BOOL				_showingWebPage;
	WebViewController	*_webVC;
	NSNumber			*_webMajorNumber;
	NSNumber			*_webMinorNumber;

	CLLocationCoordinate2D _centerLocation;
	CenterAnnotation	*_centerAnnotation;
	CLCircularRegion	*_regionNearby;
	CLCircularRegion	*_regionBlock;
	CLCircularRegion	*_regionTown;

	NSUUID				*_uuid;
	CLBeaconRegion		*_beaconRegion;
    NSMutableArray		*_beacons;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	_didLoadData = NO;
	[self loadData];
	
	_showingWebPage = NO;

	_locationManager = [[CLLocationManager alloc] init];
	_locationManager.delegate = self;
	_locationManager.desiredAccuracy = kCLLocationAccuracyBest;
	_locationManager.distanceFilter = kCLDistanceFilterNone;
	[_locationManager startUpdatingLocation];

	_uuid = [[NSUUID alloc] initWithUUIDString:@"E2C56DB5-DFFB-48D2-B060-D0F5A71096E0"];
	_beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:_uuid identifier:[_uuid UUIDString]];
}

- (void)viewDidAppear:(BOOL)animated {

	if(_didLoadData) {
		MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(_centerLocation, (FENCE_3*3.0), (FENCE_3*3.0));
		[_mapView setRegion:region animated:YES];
		
		[self setGeofenceAt:_centerLocation];
		_fenceSwitch.on = YES;
		[self monitoring:YES];
	}else{
		MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(_mapView.userLocation.location.coordinate, (FENCE_3*3.0), (FENCE_3*3.0));
		[_mapView setRegion:region animated:YES];
		_fenceSwitch.on = NO;
	}
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - GeoFence job

- (void)setGeofenceAt:(CLLocationCoordinate2D)geofenceCenter {

	[_mapView removeOverlays:_mapView.overlays];

	_centerLocation = geofenceCenter;
	
	MKCircle *_fenceRange1 = [MKCircle circleWithCenterCoordinate:_centerLocation radius:FENCE_1];
	MKCircle *_fenceRange2 = [MKCircle circleWithCenterCoordinate:_centerLocation radius:FENCE_2];
	MKCircle *_fenceRange3 = [MKCircle circleWithCenterCoordinate:_centerLocation radius:FENCE_3];

	[_mapView addOverlay:_fenceRange1 level:MKOverlayLevelAboveRoads];
	[_mapView addOverlay:_fenceRange2 level:MKOverlayLevelAboveRoads];
	[_mapView addOverlay:_fenceRange3 level:MKOverlayLevelAboveRoads];

	_regionNearby = [[CLCircularRegion alloc] initWithCenter:_fenceRange1.coordinate radius:_fenceRange1.radius identifier:@"nearby"];
	_regionNearby.notifyOnEntry = YES;
	_regionNearby.notifyOnExit  = YES;
	_regionBlock  = [[CLCircularRegion alloc] initWithCenter:_fenceRange2.coordinate radius:_fenceRange2.radius identifier:@"nextBlock"];
	_regionBlock.notifyOnEntry = YES;
	_regionBlock.notifyOnExit  = YES;
	_regionTown = [[CLCircularRegion alloc] initWithCenter:_fenceRange3.coordinate radius:_fenceRange3.radius identifier:@"nextTown"];
	_regionTown.notifyOnEntry = YES;
	_regionTown.notifyOnExit  = YES;
}

- (void)monitoring:(BOOL)flag {
	
	if(flag == YES) {
		[_locationManager requestStateForRegion:_regionNearby];

		[_locationManager startMonitoringForRegion:_regionNearby];
		[_locationManager startMonitoringForRegion:_regionBlock];
		[_locationManager startMonitoringForRegion:_regionTown];
	}
	else {
		NSArray *regions = [[_locationManager monitoredRegions] allObjects];
		for (int i = 0; i < [regions count]; i++) {
			[_locationManager stopMonitoringForRegion:[regions objectAtIndex:i]];
		}
	}
}

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region{
	
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    NSLog(@"%@",error);
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
	
	if(region.radius == _regionNearby.radius) {
		if(state == CLRegionStateInside) {
			[_locationManager startRangingBeaconsInRegion:_beaconRegion];
			NSLog(@"startRangingBeaconsInRegion");
		}
		if(state == CLRegionStateOutside) {
			[_locationManager stopRangingBeaconsInRegion:_beaconRegion];
			NSLog(@"stopRangingBeaconsInRegion");
		}
	}
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
	NSLog(@"Enter region");
	
	NSString *alertStr;
	
	if([region.identifier isEqualToString:@"nextTown"]) {
		alertStr = [NSString stringWithFormat:@"ジオフェンス%.0fm内に入りました", FENCE_3];
		[self openWebPageMajor:[NSNumber numberWithInt:5] minor:[NSNumber numberWithInt:6]];
		NSLog(@"nextTown : Inside");
	}
	if([region.identifier isEqualToString:@"nextBlock"]) {
		alertStr = [NSString stringWithFormat:@"ジオフェンス%.0fm内に入りました", FENCE_2];
		[self openWebPageMajor:[NSNumber numberWithInt:5] minor:[NSNumber numberWithInt:5]];
		NSLog(@"nextBlock : Inside");
	}
	if([region.identifier isEqualToString:@"nearby"]) {
		alertStr = [NSString stringWithFormat:@"ジオフェンス%.0fm内に入りました", FENCE_1];
		[self openWebPageMajor:[NSNumber numberWithInt:5] minor:[NSNumber numberWithInt:4]];
		NSLog(@"nearby : Inside");
	}
	
	if([alertStr length] > 0) {
		UILocalNotification *notification = [[UILocalNotification alloc] init];
		notification.alertBody = alertStr;
		notification.soundName = UILocalNotificationDefaultSoundName;
		[[UIApplication sharedApplication] cancelAllLocalNotifications];
		[[UIApplication sharedApplication] presentLocalNotificationNow:notification];
	}
}


- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
	NSLog(@"Exit region");
	
	NSString *alertStr;
	
	if([region.identifier isEqualToString:@"nearby"]) {
		alertStr = [NSString stringWithFormat:@"ジオフェンス%.0fmから外に出ました", FENCE_1];
		[self openWebPageMajor:[NSNumber numberWithInt:5] minor:[NSNumber numberWithInt:1]];
		NSLog(@"nearby : Outside");
	}
	if([region.identifier isEqualToString:@"nextBlock"]) {
		alertStr = [NSString stringWithFormat:@"ジオフェンス%.0fmから外に出ました", FENCE_2];
		[self openWebPageMajor:[NSNumber numberWithInt:5] minor:[NSNumber numberWithInt:2]];
		NSLog(@"nextBlock : Outside");
	}
	if([region.identifier isEqualToString:@"nextTown"]) {
		alertStr = [NSString stringWithFormat:@"ジオフェンス%.0fmから外に出ました", FENCE_3];
		[self openWebPageMajor:[NSNumber numberWithInt:5] minor:[NSNumber numberWithInt:3]];
		NSLog(@"nextTown : Outside");
	}
	
	if([alertStr length] > 0) {
		UILocalNotification *notification = [[UILocalNotification alloc] init];
		notification.alertBody = alertStr;
		notification.soundName = UILocalNotificationDefaultSoundName;
		[[UIApplication sharedApplication] cancelAllLocalNotifications];
		[[UIApplication sharedApplication] presentLocalNotificationNow:notification];
	}
}

#pragma mark - Beacon job

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
	static int immediateBeaconMajor = -1;
	static int immediateBeaconMinor = -1;
	
	BOOL immediateItem = NO;
	for(CLBeacon *beacon in beacons) {
		if(beacon.proximity == CLProximityImmediate) {
			immediateItem = YES;
			if((immediateBeaconMajor != [beacon.major intValue])||(immediateBeaconMinor != [beacon.minor intValue])) {
				immediateBeaconMajor = [beacon.major intValue];
				immediateBeaconMinor = [beacon.minor intValue];

				[self openWebPageMajor:[NSNumber numberWithInt:5] minor:[NSNumber numberWithInt:10]];
				UILocalNotification *notification = [[UILocalNotification alloc] init];
				notification.alertBody = @"ビーコンを検出しました";
				notification.soundName = UILocalNotificationDefaultSoundName;

				[[UIApplication sharedApplication] cancelAllLocalNotifications];
				[[UIApplication sharedApplication] presentLocalNotificationNow:notification];
			}
			break;
		}
	}
	
	if([beacons count] > 0) {
		if(immediateItem == NO) {
			immediateBeaconMajor = -1;
			immediateBeaconMinor = -1;
			[self closeWebPage];
		}
	}
}

#pragma mark - Map job

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id < MKOverlay >)overlay {
	
	MKCircleRenderer *renderer = [[MKCircleRenderer alloc] initWithCircle:(MKCircle*)overlay];
	
	renderer.strokeColor = [[UIColor redColor] colorWithAlphaComponent:0.5];
	renderer.lineWidth = 1.0;
	renderer.fillColor = [[UIColor redColor] colorWithAlphaComponent:0.2];
	
	return (MKOverlayRenderer*)renderer;
}

- (MKAnnotationView *)mapView:(MKMapView *)theMapView viewForAnnotation:(id <MKAnnotation>)annotation {
	
	if ([annotation isKindOfClass:[MKUserLocation class]])
		return nil;
	
	if ([annotation isKindOfClass:[CenterAnnotation class]]) {
		MKAnnotationView* annotationView = [_mapView  dequeueReusableAnnotationViewWithIdentifier:@"CenterAnnotation"];
		if( annotationView ){
			annotationView.annotation = annotation;
		}
		else{
			annotationView = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"CenterAnnotation"];
		}
		annotationView.image = [UIImage imageNamed:@"target"];
		return annotationView;
	}
	
	return nil;
}

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated {
	if(_centerAnnotation){
		[_mapView removeAnnotation:_centerAnnotation];
	}
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
	
	if(_centerAnnotation){
		_centerAnnotation.coordinate = _mapView.region.center;
	}
	else {
		_centerAnnotation = [[CenterAnnotation alloc] initWithCoordinate:_mapView.region.center];
	}
	
	[_mapView addAnnotation:_centerAnnotation];

	NSLog(@"%f,%f", _mapView.region.center.latitude, _mapView.region.center.longitude);
}


#pragma mark - Web job

-(void)openWebPageMajor:(NSNumber *)majorNumber minor:(NSNumber *)minorNumber
{
	if(_showingWebPage == NO) {
		_showingWebPage = YES;
		_webMajorNumber = majorNumber;
		_webMinorNumber = minorNumber;
		[self performSegueWithIdentifier:@"showWebPage" sender:self];
		NSLog(@"Show web page of %02d-%02d", [majorNumber intValue], [minorNumber intValue]);
	}
	else {
		[_webVC loadWebPageMajor:majorNumber minor:minorNumber];
	}

	[NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(closeWebPage) userInfo:Nil repeats:NO];
}

-(void)closeWebPage
{
	if(_showingWebPage == YES) {
		[self dismissViewControllerAnimated:YES completion:nil];
		_showingWebPage = NO;
		NSLog(@"Hide web page");
	}
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ( [[segue identifier] isEqualToString:@"showWebPage"] ) {
        WebViewController *nextViewController = [segue destinationViewController];
		_webVC = nextViewController;
        nextViewController.majorNumber = _webMajorNumber;
        nextViewController.minorNumber = _webMinorNumber;
    }
}

#pragma mark - Save/Load data

- (void)saveData {
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  [NSNumber numberWithDouble:_centerLocation.latitude], @"latitude",
						  [NSNumber numberWithDouble:_centerLocation.longitude], @"longitude",
						  nil
						  ];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:dict forKey:@"GeofenceData"];
}

- (void)loadData {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *dict = [defaults dictionaryForKey:@"GeofenceData"];
	if(dict) {
		_didLoadData = YES;
		_centerLocation = CLLocationCoordinate2DMake([[dict valueForKey:@"latitude"] doubleValue], [[dict valueForKey:@"longitude"] doubleValue]);
	}
}


- (IBAction)fenceSwitchValueChanged:(id)sender {
	UISwitch *sw = sender;
	[self monitoring:sw.on];
}

- (IBAction)fenceCenterButtonPushed:(id)sender {
	
	[self setGeofenceAt:_mapView.region.center];
	[self saveData];

	if(_fenceSwitch.on) {
		[self monitoring:NO];
		[self monitoring:YES];
	}
}

@end
