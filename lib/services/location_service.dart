import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String placeName;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.placeName,
  });
}

class LocationService {
  // Returns null if permission denied or location unavailable.
  Future<LocationResult?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );

    final placeName = await _resolvePlaceName(pos.latitude, pos.longitude);

    return LocationResult(
      latitude: pos.latitude,
      longitude: pos.longitude,
      placeName: placeName,
    );
  }

  Future<String> _resolvePlaceName(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isEmpty) return '$lat, $lon';
      final p = placemarks.first;
      final parts = [p.locality, p.administrativeArea, p.country]
          .where((s) => s != null && s.isNotEmpty)
          .toList();
      return parts.isNotEmpty ? parts.join(', ') : '$lat, $lon';
    } catch (_) {
      return '$lat, $lon';
    }
  }
}
