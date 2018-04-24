# mactrack

## A. Summary

Want to keep track of devices on your network? 

**mactrack** monitors MAC addresses discovered on your LAN. You can see when a device was discovered and last seen, and you can add tags (notes) to keep better track of devices on your network.

**Coming soon:** Get notifications when new MAC addresses are discovered on your network.

## B. Dependencies

 * BASH 4+
 * ipcalc
 * nmap

## C. Supported Systems

**mactrack** has been tested on CentOS Linux 7/RHEL 7 and Raspberry Pi (Raspbian). 

*It should work on other modern Linux distros!*

### Installation

1. Clone this repo to your preferred directory (eg: `/opt/`)

```
cd /opt
git clone https://github.com/curtis86/mactrack
```

2. Follow the usage instructions below!

### Usage

1) Set the network that you want to monitor `/opt/mactrack/mactrack --network <YOUR_NETWORK>`

2) Scan your network `/opt/mactrack/mactrack --scan`

3) List MAC addresses discovered on your network! `/opt/mactrack/mactrack --list`

4) Finally, **mactrack** should run as a scheduled cronjob:

 Schedule `/opt/mactrack/mactrack --scan` to run as a cronjob at your preferred interval (I run mine every 5 minutes), ie:

`*/5 * * * * root /opt/mactrack/mactrack --scan`

> **mactrack** must run as the root user!

### Sample Output
```
Last scan: Wed Apr 25 01:29:45 AEST 2018
Hosts discovered: 22

MAC Address        Last Seen (Date)       Last Seen (Seconds)  Discovered         Vendor                                Tags
-----------------  ---------------------  -------------------  -----------------  ------------------                    -------------------------------------
AA:AA:AA:AA:AA:AA  25/04/18 01:29:45      0                    25/04/18 00:58:13  Olym-tech Co.                         None
BB:BB:BB:BB:BB:BB  25/04/18 01:29:45      0                    25/04/18 00:58:13  Cisco-Linksys                         Office Router
CC:CC:CC:CC:CC:CC  25/04/18 01:29:45      0                    25/04/18 01:29:45  Apple                                 Curtis iPhone
DD:DD:DD:DD:DD:DD  25/04/18 01:29:45      0                    25/04/18 00:58:13  Giga-byte Technology Co.              Gaming PC
EE:EE:EE:EE:EE:EE  25/04/18 01:29:45      0                    25/04/18 00:58:13  QEMU Virtual NIC                      Gateway
FF:FF:FF:FF:FF:FF  25/04/18 01:29:45      0                    25/04/18 00:58:13  QEMU Virtual NIC                      Watchtower
...
...
...
```

## Notes

* To reduce unnecessary network noise, try not to run **mactrack** too frequently.
* **mactrack** has only been tested on a `/24` network and performance on larger subnets is unknown.
* **mactrack** must run as the root user to get MAC address data.
* 'Last Seen' time in `mactrack --list` is relative to the last scan time.

## Disclaimer

I'm not a programmer, but I do like to make things! Please use this at your own risk.

## License

The MIT License (MIT)

Copyright (c) 2018 Curtis K

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.