#!/usr/bin/env dart

import 'dart:io';
import 'dart:convert';
import 'package:yaml/yaml.dart';

void main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart gen_assets.dart <config.yaml> <target_app_dir>');
    exit(1);
  }

  final configPath = args[0];
  final targetDir = args[1];
  
  // Read configuration
  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    print('Config file not found: $configPath');
    exit(1);
  }
  
  final configContent = await configFile.readAsString();
  final config = loadYaml(configContent) as Map;
  
  // Extract icon configuration
  final icons = config['icons'] as Map?;
  if (icons == null) {
    print('No icons configuration found in $configPath');
    exit(1);
  }
  
  final emoji = icons['emoji'] as String? ?? '📱';
  final bgColor = icons['bg'] as String? ?? '#FFFFFF';
  final primaryColor = config['primary_color'] as String? ?? '#2196F3';
  
  print('Generating assets for ${config['app_name']}');
  print('Emoji: $emoji, Background: $bgColor, Primary: $primaryColor');
  
  // Generate SVG template
  final svgContent = '''<?xml version="1.0" encoding="UTF-8"?>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <rect width="1024" height="1024" fill="$bgColor" rx="180"/>
  <text x="512" y="700" text-anchor="middle" font-size="500" font-family="Apple Color Emoji, Segoe UI Emoji, Noto Color Emoji">$emoji</text>
</svg>''';

  // Create assets directory
  final assetsDir = Directory('$targetDir/ios/Runner/Assets.xcassets/AppIcon.appiconset');
  await assetsDir.create(recursive: true);
  
  // Write SVG file
  final svgFile = File('${assetsDir.path}/icon.svg');
  await svgFile.writeAsString(svgContent);
  
  // Generate Contents.json
  final contentsJson = {
    'images': [
      {'idiom': 'iphone', 'scale': '2x', 'size': '20x20', 'filename': 'icon-40.png'},
      {'idiom': 'iphone', 'scale': '3x', 'size': '20x20', 'filename': 'icon-60.png'},
      {'idiom': 'iphone', 'scale': '2x', 'size': '29x29', 'filename': 'icon-58.png'},
      {'idiom': 'iphone', 'scale': '3x', 'size': '29x29', 'filename': 'icon-87.png'},
      {'idiom': 'iphone', 'scale': '2x', 'size': '40x40', 'filename': 'icon-80.png'},
      {'idiom': 'iphone', 'scale': '3x', 'size': '40x40', 'filename': 'icon-120.png'},
      {'idiom': 'iphone', 'scale': '2x', 'size': '60x60', 'filename': 'icon-120.png'},
      {'idiom': 'iphone', 'scale': '3x', 'size': '60x60', 'filename': 'icon-180.png'},
      {'idiom': 'ios-marketing', 'scale': '1x', 'size': '1024x1024', 'filename': 'icon-1024.png'},
    ],
    'info': {
      'author': 'iOS App Template Generator',
      'version': 1,
    }
  };
  
  final contentsFile = File('${assetsDir.path}/Contents.json');
  await contentsFile.writeAsString(JsonEncoder.withIndent('  ').convert(contentsJson));
  
  // Generate PNG files using ImageMagick (if available)
  final sizes = [40, 60, 58, 87, 80, 120, 180, 1024];
  
  for (final size in sizes) {
    final process = await Process.run('magick', [
      'convert',
      '-background', 'transparent',
      svgFile.path,
      '-resize', '${size}x$size',
      '${assetsDir.path}/icon-$size.png'
    ]);
    
    if (process.exitCode != 0) {
      print('Warning: ImageMagick not found or failed. Please install ImageMagick to generate PNG icons.');
      print('You can install it via: brew install imagemagick');
      break;
    }
  }
  
  print('✅ Generated app icons in ${assetsDir.path}');
}