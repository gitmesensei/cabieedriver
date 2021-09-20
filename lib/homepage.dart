import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:assets_audio_player/assets_audio_player.dart'
    hide NotificationSettings;
import 'package:cabieedriver/navigationdrawercomp/navigationdrawer.dart';
import 'package:cabieedriver/notification_dialog.dart';
import 'package:cabieedriver/progress_dialog.dart';
import 'package:cabieedriver/size_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:ui' as ui;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:slider_button/slider_button.dart';

import 'main.dart';

class MyAppHome extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyAppHome> with TickerProviderStateMixin {
  Completer<GoogleMapController> mapController = Completer();
  Placemark places;
  void _onMapCreated(GoogleMapController controller) async {
    mapController.complete(controller);
    Future.delayed(Duration(milliseconds: 0), () async {
      GoogleMapController controller = await mapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_centerPosition.latitude, _centerPosition.longitude),
            zoom: 16.0,
          ),
        ),
      );
    });
  }

  FirebaseMessaging _messaging;
  String token;
  String rideID;
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  var markerCenter;
  AnimationController _animationController;
  Animation _animation;
  String id;
  bool onStarted = false;
  Animation _animation3;
  Animation _animation2;
  LatLng _centerPosition;
  BitmapDescriptor sourceIcon;
  Position currentLocation;
  var tween = Tween(begin: Offset(0.0, 1.0), end: Offset.zero)
      .chain(CurveTween(curve: Curves.bounceInOut));
  var tween2 = Tween(begin: Offset(0.0, 1.0), end: Offset.zero)
      .chain(CurveTween(curve: Curves.ease));
  var tween3 = Tween(begin: Offset(1.0, 0.0), end: Offset.zero)
      .chain(CurveTween(curve: Curves.ease));
  GeoPoint _destination;
  GeoPoint _location;
  String _destinationName;
  String _locationName;
  String _name;
  String _image;
  String _number;
  double _fare;
  String _paymentMethod;

  @override
  void initState() {
    getMarker();
    registerNotification();
    _loadCurrentUser();
    _animationController = AnimationController(
        duration: Duration(milliseconds: 1500), vsync: this);
    _animation =
        CurvedAnimation(parent: _animationController, curve: Curves.ease);
    _animation2 = Tween(begin: 0.0, end: 1.0).animate(_animationController);
    _animation3 = Tween(begin: 0.0, end: 1.0).animate(_animationController);

    super.initState();
  }

  Future<Position> locateUser() async {
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );
  }

  void _loadCurrentUser() async {
    User user = FirebaseAuth.instance.currentUser;
    setState(() {
      this.id = user.uid.toString();
    });
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))
        .buffer
        .asUint8List();
  }

  getMarker() async {
    final Uint8List markerIcon = await getBytesFromAsset('assets/car.png', 60);
    setState(() {
      sourceIcon = BitmapDescriptor.fromBytes(markerIcon);
    });
  }

  Future<String> getUserLocation2() async {
    currentLocation = await locateUser();
    setState(() {
      _centerPosition =
          LatLng(currentLocation.latitude, currentLocation.longitude);
    });
    return _centerPosition.toString();
  }

  locationMarker() {
    var markerIdVal = 'my location';
    final MarkerId markerId = MarkerId(markerIdVal);
    final Marker marker = Marker(
      markerId: markerId,
      icon: sourceIcon,
      draggable: false,
      zIndex: 2,
      flat: true,
      anchor: Offset(0.5, 0.5),
      infoWindow:
          InfoWindow(title: 'My Location', snippet: _centerPosition.toString()),
      position: LatLng(_centerPosition.latitude, _centerPosition.longitude),
    );
    markers[markerId] = marker;
    markerCenter = marker;
  }

  pauseRides() async {
    await FirebaseFirestore.instance
        .collection('Drivers')
        .doc(id)
        .update({"status": "inactive"});
  }

  updateLocationToDatabase() async {
    await FirebaseFirestore.instance.collection('Drivers').doc(id).update({
      'coords': GeoPoint(_centerPosition.latitude, _centerPosition.longitude),
      "status": "active",
      "token": token
    });
  }

  void registerNotification() async {
    getToken();
    var initialzationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettings =
        InitializationSettings(android: initialzationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
    if (Platform.isAndroid) {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification notification = message.notification;
        AndroidNotification android = message.notification?.android;
        if (notification != null && android != null) {
          flutterLocalNotificationsPlugin.show(
              notification.hashCode,
              notification.title,
              notification.body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  channel.id,
                  channel.name,
                  channel.description,
                  icon: android?.smallIcon,
                ),
              ));
          rideID = message.data['ride_id'];
          getRideDetails(rideID);
          print(rideID);
        }
      });
    } else {
      // 3. On iOS, this helps to take the user permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          RemoteNotification notification = message.notification;
          AndroidNotification android = message.notification?.android;
          if (notification != null && android != null) {
            flutterLocalNotificationsPlugin.show(
                notification.hashCode,
                notification.title,
                notification.body,
                NotificationDetails(
                  android: AndroidNotificationDetails(
                    channel.id,
                    channel.name,
                    channel.description,
                    icon: android?.smallIcon,
                  ),
                ));
            rideID = message.data['ride_id'];
            getRideDetails(rideID);
          }
        });
      } else {
        print('User declined or has not accepted permission');
      }
    }
  }

  getToken() async {
    token = await FirebaseMessaging.instance.getToken();
    setState(() {
      token = token;
    });
    print(token);
  }

  void getRideDetails(String rideID) async {
    if (rideID != null) {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => ProgressDialog("getting details"));

      await FirebaseFirestore.instance
          .collection('RideRequest')
          .doc(rideID)
          .get()
          .then((value) {
        if (value.data() != null) {
          Navigator.pop(context);
          _destination = GeoPoint(value.data()['destination'].latitude,
              value.data()['destination'].longitude);
          _location = GeoPoint(value.data()['location'].latitude,
              value.data()['location'].longitude);
          _destinationName = value.data()['destinationName'];
          _locationName = value.data()['locationName'];
          _name = value.data()['name'];
          _image = value.data()['image'];
          _number = value.data()['phone_number'];
          _fare = value.data()['fare'];
          _paymentMethod = value.data()['payment_mode'];
          showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) => NotificationDialog(
                  _destinationName,
                  _locationName,
                  rideID,
                  _destination,
                  _location,
                  _centerPosition,
                  _fare.round(),
                  _paymentMethod));
        }
      });
    }
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _animationController.dispose();
  }

  @override
  Widget build(BuildContext dialogContext) {
    _animationController.forward();
    SizeConfig().init(context);
    return SafeArea(
      child: Scaffold(
          backgroundColor: Theme.of(context).canvasColor,
          appBar: AppBar(
              automaticallyImplyLeading: false,
              iconTheme: IconThemeData(color: Colors.black, size: 30),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car,
                        color: Colors.black,
                        size: 30,
                      ),
                      SizedBox(
                        width: 10,
                      ),
                      Text(
                        'CABIEE',
                        style: TextStyle(color: Colors.black, letterSpacing: 2),
                      ),
                    ],
                  ),
                ],
              )),
          body: Stack(
            children: <Widget>[
              FutureBuilder<String>(
                  future: getUserLocation2(),
                  builder: (BuildContext context, AsyncSnapshot<String> snap) {
                    if (!snap.hasData) {
                      return Center(
                        child: Container(
                          color: Theme.of(context).canvasColor,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                              SizedBox(
                                height: 5,
                              ),
                              Text('Loading...')
                            ],
                          ),
                        ),
                      );
                    } else if (snap.hasError) {
                      return Center(child: Text('Something went wrong'));
                    }
                    print(snap.data);
                    print(currentLocation.heading);
                    locationMarker();
                    return FadeTransition(
                      opacity: _animation,
                      child: GoogleMap(
                        myLocationButtonEnabled: false,
                        myLocationEnabled: true,
                        mapType: MapType.normal,
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: CameraPosition(
                            target: LatLng(_centerPosition.latitude,
                                _centerPosition.longitude),
                            zoom: 10),
                        markers: Set<Marker>.of(markers.values),
                      ),
                    );
                  }),
              SlideTransition(
                position: _animation3.drive(tween3),
                child: Material(
                  elevation: 10,
                  child: Container(
                      color: Colors.lightBlue,
                      height: SizeConfig.safeBlockVertical * 6,
                      child: Center(
                        child: Text(
                          ' Stay Safe From Covid-19, Our Drivers Follow All Safety\n              Procedures And Regular Sensitisation',
                          style: TextStyle(color: Colors.white),
                        ),
                      )),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: onStarted == false
                      ? Container(
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black12, offset: Offset(2, 4))
                              ]),
                          child: SliderButton(
                              action: () {
                                ///Do something here
                                // Navigator.of(context).pop();
                                updateLocationToDatabase();
                                setState(() {
                                  onStarted = true;
                                });
                              },
                              buttonColor: Colors.amberAccent,
                              backgroundColor: Colors.white,
                              label: Text(
                                "Slide to Activate",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 17),
                              ),
                              icon: Icon(Icons.power_settings_new)),
                        )
                      : Container(
                          padding: EdgeInsets.only(
                              left: 20, right: 20, top: 10, bottom: 10),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black12, offset: Offset(2, 4))
                              ]),
                          // ignore: deprecated_member_use
                          child: RaisedButton.icon(
                            elevation: 0,
                            color: Colors.white,
                            icon: Icon(
                              Icons.pause_circle_filled,
                              size: 50,
                            ),
                            onPressed: () {
                              pauseRides();
                              HapticFeedback.vibrate();
                              setState(() {
                                onStarted = false;
                              });
                            },
                            label: Text(
                              'Pause Rides',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                ),
              )
            ],
          ),
          endDrawer: Drawer(
            child: AppDrawer(),
          )),
    );
  }
}
