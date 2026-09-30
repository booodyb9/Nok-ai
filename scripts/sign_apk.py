#!/usr/bin/env python3
"""Sign an already built APK with NOK's persistent key; never publish the key."""
import argparse
import re
import subprocess
import tempfile
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('input', 'output', 'keystore', 'password_file', 'apksigner_jar', 'zipalign'):
        parser.add_argument(name, type=Path)
    args = parser.parse_args()
    if args.input.resolve() == args.output.resolve():
        parser.error('Use a different output path; the input APK is preserved.')
    expected = (Path(__file__).resolve().parent.parent / 'android/signing-certificate.sha256').read_text().strip()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='nok-sign-', dir=args.output.parent) as work:
        aligned = Path(work) / 'aligned.apk'
        signed = Path(work) / 'signed.apk'
        subprocess.run([str(args.zipalign.resolve()), '-f', '-P', '16', '4', str(args.input), str(aligned)], check=True)
        signer = ['java', '-jar', str(args.apksigner_jar)]
        subprocess.run(signer + ['sign', '--ks', str(args.keystore), '--ks-key-alias', 'nok-release',
                                '--ks-pass', 'file:' + str(args.password_file),
                                '--out', str(signed), str(aligned)], check=True)
        result = subprocess.run(signer + ['verify', '--verbose', '--print-certs', str(signed)],
                                check=True, capture_output=True, text=True)
        match = re.search(r'Signer #1 certificate SHA-256 digest: ([0-9a-f]+)', result.stdout)
        if not match or match.group(1) != expected:
            raise SystemExit('Refusing to distribute an APK with a different signing certificate.')
        subprocess.run([str(args.zipalign.resolve()), '-c', '-P', '16', '4', str(signed)], check=True)
        signed.replace(args.output)
        print('Signature and 16 KB alignment verified; certificate SHA-256: ' + expected)
        print('Signed APK: ' + str(args.output))


if __name__ == '__main__':
    main()
