---
title: Bypass Content Security Policy framing restriction rule - OLX
category: Application Security
tags: ["Clickjacking", "CSP", "DNS"]
date: 2019-01-17
---

It's been a while since my last post. Today I decided to share with you a bug I found on a public bug bounty program on HackerOne. You can find the original report [here](https://hackerone.com/reports/371980).

This post is about a misconfiguration in CSP rule that leaves the website vulnerable to UI redressing aka clickjacking. This attack is widly used by scammer and spammers to trick users.  
After some recon on *olx.co.za* and *olx.com.gh* I noticed that both of them use the same CSP rule to restrict framing as you can see below:

**olx.co.za:**

![image](/images/csp_olx.co.za.png)

**olx.com.gh:** 

![image](/images/csp_olx.com.gh.png)

Let's take a closer look at it:
```
content-security-policy: frame-ancestors 'self' https://*.mod-tools.com:*
```
Basically it says that you can only frame *olx.co.za*, *olx.com.gh* if your origin is a subdomain of *mod-tools.com* (using HTTPS only on any port).

So my plan was:
* Subdomain Enumeration
* Seek for a subdomain takeover
* Write a proof of concept

Before starting the above process, I settled on checking dns records of *mod-tools.com* and to my suprise the domain was unclaimed:

```
$ dig mod-tools.com 

; <<>> DiG 9.10.3-P4-Ubuntu <<>> mod-tools.com
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 11998
;; flags: qr rd ra ad; QUERY: 1, ANSWER: 0, AUTHORITY: 0, ADDITIONAL: 0

;; QUESTION SECTION:
;mod-tools.com.         IN  A

;; Query time: 1 msec
;; SERVER: 127.0.1.1#53(127.0.1.1)
;; WHEN: Thu Jun 28 10:34:33 CEST 2018
;; MSG SIZE  rcvd: 31
```

Wait what ?

![claim_domain](/images/unclaimed_mod-tools.com.png)

Can we claim it ?

![claim_domain](/images/claim_mod-tools.com.png)

The domain was available and we could claim it. I just submited the report without claiming it.

Timeline:
* 28/06/2018: submited report 
* 29/06/2018: triaged
* 24/10/2018: resolved
* 23/12/2018: disclosed

Notes:
* Always check CSP rules for misconfiguration
* Check assets used by CSP rules
* Sometimes you just only need a browser to find bugs on websites 

Thanks for reading
