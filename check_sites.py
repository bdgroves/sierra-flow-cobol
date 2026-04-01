import urllib.request, json

sites = '11427000,11266500,11399500,11251000,11303000,11381500,11340500,11390000'
url = (f'https://waterservices.usgs.gov/nwis/iv/?format=json&sites={sites}'
       f'&parameterCd=00060&period=P1D&siteStatus=active')

r = urllib.request.urlopen(url)
d = json.loads(r.read())

seen = set()
for ts in d['value']['timeSeries']:
    sid = ts['sourceInfo']['siteCode'][0]['value']
    name = ts['sourceInfo']['siteName']
    if sid not in seen:
        seen.add(sid)
        print(sid, '-', name)
