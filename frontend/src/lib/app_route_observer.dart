import 'package:flutter/material.dart';

/// Registered on [MaterialApp.navigatorObservers]. Screens mix in [RouteAware]
/// and subscribe so they can refresh when a route pushed on top is popped.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
