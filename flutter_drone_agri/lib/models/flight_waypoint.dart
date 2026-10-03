enum WaypointAction {
  surveyScan,
  sprayTarget,
  hoverPhoto,
  rechargeRTL,
}

class FlightWaypoint {
  final int index;
  final double x; // Relative/Cartesian or Longitude (0..1 normalized for canvas or meter)
  final double y; // Relative/Cartesian or Latitude (0..1 normalized for canvas or meter)
  final double altitude; // Altitude in meters
  final double speed; // Speed in m/s
  final WaypointAction action;
  final bool isCompleted;

  const FlightWaypoint({
    required this.index,
    required this.x,
    required this.y,
    this.altitude = 15.0,
    this.speed = 3.0,
    this.action = WaypointAction.surveyScan,
    this.isCompleted = false,
  });

  FlightWaypoint copyWith({
    int? index,
    double? x,
    double? y,
    double? altitude,
    double? speed,
    WaypointAction? action,
    bool? isCompleted,
  }) {
    return FlightWaypoint(
      index: index ?? this.index,
      x: x ?? this.x,
      y: y ?? this.y,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      action: action ?? this.action,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
