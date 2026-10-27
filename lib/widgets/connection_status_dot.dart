import 'package:flutter/material.dart';

enum ConnectionStatus { connected, expiringSoon, expired, neverConnected }

class ConnectionStatusDot extends StatelessWidget {
  final ConnectionStatus status;
  final String platform;
  final double size;

  const ConnectionStatusDot({
    super.key,
    required this.status,
    required this.platform,
    this.size = 8,
  });

  Color get _color {
    switch (status) {
      case ConnectionStatus.connected:
        return const Color(0xFF34C759);
      case ConnectionStatus.expiringSoon:
        return const Color(0xFFFF9500);
      case ConnectionStatus.expired:
        return const Color(0xFFFF3B30);
      case ConnectionStatus.neverConnected:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$platform: ${status.name}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _color,
          boxShadow: status == ConnectionStatus.connected
              ? [
                  BoxShadow(
                    color: _color.withAlpha(100),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  static ConnectionStatus fromTokenStatus(dynamic tokenStatus) {
    switch (tokenStatus.toString()) {
      case 'connected':
        return ConnectionStatus.connected;
      case 'expiringSoon':
        return ConnectionStatus.expiringSoon;
      case 'expired':
        return ConnectionStatus.expired;
      default:
        return ConnectionStatus.neverConnected;
    }
  }
}

class ConnectionStatusRow extends StatelessWidget {
  final Map<String, ConnectionStatus> statuses;

  const ConnectionStatusRow({super.key, required this.statuses});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: statuses.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: ConnectionStatusDot(
            status: entry.value,
            platform: entry.key,
          ),
        );
      }).toList(),
    );
  }
}
