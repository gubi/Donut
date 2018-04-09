# auto-server
This script automatize the first server install process in an Ubuntu/Debian environment.<br />
* Get an empty virtual server
* Launch this scipt under the `/home/`
``` shell
$ ./server_init.sh <WEBSERVER_TYPE> <DOMAIN.TLD>
```
(for example: `$ ./server_init.sh apache example.com`)

The script will proceed to execute this sequence of stuff:
1. Add [ondrej](https://launchpad.net/~ondrej/+archive/ubuntu/php) apt-repository for the latest version of PHP (Best supported)
2. Add [certbot](https://certbot.eff.org/) apt-repository for the last version of [Let’s Encrypt](https://letsencrypt.org/)
3. Update the System
4. Upgrade the system
5. Install your preferred Web Server
6. Install `python-certbot`
7. Update the System
8. Install `curl` and `software-properties-common`
9. Install the latest version of PHP
10. Enable and configure [ufw](https://wiki.debian.org/Uncomplicated%20Firewall%20%28ufw%29
11. Modify permissions on webserver root
12. Remove the default `html` folder created by the web server
13 Create the `index.php` and the `info.php` files
14. Configure the web server (removing also the default configurations)
15. Enable certbot certificates to keep updated via `cron`
16. Restart the server

### Please, help me perfecting this project
