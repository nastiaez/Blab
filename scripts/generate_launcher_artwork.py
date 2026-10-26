"""Render owner SVG without pre-rounded platform corners; then run flutter_launcher_icons.
Requires cairosvg. Source geometry/colors stay unchanged. Android foreground is
centered in 108dp with the supplied 378-unit composition occupying 72dp.
"""
from pathlib import Path
import re
import cairosvg

ROOT = Path(__file__).resolve().parent.parent
source = (ROOT / 'assets/icon/source/blab-icon.svg').read_text()
cairosvg.svg2png(
    bytestring=source.replace('rx="78"', 'rx="0"').encode(),
    write_to=str(ROOT / 'assets/icon/launcher_icon.png'),
    output_width=1024, output_height=1024,
)
paths = ''.join(re.findall(r'<path[^>]+/>', source))
foreground = (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 567 567" fill="none">'
    '<g transform="translate(94.5 94.5)">' + paths + '</g></svg>'
)
cairosvg.svg2png(
    bytestring=foreground.encode(),
    write_to=str(ROOT / 'assets/icon/orange_mark_adaptive.png'),
    output_width=1024, output_height=1024,
)
