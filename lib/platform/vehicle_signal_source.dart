/// "The device is probably in a vehicle" — never "the user is the driver".
///
/// Android (Phase 4): Activity Recognition Transition API, IN_VEHICLE
/// ENTER/EXIT, optionally confirmed by the user's chosen car Bluetooth.
/// iPhone (Phase 7): App Intents triggered by Shortcuts (Driving Focus/CarPlay).
/// Detection stays on the device; only availability is shared.
enum VehicleTransition { enter, exit }

enum VehicleConfidence { normal, high }

class VehicleEvent {
  const VehicleEvent(
    this.transition, {
    this.confidence = VehicleConfidence.normal,
  });
  final VehicleTransition transition;
  final VehicleConfidence confidence;
}

abstract class VehicleSignalSource {
  Stream<VehicleEvent> get events;
  bool get probablyInVehicle;
}
