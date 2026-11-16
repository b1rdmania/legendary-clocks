# Adds Jacobsen and Orsay to the site once their dial renders exist. Run from site/.
import re, subprocess
s = open('index.html').read()
def edge(id):
    return subprocess.run(['magick', f'assets/{id}/dial/day/plate.jpg', '-crop', '120x120+0+0', '-resize', '1x1!', '-format', '#%[hex:p{0,0}]', 'info:'],
                          capture_output=True, text=True).stdout[:7].lower()
j, o = edge('jacobsen'), edge('orsay')
s = s.replace("  ball: { name: 'Ball',", f"""  jacobsen: {{ name: 'Jacobsen', by: 'Arne Jacobsen · 1942', line: 'Made for Aarhus City Hall. Slender bars, nothing else.', move: smooth,
    lift: {{ hour: .0012, minute: .0024, second: .0034 }},
    looks: {{ dial: {{ day: {{ bg: '{j}' }} }} }} }},
  orsay: {{ name: 'Orsay', by: 'Gare d\\u2019Orsay · 1900', line: 'The great glass clock face, seen from inside the station.', move: smooth,
    lift: {{ hour: .0030, minute: .0046, second: 0 }},
    looks: {{ dial: {{ day: {{ bg: '{o}' }} }} }} }},
  ball: {{ name: 'Ball',""")
s = s.replace("const ORDER = ['station', 'bill', 'rams', 'ball'];", "const ORDER = ['station', 'bill', 'jacobsen', 'rams', 'orsay', 'ball'];")
s = s.replace('Four clocks. More in the workshop.', 'Six clocks. More in the workshop.')
s = s.replace("const names = [['Hans Hilfiker', '1944'], ['Max Bill', '1956'], ['George Nelson studio', '1948'], ['Dieter Rams & Dietrich Lubs', '1987']];",
              "const names = [['Hans Hilfiker', '1944'], ['Max Bill', '1956'], ['Arne Jacobsen', '1942'], ['Gare d\\u2019Orsay', '1900'], ['George Nelson studio', '1948'], ['Dieter Rams & Dietrich Lubs', '1987']];")
s = s.replace("const soon = [['Arne Jacobsen', '1942'], ['Richard Sapper', '1959'], ['Gino Valle', '1965']];",
              "const soon = [['Richard Sapper', '1959'], ['Gino Valle', '1965'], ['Peter Behrens', '1910']];")
s = s.replace('<span><b>Arne Jacobsen</b> 1942</span><span><b>Musée d\'Orsay</b> 1900</span><span><b>Richard Sapper</b> 1959</span><span><b>Gino Valle</b> 1965</span>',
              '<span><b>Richard Sapper</b> 1959</span><span><b>Gino Valle</b> 1965</span><span><b>Peter Behrens</b> 1910</span><span><b>Paolo Uccello</b> 1443</span>')
s = s.replace('<div><b>George Nelson studio</b><span>Ball clock, 1948</span></div>',
              '<div><b>George Nelson studio</b><span>Ball clock, 1948</span></div>\n          <div><b>Arne Jacobsen</b><span>Roman clock, 1942</span></div>\n          <div><b>Gare d’Orsay</b><span>Station clock, 1900</span></div>')
s = s.replace('.credits{display:grid;grid-template-columns:repeat(4,minmax(0,1fr))', '.credits{display:grid;grid-template-columns:repeat(3,minmax(0,1fr))')
s = s.replace('.collection{display:grid;grid-template-columns:repeat(4,minmax(0,1fr))', '.collection{display:grid;grid-template-columns:repeat(3,minmax(0,1fr))')
s = s.replace('Bill and Rams tick once a second, like quartz.</p>', 'Bill and Rams tick once a second, like quartz. Jacobsen, Orsay and Ball glide.</p>')
s = s.replace('<figcaption><b>Continuous</b>Ball</figcaption>', '<figcaption><b>Continuous</b>Jacobsen, Orsay, Ball</figcaption>')
open('index.html', 'w').write(s)
print('added', j, o)
