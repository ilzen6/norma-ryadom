import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/server_address.dart';
import '../../utils/result.dart';

sealed class ServerUpdate {
  const ServerUpdate();
}

final class ServerSaved extends ServerUpdate {
  const ServerSaved(this.address);

  final String address;
}

final class ServerRejected extends ServerUpdate {
  const ServerRejected(this.problem);

  final ServerAddressProblem problem;
}

final class ServerUnreachable extends ServerUpdate {
  const ServerUnreachable(this.failure);

  final AppFailure failure;
}

final serverSettingsProvider = Provider<ServerSettings>(
  (ref) => ServerSettings(
    ref.watch(serverAddressProvider.notifier),
    ref.watch(serverProbeProvider),
    allowCleartext: ref.watch(appConfigProvider).allowCleartextServer,
  ),
);

class ServerSettings {
  const ServerSettings(this._address, this._probe, {required this.allowCleartext});

  final ServerAddressController _address;
  final ServerProbe _probe;
  final bool allowCleartext;

  Future<ServerUpdate> apply(String text) async {
    final (address, problem) = ServerAddress.parse(text, allowCleartext: allowCleartext);
    if (address == null) return ServerRejected(problem ?? ServerAddressProblem.invalid);
    if (await _probe(address) case Err(:final failure)) return ServerUnreachable(failure);
    await _address.save(address);
    return ServerSaved(address);
  }
}
