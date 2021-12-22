---
title: "Build an Atomic Windows Lab"
category: Security
tags: ["OSEP", "PEN300", "PEN200","OSCP", "Windows", "Privilege Escalation", "Powershell"]
date: 2021-11-25T15:32:12Z
---

I have decided to build a Windows virtual machine to run some test scenarios with the goal to automate the repetitive tasks we encounter during an engagement.  

In the nutshell we are going to build a vulnerable Non-Domain Windows machine with different escalation paths including weak configuration service and Always Install Elevated enabled with some defenses on such as Windows Defender (LOL) and Powershell restricted language to make a bit challenging, or should I say interesting.

In order to facilitate the construction and deconstruction of the environment, I have wrote the following tiny Powershell script.

https://gist.github.com/tahadraidia/23f44acaf57b7a51b095edcd1d0975e8

Note that admin rights are required obviously, also once we have executed Install-Environment(), we cannot use the script in a new created Powershell session due to the Restricted Language mode. However, we can still leverage InstallUtils and Powershell Runspace among other things to execute the script.

References:
- https://www.winhelponline.com/blog/view-edit-service-permissions-windows/
- https://www.hackingarticles.in/windows-privilege-escalation-alwaysinstallelevated/
- https://docs.microsoft.com/en-us/dotnet/framework/tools/installutil-exe-installer-tool
- https://docs.microsoft.com/en-us/powershell/scripting/developer/hosting/windows-powershell-host-quickstart?view=powershell-7.2



