#!/bin/bash
set -euo pipefail
VENDOR_REV=c1ec1363c659deaa483778315b86e680f8f81af0
VENDOR_DIR=$(mktemp -d)
trap 'rm -rf "$VENDOR_DIR"' EXIT
git clone --quiet https://github.com/HBandSDK/iOS_Ble_SDK.git "$VENDOR_DIR"
git -C "$VENDOR_DIR" checkout --quiet "$VENDOR_REV"
mkdir -p Vendor
cp -R "$VENDOR_DIR/iOS_sdk_source/Framework/2.2.XX.15/VeepooBleSDK.framework" Vendor/
for framework in GRDFUSDK DFUnits ABParTool JL_BLEKit JLDialUnit ZipZap; do
  cp -R "$VENDOR_DIR/iOS_sdk_source/Demo/VeepooBleSDKDemo/VeepooBleSDKDemo/$framework.framework" Vendor/
done
brew list xcodegen >/dev/null 2>&1 || brew install xcodegen
python3 - <<'PY'
from pathlib import Path
p=Path('project.yml')
s=p.read_text()
marker='    settings:\n      base:\n        PRODUCT_BUNDLE_IDENTIFIER:'
deps='    dependencies:\n'
for name in ['VeepooBleSDK','GRDFUSDK','DFUnits','JL_BLEKit','ABParTool','JLDialUnit','ZipZap']:
    embed = name in ['ABParTool','JLDialUnit','ZipZap']
    deps += f'      - framework: Vendor/{name}.framework\n        embed: {str(embed).lower()}\n'
assert marker in s
p.write_text(s.replace(marker,deps+marker,1))
PY
xcodegen generate
cat > Podfile <<'PODS'
platform :ios, '17.0'
use_frameworks!
target 'VeepooHealthBridge' do
  pod 'AFNetworking', '4.0.1'
  pod 'FMDB', '2.7.12'
  pod 'iOSDFULibrary', '4.15.3'
  pod 'ZIPFoundation', '0.9.19'
  pod 'MJExtension', '3.4.2'
end
PODS
pod install
