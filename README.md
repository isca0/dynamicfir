# dynamicfir
=================

### A dynamic host DNAT iptables front-end for Network Unix Administrator's


By: [Zero](http://plebeos1.blogspot.com)
Curitiba/PR - Brazil (13/09/2014)


## the need

####english explain comes first ;)
A lot o people request a way to access network services from remote computers without vpn. On a statefull firewall we allways dont want unidentified hosts to connect on network. And on small networks we dont wnat a lot of resources to make a remote client get in on some service port. So i just make a way to simplified the regular dynamichost users to access this services allowing only the dynamic ip address to be constantly verified on firewall and create the chain on iptables.

## Required

* Cron (must be runnig as an cron job)
* host (host command line tool)

## Knolegment

Its only a simple shell script, i presume you have a little knolegment with Linux network administration, and iptables basic's

Ps.: Right Now, this only support's a simple DNAT redirection
