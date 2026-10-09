import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum DeviceCategory {
  iphone,
  android,
  tablet,
  laptop,
  tv,
}

enum PreviewOrientation {
  portrait,
  landscape,
}

class DeviceSpec {
  final String id;
  final String name;
  final String brand;
  final DeviceCategory category;
  final double width;
  final double height;
  final double cornerRadius;
  final double bezelWidth;
  final IconData icon;
  final bool supportsLandscape;

  const DeviceSpec({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.width,
    required this.height,
    required this.cornerRadius,
    required this.bezelWidth,
    required this.icon,
    this.supportsLandscape = true,
  });

  static const List<DeviceSpec> allDevices = [
    DeviceSpec(
      id: 'iphone_16_pro',
      name: 'iPhone 16 Pro',
      brand: 'Apple',
      category: DeviceCategory.iphone,
      width: 380,
      height: 770,
      cornerRadius: 48,
      bezelWidth: 8,
      icon: CupertinoIcons.device_phone_portrait,
      supportsLandscape: false,
    ),
    DeviceSpec(
      id: 'samsung_s24_ultra',
      name: 'Galaxy S24 Ultra',
      brand: 'Samsung',
      category: DeviceCategory.android,
      width: 385,
      height: 790,
      cornerRadius: 26,
      bezelWidth: 7,
      icon: CupertinoIcons.device_phone_portrait,
      supportsLandscape: false,
    ),
    DeviceSpec(
      id: 'ipad_pro_13',
      name: 'iPad Pro 13"',
      brand: 'Apple',
      category: DeviceCategory.tablet,
      width: 580,
      height: 780,
      cornerRadius: 32,
      bezelWidth: 12,
      icon: Icons.tablet_mac,
      supportsLandscape: true,
    ),
    DeviceSpec(
      id: 'macbook_pro_16',
      name: 'MacBook Pro 16"',
      brand: 'Apple',
      category: DeviceCategory.laptop,
      width: 720,
      height: 480,
      cornerRadius: 18,
      bezelWidth: 14,
      icon: CupertinoIcons.device_laptop,
      supportsLandscape: false,
    ),
    DeviceSpec(
      id: 'smart_tv_4k',
      name: 'Smart TV 4K',
      brand: 'Living Room',
      category: DeviceCategory.tv,
      width: 760,
      height: 460,
      cornerRadius: 10,
      bezelWidth: 10,
      icon: CupertinoIcons.tv,
      supportsLandscape: false,
    ),
  ];

  static DeviceSpec byCategory(DeviceCategory category) {
    return allDevices.firstWhere(
      (d) => d.category == category,
      orElse: () => allDevices.first,
    );
  }
}
