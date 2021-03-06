#!/usr/bin/python
import urllib
import urllib2
import json
import sys

def query_graphite(url):
    """Function to make query to graphite to retrive monitoring data
    Returns data for the query in json format. Refer document
    http://graphite.readthedocs.org/en/1.0/url-api.html for details
    Accepts url formatted to make a query to graphite. Time out to get
    a valid response from graphite URL is 30 seconds 
    Keyword arguments:
    url: graphite jsp api url along with the query parameter 
    """
    req = urllib2.Request(url)
    response = urllib2.urlopen(req,timeout=30)
    res = response.read()
    data = json.loads(res)
    return data

def write_data(zbxhost, zbxkey, data):
    """Function to parse the json object retruned by graphite query
    and generate data in the format zabbix_sender protocol needs
    Refer to zabbix sender man pages for details.
    https://www.zabbix.com/documentation/1.8/manpages/zabbix_sender
    Accepts host name defined in zabbix, the zabbix item defined in
    the zabbix host to which the data corresponds to  and the data 
    Keyword arguments:
    zbxhost: the zabbix host name to which the data will be attached to
    zbxkey: the zabbix key to which the data will be attached to
    data: json data returned from querying graphite. Sample data
    [{   
      "target": "entries",
        "datapoints": [
          [1.0, 1311836008],
          [2.0, 1311836009]
        ]
    }]
    """
    for entry in data:
        for key,value in entry.iteritems():
            if key == 'datapoints':
               for v in value:
                 if (v[0] is None):
                   val = '0'
                 else:
                   val = str(v[0])
                 out = "%s %s %s %s" % (zbxhost,zbxkey,str(v[1]),val)
                 sys.stdout.write(out+'\n')

if __name__ == "__main__":
    with open("/usr/local/etc/query_graphite.config","r") as fin:
        config = json.load(fin)
        for entry in config["queries"]:
            graphite_data=query_graphite(entry["graphite_url"])
            write_data(entry["zabbix_host"],entry["zabbix_key"],graphite_data)
