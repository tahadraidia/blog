---
title: "Delivering more than just presents: An Xmas story of self-XSS on Amazon.com"
category: Application Security
tags: ["XSS", "Javascript"]
date: 2020-04-02
---

It's been a long time since my last blog post, as I was preparing for my OSCP. Well, I'm glad to inform you all that I'm now an Offensive Security Certified Professional. 

In this post, I will walk you through how, in less than five minutes, I found a self-XSS bug on the main Amazon.com website.

It was Chrismas time and a colleague of mine had introduced me to Amazon Prime Video, so I decided to take a look at it. Whilst browsing the Amazon website, I noticed something out of the ordinary; the website used to display the user's fullname in the top-left corner of the page, but this time only the first name was showing. 

The fact only the first name was showing got me curious, so I decided to review the source code of the page looking for the pattern **Taha**. It turns out this was reflected several times in different contexts. 

The one that caught my eye was the following:

```javascript
window.$Nav && $Nav.declare('config.customerName', 'Taha');
```

The user's first name was being reflected inside a JavaScript context here! At this point, I'm pretty sure we all have the same idea in mind; close off the string and inject our code!

The way I see it is we have two options for a payload here:

* `');alert(0);void('`
or
* `'-alert(0)-'`

The last payload wins in this case for the following reasons:
* Only 12 characters long
* Cleaner syntax

On pasting this into the first name field and viewing any page under my account, the XSS payload would execute:

![POC Picture](/images/self-xss-amazon/reflected-js-context.png)

{{< youtube kAn4-8Ompro >}}

Please note that this is known as self-XSS, as you can only inject youself and can't harm anyone else with this unless chaining it with another vulnerablity such as an inconsistent access controls. 

Since Amazon does not have a bug bounty program, testing their services would be illegal, so no further tests were made to escalate this issue.

This is issue afftected the desktop version of the main Amazon.com website only. Other Amazon products were not affected.

Timeline:

* 21/12/2019: Reported to Amazon
* 23/12/2019: Acknowleged by Amazon Security Team
* 20/01/2020: Resolved by Amazon
* 15/03/2020: Asked Amazon for updates
* 31/03/2020: Public disclosure

Thank you for reading.





