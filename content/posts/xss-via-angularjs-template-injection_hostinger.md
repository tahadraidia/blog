---
title: Reflective XSS via angularJS template injection - Hostinger
category: Application Security
tags: ["XSS", "Javascript"]
date: 2018-08-17
---

### Introduction 
This is a write-up of  an AngularJS Template Injection  I found in the main domain of Hostinger. If you don't know what's client-side template injection I invite you to take a look at those links [[1]](https://portswigger.net/kb/issues/00200308_client-side-template-injection)[[2]](https://blog.portswigger.net/2016/01/xss-without-html-client-side-template.html). Please note that this is my first write-up, I hope you'll enjoy it.

It all started when [@berkanexo](https://twitter.com/berkanexo) was telling me that he got listed on [Hostinger Wall Of Fame](https://www.hostinger.com/wall-of-fame) so I decided to take a look at their website.

### What is Hostinger?
A world class web hosting platform. Who has a bug bounty program.

### Finding the vulnerability
While browsing their website the first thing I noticed is that they were using AngularJS for the front, I immediately opened the Javascript console to check what version they were using.  

![angularVersion](/images/angularVersion.png){:class="postImage"}

As we can see on the above image, they were using the ```version 1.5.1```. I knew the existance of a payload for that version. The only thing left todo was to check if they were vulenrable to template injection. On the main page of the website was a form to find a unique domain. 

![findDomainImage](/images/findDomain.png){:class="postImage"}

I inserted the following: ```toto{ { 4-2 } }``` and the result was: ```toto2``` which mean they were vulnerable to template injection. It was not enough. I needed to proof that we can run javascript code.   

### Exploitation
By inserting the following:   
{% highlight javascript lineos %}
 toto{ {x = {'y':''.constructor.prototype}; x['y'].charAt=[].join;$eval('x=alert(document.domain)');} }
{% endhighlight %}
An alertbox should popup and should be accepted as a Proof Of Concept.

##### Proof of Concept  using Chrome:

![alertBox](/images/Hostinger_chrome.png){:class="postImage"}

##### Proof of  Concept using Edge:

![alertBox](/images/Hostinger_edge.png){:class="postImage"}

### Timeline
* 23/10/2017: Reported to Hostinger
* 24/10/2017: Vulnerability Patched
* 25/10/2017: Got my name on their Wall Of Fame

Thanks for reading.
