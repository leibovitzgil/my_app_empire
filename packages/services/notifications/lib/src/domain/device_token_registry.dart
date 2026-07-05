import 'package:core_utils/core_utils.dart';

/// Contract for registering/unregistering a device's push token against a
/// user, so a server-side (or, pre-Cloud-Function, client-side) sender knows
/// which devices to notify. Forward-provisioning only for v1: nothing yet
/// reads this registry to actually deliver a push (see
/// `UserMessageGateway.sendToUser`'s doc) — it's write-only plumbing a later
/// Cloud Function will consume unchanged.
abstract class DeviceTokenRegistry {
  /// Registers [token] as a current push token for [uid]. Idempotent:
  /// registering the same token again is a no-op.
  Future<Result<void>> register(String uid, String token);

  /// Unregisters [token] for [uid] (e.g. on sign-out). Idempotent: a no-op
  /// if [token] isn't currently registered.
  Future<Result<void>> unregister(String uid, String token);
}
