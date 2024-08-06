---
title: "Michał Bentkowski XSS Challenge"
category: Application Security
tags: ["XSS", "Javascript"]
date: 2020-05-05
---

Back in April, Michał Bentkowski posted an XSS challenge on [twitter](https://twitter.com/SecurityMB/status/1247231885996101635). So I decided to give this a try and here is my write-up about it.

The first thing that I noticed when I visited the page is that the challenge was served via GitHub Pages. From there, I knew that CSP did not apply to the challenge. 

The challenge rules were as follows:

```markdown
Please enter some HTML. It gets sanitized and inserted to a <div>.
* The task is: execute alert(1).
* The solution must work on current version of at least one major browser (Chrome/Edge, Firefox, Safari).
* If you find a solution, please DM me at Twitter: @SecurityMB.
* The challenge is based on code seen in the wild.
```

The page has a `textarea`. Typing some HTML into the input, nothing happened, or should I say nothing visible to the eye happened? Time to inspect the code.

```javascript
29  const input = document.getElementById('input');
30  const getInput = () => input.value;
31  const mainUrl = location.href.split('?')[0];
32  const iframe = document.getElementById('ifr');
33  input.value = new URL(location).searchParams.get('xss');
```

Three functions were declared along with three global variables. At line 30, `getInput` is not a variable per se but instead an arrow function, which is equivalent to the following:

```javascript
const getinput = function(){ return input.value;}
```
What the function does is basically return `input.value`. Line 33 is simply setting `input.value` to whatever the `xss` parameter is set to.
```javascript
function process() {
67        const input = getInput();
68        history.replaceState(null, null,  '?xss=' + encodeURIComponent(input));
        
69        const div = document.createElement('div');
70        div.innerHTML = sanitize(input);
71        // document.body.appendChild(div)
    }
```

This is where all the magic happens; at line 67 we assign an input variable with the returned value of the `getInput()` function, which simply retrieves the value from `textarea`. Then at line 69 we create a `div` element and at line 70 we use a `sanitize` function to sanitise the value of `textarea`, and we assign this to the `div` element through `innerHTML`. However, at line 71, we can see that the created `div` element is not added to the DOM due to the fact that the line is commented out, which explains why nothing happened when we entered some HTML into the input.

Keeping this mind, let's dive into the `sanitize` function:

```javascript
function sanitize(input) {
36        const TAG_REGEX = /<\/?(\w*)([^>]*)>/g
37        const COMMENT_REGEX = /<!--.*?-->/gmi;
38        const END_TAG_REGEX = /^<\//;
        // Taken from XSS Cheat Sheet by Portswigger
40        const FORBIDDEN_ATTRS = ["onactivate","onafterprint","onanimationcancel","onanimationend","onanimationiteration","onanimationstart","onauxclick","onbeforeactivate","onbeforecopy","onbeforecut","onbeforedeactivate","onbeforepaste","onbeforeprint","onbeforeunload","onbegin","onblur","onbounce","oncanplay","oncanplaythrough","onchange","onclick","oncontextmenu","oncopy","oncut","ondblclick","ondeactivate","ondrag","ondragend","ondragenter","ondragleave","ondragover","ondragstart","ondrop","onend","onended","onerror","onfinish","onfocus","onfocusin","onfocusout","onhashchange","oninput","oninvalid","onkeydown","onkeypress","onkeyup","onload","onloadeddata","onloadedmetadata","onloadend","onloadstart","onmessage","onmousedown","onmouseenter","onmouseleave","onmousemove","onmouseout","onmouseover","onmouseup","onpageshow","onpaste","onpause","onplay","onplaying","onpointerover","onpointerdown","onpointerenter","onpointerleave","onpointermove","onpointerout","onpointerup","onpointerrawupdate","onpopstate","onreadystatechange","onrepeat","onreset","onresize","onscroll","onsearch","onseeked","onseeking","onselect","onstart","onsubmit","ontimeupdate","ontoggle","ontouchstart","ontouchend","ontouchmove","ontransitioncancel","ontransitionend","ontransitionrun","onunhandledrejection","onunload","onvolumechange","onwaiting","onwheel"];
41        const FORBIDDEN_TAGS = ["script", "style", "noscript", "template", "svg", "math"];
        
43       let sanitized = input;
    
45        sanitized = sanitized.replace(COMMENT_REGEX, '');
46        sanitized = sanitized.replace(TAG_REGEX, (wholeTag, tagName, attributes) => {
47            tagName = tagName.toLowerCase();
            
49            if (FORBIDDEN_TAGS.includes(tagName)) return '';
            
51            if (END_TAG_REGEX.test(wholeTag)) {
52                return `</${tagName}>`;
            }
54            for (let attr of FORBIDDEN_ATTRS) {
55                attributes = attributes.replace(new RegExp(attr + '\\s*=', 'gi'), '_ROBUST_XSS_PROTECTION_=');
            }
            
58            return `<${tagName}${attributes}>`
        });
        
        
        return sanitized;
        
    }
```

This function is quite along, but what the function does is quite simple; we start by defining three regexes to match a tag, an HTML comment and an ending tag:

```javascript
36      const TAG_REGEX = /<\/?(\w*)([^>]*)>/gmi;
37      const COMMENT_REGEX = /<!--.*?-->/gmi;
38      const END_TAG_REGEX = /^<\//;
```

Then we define an array of a disallowed attributes and tags at lines 40 and 41 so that we can loop through these, make changes if matched and finally return a sanitised version of the user input.

Looking at the `FORBIDDEN_TAGS` array, a few tags that could be used to trigger an XSS without an attribute are not in the list; however, these need to be added to the DOM to make it work and this is not our case, remember?

```javascript
72        // document.body.appendChild(div)
```

Taking another look at the `FORBIDDEN_TAGS` array, it turns out that `img` is not in the list. After inserting an image tag with invalid source attribute, an error message shows up on the console:

![img-fetch](/images/securitymb-xss/img-fetch.png)

It seems like `img` is the key to solving the challenge; however, we need to note a strange behaviour here, since we can fetch an image but can't render it even if the element is not part of the DOM.

Therefore, it would be possible to trigger an XSS by using certain attributes such as `onerror` and `onload`; however, these are listed in the `FORBIDDEN_ATTRIB` array:

```javascript
55        attributes = attributes.replace(new RegExp(attr + '\\s*=', 'gi'), '_ROBUST_XSS_PROTECTION_=');
```

Here, the matched attribute gets replaced by `_ROBUST_XSS_PROTECTION_`, which results in breaking the XSS payload. By setting a breakpoint at line 58, we can investigate the variable values inside the debugger: 

![img-fetch](/images/securitymb-xss/replaced-attrib.png){: .center-image }

Finally, after revisiting the implemented regular expressions, I found a way to fool `TAG_REGEX` by setting the `>` character as an attribute value:

![img-fetch](/images/securitymb-xss/fool-regex-tag.png){: .center-image }

This was an interesting XSS bug, since we faced some weird browser behaviour to solve the challenge, but I've had fun solving it all the same. 

![img-fetch](/images/securitymb-xss/thanks.png){: .center-image }