import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ultimate_alarm_clock/app/data/models/user_model.dart';
import 'package:ultimate_alarm_clock/app/data/providers/secure_storage_provider.dart';
import 'package:ultimate_alarm_clock/app/utils/constants.dart';
import 'package:ultimate_alarm_clock/app/utils/utils.dart';
import 'package:weather/weather.dart';
import 'package:latlong2/latlong.dart';
import 'package:fl_location/fl_location.dart';

class SettingsController extends GetxController {
  final _secureStorageProvider = SecureStorageProvider();
  final apiKey = TextEditingController();
  final currentPoint = LatLng(0, 0).obs;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  late GoogleSignInAccount? googleSignInAccount;
  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {
    super.onClose();
  }

  // Logins user using GoogleSignIn
  loginWithGoogle() async {
    try {
      googleSignInAccount = await _googleSignIn.signIn();
      String fullName = googleSignInAccount!.displayName.toString();
      List<String> parts = fullName.split(" ");
      String lastName = " ";
      if (parts.length == 3) {
        if (parts[parts.length - 1].length == 1) {
          lastName = parts[1].toLowerCase().capitalizeFirst.toString();
        } else {
          lastName =
              parts[parts.length - 1].toLowerCase().capitalizeFirst.toString();
        }
      } else {
        lastName =
            parts[parts.length - 1].toLowerCase().capitalizeFirst.toString();
      }
      String firstName = parts[0].toLowerCase().capitalizeFirst.toString();

      UserModel userModel = UserModel(
        id: googleSignInAccount!.id,
        fullName: fullName,
        firstName: firstName,
        lastName: lastName,
        email: googleSignInAccount!.email,
      );
      await SecureStorageProvider().storeUserModel(userModel);
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<void> logoutGoogle() async {
    await _googleSignIn.signOut();
  }

  addKey(ApiKeys key, String val) async {
    await _secureStorageProvider.storeApiKey(key, val);
  }

  getKey(ApiKeys key) async {
    return await _secureStorageProvider.retrieveApiKey(key);
  }

  Future<bool> isApiKeyValid(String apiKey) async {
    print(apiKey);
    final weather = WeatherFactory(apiKey);
    try {
      final currentWeather = await weather.currentWeatherByLocation(
          currentPoint.value.latitude, currentPoint.value.longitude);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> getLocation() async {
    if (await _checkAndRequestPermission()) {
      final timeLimit = const Duration(seconds: 10);
      await FlLocation.getLocation(
              timeLimit: timeLimit, accuracy: LocationAccuracy.best)
          .then((location) {
        currentPoint.value = LatLng(location.latitude, location.longitude);
      }).onError((error, stackTrace) {
        print('error: ${error.toString()}');
      });
    }
  }

  Future<bool> _checkAndRequestPermission({bool? background}) async {
    if (!await FlLocation.isLocationServicesEnabled) {
      // Location services are disabled.
      return false;
    }

    var locationPermission = await FlLocation.checkLocationPermission();
    if (locationPermission == LocationPermission.deniedForever) {
      // Cannot request runtime permission because location permission is denied forever.
      return false;
    } else if (locationPermission == LocationPermission.denied) {
      // Ask the user for location permission.
      locationPermission = await FlLocation.requestLocationPermission();
      if (locationPermission == LocationPermission.denied ||
          locationPermission == LocationPermission.deniedForever) return false;
    }

    // Location permission must always be allowed (LocationPermission.always)
    // to collect location data in the background.
    if (background == true &&
        locationPermission == LocationPermission.whileInUse) return false;

    // Location services has been enabled and permission have been granted.
    return true;
  }
}
