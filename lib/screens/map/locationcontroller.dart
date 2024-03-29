
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:takeeazy_customer/model/takeeazyapis/meta/metamodel.dart';
import 'package:takeeazy_customer/screens/bottomnav/bottonnav.dart';
import 'package:takeeazy_customer/screens/controller/textcontroller.dart';
import 'package:takeeazy_customer/main.dart';
import 'package:takeeazy_customer/model/base/exception.dart';
import 'package:takeeazy_customer/model/base/networkcall.dart';
import 'package:takeeazy_customer/model/caching/runtimecaching.dart';
import 'package:takeeazy_customer/model/dialog/dialogservice.dart';
import 'package:takeeazy_customer/model/googleapis/geocoding/address.dart';
import 'package:takeeazy_customer/model/googleapis/geocoding/geocodingservices.dart';
import 'package:takeeazy_customer/model/googleapis/placeautocomplete/autocompservices.dart';
import 'package:takeeazy_customer/model/googleapis/placeautocomplete/places.dart';
import 'package:takeeazy_customer/model/googleapis/placedetails/placedetails.dart';
import 'package:takeeazy_customer/model/navigator/navigatorservice.dart';
import 'package:takeeazy_customer/model/takeeazyapis/meta/meta.dart';
import 'package:takeeazy_customer/model/base/caching.dart';


enum LocationStatus{
  Fetched,
  Failed,
  Fetching,
  Denied,
  Done
}

class PositionController with ChangeNotifier{
  Position _position;
  Position get position => _position;
  set position(p){
    if(_position != p){
      _position = p;
      notifyListeners();
    }
  }

  void notify(){
    notifyListeners();
  }
}

class ListStatusController with ChangeNotifier{
  bool _listOpen = false;
  bool get listOpen => _listOpen;
  set listOpen(bool open){
    _listOpen = open;
    notifyListeners();
  }
}

class SearchController with ChangeNotifier{
  bool _isSearching=false;
  bool get isSearching=>_isSearching;
  set isSearching(bool s){
    if(s!=_isSearching){
      _isSearching = s;
      notifyListeners();
    }
  }
}

class AddressListController with ChangeNotifier {
  List<Places> _addresses = List();

  List<Places> get addresses => _addresses;

  set addresses(List<Places> a) {
    _addresses = a;
    notifyListeners();
  }
}

class LocationStatusController with ChangeNotifier {
  LocationStatus _locationStatus = LocationStatus.Fetching;

  get locationStatus => _locationStatus;

  set _newLocationStatus(v){
    if(v!=_locationStatus){
      _locationStatus = v;
      notifyListeners();
    }
  }
}

class CustomFocusNode extends FocusNode{
  ListStatusController _listStatusController;
  set listStatusController(ListStatusController lsc){
    _listStatusController = lsc;
  }

  @override
  void requestFocus([FocusNode node]) {
    _listStatusController.listOpen=true;
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      super.requestFocus(node);
    });

  }

}


class LocationController{
  String currentAddress="";
  List<String> containers =List();
  bool liveLocationRequired = true;
  final _dialogService = DialogService();
  final TextController city = TextController();
  final TextEditingController addressLine = TextEditingController();
  final ListStatusController listStatusController = ListStatusController();
  final AddressListController listController = AddressListController();
  final PositionController positionController = PositionController();
  final LocationStatusController locationStatusController = LocationStatusController();
  final ValueNotifier<bool> searchController = ValueNotifier<bool>(false);

  final CustomFocusNode focusNode = CustomFocusNode();

  final ValueNotifier<bool> serviceableArea = ValueNotifier<bool>(false);



  void reSyncValues(){
    print("Resyncing Values $currentAddress");
    addressLine.text = currentAddress;
  }


 void selectAddress(Places place) async{
    TEResponse response= await PlaceDetails.getPlaceDetails(place.id);
    locationStatusController._newLocationStatus = LocationStatus.Fetching;
    Address address = await response.response;
    positionController.position = Position(latitude: address.latLng.latitude , longitude: address.latLng.longitude);
    city.text = address.subLocality??address.town??address.state;
    listStatusController.listOpen = false;
    focusNode.unfocus();
 }


