import 'package:flutter/material.dart';
import '../models/ble_models.dart';

class DeviceTile extends StatelessWidget {
  final DeviceSnapshot device;
  final VoidCallback onTap;
  const DeviceTile({super.key, required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rssi = device.rssi;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE2F1ED),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.watch_outlined, color: Color(0xFF2C9B88)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    device.id,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6D7C84),
                    ),
                  ),
                ],
              ),
            ),
            if (rssi != null)
              Text(
                '$rssi dBm',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6D7C84)),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF9AA7AC)),
          ],
        ),
      ),
    );
  }
}
