import 'dart:convert';
import 'package:http/http.dart' as http;

class BusMapsService {
  static const String _baseUrl = 'https://capi.busmaps.com:8443';
  static const String _host = 'busmaps.com';

  final String apiKey;
  final http.Client _httpClient;

  BusMapsService({required this.apiKey, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Map<String, String> get _headers => {
        'capi-key': 'Bearer $apiKey',
        'capi-host': _host,
        'Accept': 'application/json',
      };

  Uri _uri(String path, [Map<String, String?>? params]) {
    final queryParameters = <String, String>{};
    if (params != null) {
      params.forEach((key, value) {
        if (value != null && value.isNotEmpty) {
          queryParameters[key] = value;
        }
      });
    }
    return Uri.parse('$_baseUrl$path').replace(queryParameters: queryParameters);
  }

  Future<List<BusMapsGtfsFeed>> getGtfsFeedsDownloads({String? countryIso}) async {
    final uri = _uri('/getGtfsFeedsDownloads', {
      if (countryIso != null) 'countryIso': countryIso,
    });

    final response = await _httpClient.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw BusMapsException(
        'GTFS catalog failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final data = jsonDecode(response.body);
    final items = data is List ? data : data['feeds'] as List?;
    return (items ?? [])
        .map((item) => BusMapsGtfsFeed.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<BusMapsStop>> stopsInRadius({
    required double latitude,
    required double longitude,
    int radius = 2000,
    String? regionName,
  }) async {
    final uri = _uri('/stopsInRadius', {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'radius': radius.toString(),
      if (regionName != null) 'regionName': regionName,
    });

    final response = await _httpClient.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw BusMapsException(
        'stopsInRadius failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final stops = data['stops'] as List<dynamic>? ?? [];
    return stops
        .map((item) => BusMapsStop.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<BusMapsLine> getLine({
    required String routeId,
    required String regionName,
    required String countryIso,
  }) async {
    final uri = _uri('/line', {
      'routeId': routeId,
      'regionName': regionName,
      'countryIso': countryIso,
    });

    final response = await _httpClient.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw BusMapsException(
        'line failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return BusMapsLine.fromJson(data);
  }

  Future<BusMapsTrip> getTrip({
    required String tripId,
    required String regionName,
  }) async {
    final uri = _uri('/trip', {
      'tripId': tripId,
      'regionName': regionName,
    });

    final response = await _httpClient.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw BusMapsException(
        'trip failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return BusMapsTrip.fromJson(data);
  }

  /// Récupère les prochains départs pour un arrêt donné.
  ///
  /// IMPORTANT : l'API BusMaps exige `countryIso` dès que `stopId` est
  /// utilisé, sinon elle renvoie une erreur 400
  /// ("countryIso is required when using stopId on busmaps").
  Future<BusMapsNextDepartures> nextDeparturesByStop({
    required String stopId,
    required String regionName,
    required String countryIso,
  }) async {
    final uri = _uri('/nextDepartures', {
      'stopId': stopId,
      'regionName': regionName,
      'countryIso': countryIso,
    });

    final response = await _httpClient.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw BusMapsException(
        'nextDepartures failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return BusMapsNextDepartures.fromJson(data);
  }
}

class BusMapsException implements Exception {
  final String message;
  final int statusCode;
  final String body;

  BusMapsException(this.message, {required this.statusCode, required this.body});

  @override
  String toString() =>
      'BusMapsException($statusCode): $message - ${body.substring(0, body.length.clamp(0, 150))}';
}

class BusMapsGtfsFeed {
  final String feedId;
  final String publisherName;
  final String feedUrl;
  final String countryIso;

  BusMapsGtfsFeed({
    required this.feedId,
    required this.publisherName,
    required this.feedUrl,
    required this.countryIso,
  });

  factory BusMapsGtfsFeed.fromJson(Map<String, dynamic> json) {
    return BusMapsGtfsFeed(
      feedId: json['feed_id']?.toString() ?? json['id']?.toString() ?? '',
      publisherName: json['publisher_name']?.toString() ?? '',
      feedUrl: json['feed_url']?.toString() ?? json['download_url']?.toString() ?? '',
      countryIso: json['country_iso']?.toString() ?? '',
    );
  }
}

class BusMapsStop {
  final String stopId;
  final String stopName;
  final double latitude;
  final double longitude;
  final String? regionName;
  final String? countryIso;

  BusMapsStop({
    required this.stopId,
    required this.stopName,
    required this.latitude,
    required this.longitude,
    this.regionName,
    this.countryIso,
  });

  factory BusMapsStop.fromJson(Map<String, dynamic> json) {
    return BusMapsStop(
      stopId: json['stopId']?.toString() ?? json['stop_id']?.toString() ?? '',
      stopName: json['stopName']?.toString() ?? json['stop_name']?.toString() ?? '',
      latitude: (json['stopLat'] ?? json['stop_lat'] ?? 0).toDouble(),
      longitude: (json['stopLon'] ?? json['stop_lon'] ?? 0).toDouble(),
      regionName: json['regionName']?.toString(),
      countryIso: json['countryIso']?.toString() ?? json['country_iso']?.toString(),
    );
  }
}

class BusMapsLine {
  final String routeId;
  final String routeName;
  final String regionName;
  final String? countryIso;
  final List<BusMapsStop> stops;
  final List<BusMapsTripSummary> trips;

  BusMapsLine({
    required this.routeId,
    required this.routeName,
    required this.regionName,
    this.countryIso,
    this.stops = const [],
    this.trips = const [],
  });

  factory BusMapsLine.fromJson(Map<String, dynamic> json) {
    final stops = (json['stops'] as List<dynamic>?)
            ?.map((item) => BusMapsStop.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];
    final trips = (json['trips'] as List<dynamic>?)
            ?.map((item) => BusMapsTripSummary.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];

    return BusMapsLine(
      routeId: json['routeId']?.toString() ?? json['route_id']?.toString() ?? '',
      routeName: json['routeName']?.toString() ?? json['route_name']?.toString() ?? '',
      regionName: json['regionName']?.toString() ?? '',
      countryIso: json['countryIso']?.toString(),
      stops: stops,
      trips: trips,
    );
  }
}

class BusMapsTripSummary {
  final String tripId;
  final String direction;

  BusMapsTripSummary({
    required this.tripId,
    required this.direction,
  });

  factory BusMapsTripSummary.fromJson(Map<String, dynamic> json) {
    return BusMapsTripSummary(
      tripId: json['tripId']?.toString() ?? json['trip_id']?.toString() ?? '',
      direction: json['direction']?.toString() ?? json['direction_name']?.toString() ?? '',
    );
  }
}

class BusMapsTrip {
  final String tripId;
  final String routeId;
  final String regionName;
  final List<BusMapsStopTime> stopTimes;

  BusMapsTrip({
    required this.tripId,
    required this.routeId,
    required this.regionName,
    required this.stopTimes,
  });

  factory BusMapsTrip.fromJson(Map<String, dynamic> json) {
    final stopTimes = (json['stopTimes'] as List<dynamic>?)
            ?.map((item) => BusMapsStopTime.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];
    return BusMapsTrip(
      tripId: json['tripId']?.toString() ?? json['trip_id']?.toString() ?? '',
      routeId: json['routeId']?.toString() ?? json['route_id']?.toString() ?? '',
      regionName: json['regionName']?.toString() ?? '',
      stopTimes: stopTimes,
    );
  }
}

class BusMapsStopTime {
  final String stopId;
  final String stopName;
  final String arrivalTime;
  final String departureTime;
  final int? stopSequence;

  BusMapsStopTime({
    required this.stopId,
    required this.stopName,
    required this.arrivalTime,
    required this.departureTime,
    this.stopSequence,
  });

  factory BusMapsStopTime.fromJson(Map<String, dynamic> json) {
    return BusMapsStopTime(
      stopId: json['stopId']?.toString() ?? json['stop_id']?.toString() ?? '',
      stopName: json['stopName']?.toString() ?? json['stop_name']?.toString() ?? '',
      arrivalTime: json['arrivalTime']?.toString() ?? json['arrival_time']?.toString() ?? '',
      departureTime:
          json['departureTime']?.toString() ?? json['departure_time']?.toString() ?? '',
      stopSequence: json['stopSequence'] is int
          ? json['stopSequence'] as int
          : int.tryParse(json['stopSequence']?.toString() ?? ''),
    );
  }
}

class BusMapsNextDepartures {
  final String regionName;
  final List<BusMapsDeparture> departures;

  BusMapsNextDepartures({
    required this.regionName,
    required this.departures,
  });

  factory BusMapsNextDepartures.fromJson(Map<String, dynamic> json) {
    final departures = (json['departures'] as List<dynamic>?)
            ?.map((item) => BusMapsDeparture.fromJson(item as Map<String, dynamic>))
            .toList() ??
        [];
    return BusMapsNextDepartures(
      regionName: json['regionName']?.toString() ?? '',
      departures: departures,
    );
  }
}

class BusMapsDeparture {
  final String routeId;
  final String routeShortName;
  final String destination;
  final String departureTime;
  final bool realtime;

  BusMapsDeparture({
    required this.routeId,
    required this.routeShortName,
    required this.destination,
    required this.departureTime,
    required this.realtime,
  });

  factory BusMapsDeparture.fromJson(Map<String, dynamic> json) {
    return BusMapsDeparture(
      routeId: json['routeId']?.toString() ?? json['route_id']?.toString() ?? '',
      routeShortName:
          json['routeShortName']?.toString() ?? json['route_short_name']?.toString() ?? '',
      destination: json['destination']?.toString() ?? json['headsign']?.toString() ?? '',
      departureTime:
          json['departureTime']?.toString() ?? json['departure_time']?.toString() ?? '',
      realtime: json['realtime'] == true || json['realTime'] == true,
    );
  }
}