"""Distribution checks; numerical Stata validation is a separate licensed job."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
packages=list(root.glob('*.pkg'))
assert packages,'No Stata distribution manifest'
for manifest in packages:
    for line in manifest.read_text(encoding='utf-8-sig').splitlines():
        if line.startswith('f '):
            path=root/line[2:].strip()
            assert path.is_file(),(manifest.name,'missing package file',path)
assert (root/'LICENSE').is_file()
for file in ['README.md','examples/school_policy.do','examples/school_policy.csv','examples/school_panel.csv','examples/DATA_GUIDE.md','examples/expected_output.txt','tests/release_checks.json']:
    assert (root/file).is_file(),file
for file in root.rglob('*.ado'):
    if '.git' not in file.parts:
        text=file.read_text(encoding='utf-8',errors='replace')
        assert not any(line.startswith(('<<<<<<< ','>>>>>>> ')) or line=='=======' for line in text.splitlines()),file
print('Distribution checks passed (not a substitute for licensed numerical tests).')
