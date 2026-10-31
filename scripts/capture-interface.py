"""Capture the actual native app; a boot-status timeout never creates a mock screenshot."""
import json
from pathlib import Path
import subprocess
import time


def run(command, timeout=45):
    return subprocess.run(command, check=True, timeout=timeout, text=True)


def retry(command, attempts=4):
    for attempt in range(attempts):
        try:
            return run(command)
        except (subprocess.SubprocessError, OSError):
            if attempt == attempts - 1:
                raise
            time.sleep(5)


devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j'], timeout=45))
device = next(x for group in devices['devices'].values() for x in group if 'iPhone' in x['name'])
identifier = device['udid']
print('Capture device:', device['name'], identifier, flush=True)
if device['state'] != 'Booted':
    run(['xcrun', 'simctl', 'boot', identifier])
try:
    run(['open', '-a', 'Simulator', '--args', '-CurrentDeviceUDID', identifier], timeout=20)
    run(['xcrun', 'simctl', 'bootstatus', identifier, '-b'], timeout=120)
except (subprocess.SubprocessError, OSError):
    print('Boot-status wait ended; trying actual app installation and launch.', flush=True)
app = Path('derived/Build/Products/Release-iphonesimulator/VeepooHealthBridge.app')
assert app.is_dir()
retry(['xcrun', 'simctl', 'install', identifier, str(app)])
out = Path('interface-captures')
out.mkdir(exist_ok=True)
for screen in ['home', 'device', 'settings']:
    retry(['xcrun', 'simctl', 'launch', '--terminate-running-process', identifier,
           'org.veepoobridge.ios', '--screen=' + screen, '-AppleLanguages', '(es)', '-AppleLocale', 'es_ES'])
    time.sleep(3)
    run(['xcrun', 'simctl', 'io', identifier, 'screenshot', str(out / (screen + '.png'))])
