import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ultimate_alarm_clock/app/data/models/user_model.dart';
import 'package:ultimate_alarm_clock/app/data/providers/firestore_provider.dart';
import 'package:ultimate_alarm_clock/app/data/providers/secure_storage_provider.dart';
import 'package:ultimate_alarm_clock/app/modules/home/controllers/home_controller.dart';
import 'package:ultimate_alarm_clock/app/utils/constants.dart';
import 'package:weather/weather.dart';
import 'package:latlong2/latlong.dart';
import 'package:fl_location/fl_location.dart';

class SettingsController extends GetxController {
  var homeController = Get.find<HomeController>();
  var isHapticFeedbackEnabled = true.obs;
  final _hapticFeedbackKey = 'haptic_feedback';
  final _secureStorageProvider = SecureStorageProvider();
  final apiKey = TextEditingController();
  final currentPoint = LatLng(0, 0).obs;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  late GoogleSignInAccount? googleSignInAccount;
  final RxBool isUserLoggedIn = false.obs;
  final RxBool isWeatherKeyAdded = false.obs;
  final RxBool didWeatherKeyError = false.obs;
  UserModel? userModel;
  @override
  void onInit() {
    super.onInit();

    userModel = homeController.userModel.value;
    isUserLoggedIn.value = homeController.isUserSignedIn.value;
    _loadPreference();
  }

  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {
    super.onClose();
    homeController.isUserSignedIn.value = isUserLoggedIn.value;
    homeController.userModel.value = userModel;
  }

  // Logins user using GoogleSignIn
  loginWithGoogle() async {
    try {
      googleSignInAccount = await _googleSignIn.signIn();

      if (googleSignInAccount != null) {
        // Process successful sign-in
        String fullName = googleSignInAccount!.displayName.toString();
        List<String> parts = fullName.split(" ");
        String lastName = " ";
        if (parts.length == 3) {
          if (parts[parts.length - 1].length == 1) {
            lastName = parts[1].toLowerCase().capitalizeFirst.toString();
          } else {
            lastName = parts[parts.length - 1]
                .toLowerCase()
                .capitalizeFirst
                .toString();
          }
        } else {
          lastName =
              parts[parts.length - 1].toLowerCase().capitalizeFirst.toString();
        }
        String firstName = parts[0].toLowerCase().capitalizeFirst.toString();

        userModel = UserModel(
          id: googleSignInAccount!.id,
          fullName: fullName,
          firstName: firstName,
          lastName: lastName,
          email: googleSignInAccount!.email,
        );
        await FirestoreDb.addUser(userModel!);
        await SecureStorageProvider().storeUserModel(userModel!);
        isUserLoggedIn.value = true;

        return true;
      } else {
        return null;
      }
    } catch (e) {
      // Handle any other exceptions that may occur
      print(e);
      return false;
    }
  }

  Future<void> logoutGoogle() async {
    await _googleSignIn.signOut();
    await SecureStorageProvider().deleteUserModel();
    userModel = null;
    isUserLoggedIn.value = false;
  }

  addKey(ApiKeys key, String val) async {
    await _secureStorageProvider.storeApiKey(key, val);
  }

  getKey(ApiKeys key) async {
    return await _secureStorageProvider.retrieveApiKey(key);
  }

  Future<bool> isApiKeyValid(String apiKey) async {
    final weather = WeatherFactory(apiKey);
    try {
      // ignore: unused_local_variable
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

  void _loadPreference() async {
    isHapticFeedbackEnabled.value = await _secureStorageProvider
        .readHapticFeedbackValue(key: _hapticFeedbackKey);
  }

  void _savePreference() async {
    await _secureStorageProvider.writeHapticFeedbackValue(
      key: _hapticFeedbackKey,
      isHapticFeedbackEnabled: isHapticFeedbackEnabled.value,
    );
  }

  void toggleHapticFeedback(bool enabled) {
    isHapticFeedbackEnabled.value = enabled;
    _savePreference();
  }
}