  TEResponse response;
  Future getLocationFromAddress() async{
    if(response!=null){
      response.dispose();
    }
    searchController.value = true;
    if(positionController._position!=null){
      AutocompleteServices.getPlaces(addressLine.text, longitude: positionController._position.longitude, latitude: positionController._position.latitude).then((response) async{
        Predictions predictions = await response.response;
        if(predictions!=null) {
          listController.addresses = predictions.predictions;
          searchController.value = false;
        }});
    }else{
      AutocompleteServices.getPlaces(addressLine.text).then((response) async{
        Predictions predictions = await response.response;
        if(predictions!=null) {
          listController.addresses = predictions.predictions;
          searchController.value = false;
        }});
    }

  }

  Future getMetaData() async {
    print("Fetching Meta Info");
    liveLocationRequired =false;
    locationStatusController._newLocationStatus = LocationStatus.Fetching;
    TEResponse response = await Meta.getMetaInfo(
        longitude: positionController.position.longitude,
        latitude: positionController.position.latitude);
    response.response.then((metaModel) {
      city.text = metaModel.city.cityName;
      serviceableArea.value = true;
      containers = metaModel.city.containers;
      print("Serviceable Area");
      storeValues();
      HomeNavigator.currentPageIndex=0;
      NavigatorService.rootNavigator.popAndPushNamed(TERoutes.bottomnav);
      locationStatusController._newLocationStatus = LocationStatus.Fetched;
    }).catchError((e){
      print("ERROR " + e.toString());
      if (e is ResponseException) {
        print("NonServiceable Area");
        serviceableArea.value= false;
        storeValues();
        HomeNavigator.currentPageIndex=0;
        NavigatorService.rootNavigator.popAndPushNamed(TERoutes.bottomnav);
        locationStatusController._newLocationStatus = LocationStatus.Fetched;
      }
    });
    print("Fetched Meta Info");
  }

  Future getAddress() async {

    TEResponse response = await GeocodingServices.getAddress(positionController.position.latitude, positionController.position.longitude);

      response.response.then((addressResults) {
        print(addressResults);
        print("Received address");
        print(addressResults.addresses);
        if(addressResults.addresses.length>0){
          print("Updating Values");
          city.text = addressResults.addresses[0].subLocality??addressResults.addresses[0].town??addressResults.addresses[0].state;
          addressLine.text = addressResults.addresses[0].formattedAddress;
          currentAddress = addressLine.text;
        }
        locationStatusController._newLocationStatus = LocationStatus.Fetched;
      }).catchError((e){
        print(e.toString());
        if(e is SocketException){
          _dialogService.openDialog(
              title: "No Internet Connection",
              content: "App needs internet connection to search locations",
              actions: [
                ActionHolder(title: "Okay", onPressed: (){})
              ]);
          locationStatusController._newLocationStatus = LocationStatus.Failed;
        }});
  }

  Future getLocationData() async {
    try {
      positionController.position = await Geolocator.getCurrentPosition();
      print(positionController.position.toString() + " getLocationData");
    } catch (e) {
      print("Failed " + e.toString());
      locationStatusController._newLocationStatus = LocationStatus.Denied;
    }
  }

  Future requestLocationAccess() async {
   listStatusController.listOpen = false;
    print("Requesting Access");
    if ((await Geolocator.checkPermission()) ==
        LocationPermission.deniedForever) {
      await _dialogService.openDialog(
          title: "Grant location permissions",
          content: "App needs location permissions to get the current location",
          actions: [
            ActionHolder(title: "Cancel", onPressed: (){}),
            ActionHolder(title: "Open Settings",
                onPressed: Geolocator.openLocationSettings)
          ]
      );
    } else {
      //LocationPermission result = await Geolocator.requestPermission();
    //  if (result == LocationPermission.always ||
      //    result == LocationPermission.whileInUse) {
        locationStatusController._newLocationStatus = LocationStatus.Fetching;
        await getLocationData();
        locationStatusController._newLocationStatus = LocationStatus.Fetched;
      }
    //}
  }


  void storeValues(){
    print("Saving ${city.text} ${serviceableArea.value}");
    Map data = {
      'city': city.text,
      'ser': serviceableArea.value,
      'lat': positionController.position.latitude.toString(),
      'lng': positionController.position.longitude.toString(),
      'addressLine': currentAddress,
      'containers': containers
    };
    storeData(data, "City");
    RuntimeCaching.city = city.text;
    RuntimeCaching.serviceableArea = serviceableArea.value;
    RuntimeCaching.lat = positionController.position.latitude.toString();
    RuntimeCaching.lng = positionController.position.longitude.toString();
    RuntimeCaching.containers = containers;
 }

}


