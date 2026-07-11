import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/trajet.dart';
import 'location_service.dart';

class NavigationSnapshot {
  final LatLng position;
  final LatLng? snappedPosition;
  final String nextInstruction;
  final int remainingMinutes;
  final double remainingMeters;
  final bool hasArrived;
  final double? bearing;

  const NavigationSnapshot({
    required this.position,
    this.snappedPosition,
    required this.nextInstruction,
    required this.remainingMinutes,
    required this.remainingMeters,
    required this.hasArrived,
    this.bearing,
  });

  bool get isOnRoute => snappedPosition != null;
}

class NavigationService {
  static final NavigationService _instance = NavigationService._();
  factory NavigationService() => _instance;
  NavigationService._();

  StreamSubscription<NavigationSnapshot>? _subscription;
  NavigationSnapshot? _lastSnapshot;

  LatLng? _destination;
  List<LatLng> _routePoints = const [];
  Segment? _activeSegment;
  int _currentRouteIndex = 0;
  bool _isNavigating = false;
  bool _autoRecenter = true;

  NavigationSnapshot? get lastSnapshot => _lastSnapshot;
  bool get isNavigating => _isNavigating;
  bool get autoRecenter => _autoRecenter;

  void configure({
    required LatLng destination,
    required List<LatLng> routePoints,
    Segment? activeSegment,
  }) {
    _destination = destination;
    _routePoints = routePoints;
    _activeSegment = activeSegment;
    _currentRouteIndex = 0;
  }

  Stream<NavigationSnapshot> startNavigation() {
    _isNavigating = true;
    _currentRouteIndex = 0;

    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).asyncMap(_toSnapshot);

    _subscription = stream.listen(
      _onPosition,
      onError: (_) {},
      cancelOnError: false,
    );

    return stream;
  }

  Future<void> stopNavigation() async {
    await _subscription?.cancel();
    _subscription = null;
    _isNavigating = false;
    _lastSnapshot = null;
  }

  void toggleRecenter() {
    _autoRecenter = !_autoRecenter;
  }

  Future<NavigationSnapshot> _toSnapshot(Position position) async {
    final current = LatLng(position.latitude, position.longitude);
    final snapped = _snapToRoute(current);
    final advanced = _advanceRouteIndex(snapped ?? current);
    final next = _nextInstruction(advanced.routeIndex);
    final remaining = _remainingFrom(advanced.routeIndex);
    final arrived = _hasArrived(current);

    final snapshot = NavigationSnapshot(
      position: current,
      snappedPosition: snapped,
      nextInstruction: next,
      remainingMinutes: _minutesFromMeters(remaining),
      remainingMeters: remaining,
      hasArrived: arrived,
      bearing: position.heading,
    );

    _lastSnapshot = snapshot;
    return snapshot;
  }

  void _onPosition(NavigationSnapshot snapshot) {
    _lastSnapshot = snapshot;
  }

  LatLng? _snapToRoute(LatLng current) {
    if (_routePoints.isEmpty) return null;

    double minDist = double.infinity;
    LatLng? closest;
    int closestIndex = 0;

    for (int i = 0; i < _routePoints.length; i++) {
      final p = _routePoints[i];
      final d = LocationService.distanceEnMetres(
        lat1: current.latitude,
        lon1: current.longitude,
        lat2: p.latitude,
        lon2: p.longitude,
      );
      if (d < minDist) {
        minDist = d;
        closest = p;
        closestIndex = i;
      }
    }

    if (minDist > 80) return null;
    _currentRouteIndex = closestIndex;
    return closest;
  }

  ({int routeIndex, LatLng point}) _advanceRouteIndex(LatLng snapped) {
    if (_routePoints.isEmpty) return (routeIndex: 0, point: snapped);

    for (int i = _currentRouteIndex; i < _routePoints.length - 1; i++) {
      final p = _routePoints[i + 1];
      final d = LocationService.distanceEnMetres(
        lat1: snapped.latitude,
        lon1: snapped.longitude,
        lat2: p.latitude,
        lon2: p.longitude,
      );
      if (d <= 12) {
        _currentRouteIndex = i + 1;
      }
    }

    _currentRouteIndex = _currentRouteIndex.clamp(0, _routePoints.length - 1);
    return (routeIndex: _currentRouteIndex, point: _routePoints[_currentRouteIndex]);
  }

  String _nextInstruction(int routeIndex) {
    if (_routePoints.isEmpty) return 'Suis la route';
    if (routeIndex >= _routePoints.length - 1) {
      return _activeSegment?.description ?? 'Tu es arrivé';
    }

    if (_activeSegment != null) {
      if (_activeSegment!.type == TypeSegment.piedVersGare) {
        return 'Dirige-toi vers ${_activeSegment!.description.replaceFirst('Marche vers ', '')}';
      }
      if (_activeSegment!.type == TypeSegment.transport) {
        return _activeSegment!.description;
      }
      if (_activeSegment!.type == TypeSegment.piedVersDest) {
        return 'Marche vers ta destination';
      }
    }

    return 'Continue tout droit';
  }

  double _remainingFrom(int routeIndex) {
    if (_routePoints.isEmpty) return 0;
    double total = 0;
    for (int i = routeIndex; i < _routePoints.length - 1; i++) {
      total += LocationService.distanceEnMetres(
        lat1: _routePoints[i].latitude,
        lon1: _routePoints[i].longitude,
        lat2: _routePoints[i + 1].latitude,
        lon2: _routePoints[i + 1].longitude,
      );
    }
    return total;
  }

  bool _hasArrived(LatLng current) {
    if (_destination == null) return false;
    final d = LocationService.distanceEnMetres(
      lat1: current.latitude,
      lon1: current.longitude,
      lat2: _destination!.latitude,
      lon2: _destination!.longitude,
    );
    return d <= 40;
  }

  static int _minutesFromMeters(double meters) {
    if (meters <= 0) return 0;
    final walking = (meters / 4000 * 60).round();
    return walking.clamp(1, 120);
  }
}
