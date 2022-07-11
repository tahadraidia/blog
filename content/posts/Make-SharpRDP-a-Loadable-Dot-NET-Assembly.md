---
title: "Make SharpRDP a Loadable .NET Assembly"
date: 2021-11-29T07:21:19Z
categories: ["Security", "Programming"]
tags: ["OSEP", "PEN300", "Reverse Engineer", "C#", "Powershell", ".NET Assembly"]
---

SharpRDP in a neat tool when it comes to get a command execution via RDP protocol, The project is written in C# .NET, which makes perfect to leverage .NET Assembly, however, in order to load an assembly the binary needs to expose the API and in this case SharpRDP is build in away that it can only be in traditional way. 

If we look at the source code of the project on github, we can clearly see that Program class has internal attributes and the two methods have private attribute. In order to make an Assembly loadable we need to make them public. We have two options here, the first one is to clone the project make the changes and compile it or use the current binary laying around and modified it using dnSpy.

We are going to choose the second option, this more straight forward process and easier to accomplish, the source code compilation requires some more steps, this is really not appealing and to be honest, I am not feeling to open Visual Studio today.

![original-code](/images/SharpRDP/OpenedInDnSPY.PNG)

As mentioned earlier, Program class is internal and both HowTo() and Main() functions are private, we need to change all of them to public (Edit->Edit Class), also we need to keep the static part, thanks to static keyword we don't need to instantiate a new instance of the class.

![updated-code](/images/SharpRDP/ChangeProgramClass.PNG)

Now, we need to save the changes, to do so go to Save module but before saving we need to change the Machine option to AMD64.

![change-machine](/images/SharpRDP/ChangeARch2AMD64.PNG)

After this step we choose the location where to save the file and we are good to go!

![save-location](/images/SharpRDP/ChooseLocation2save.PNG)

Before going any further in the process, we first need to check that the binary works.

![save-location](/images/SharpRDP/RunIt2makeSureItStillWorks.PNG)

Amazing! the program still works as expected now it is time to write a Powershell script and load the assembly in memory.

![script-source](/images/SharpRDP/ScriptSourceCode.PNG)

The script reads the file from dist but this could be trivially changed later on if needed, the main important part is namespace and class name along with the parameters passed to Main function. What we did here is simply translate the C# code into Powershell code (Referring to args).

![running-script](/images/SharpRDP/Perfecto.png)

Perfecto! we made SharpRDP .NET Assembly loadable! This will come handy later on.

You can find the adaptation script made for the MSF script here:

https://gist.github.com/tahadraidia/aa3ad6fdccd3b785b5788af641edbbe9

References:
- https://github.com/0xthirteen/SharpRDP
- https://docs.microsoft.com/en-us/dotnet/standard/assembly/
- https://docs.microsoft.com/en-us/dotnet/api/system.reflection.assembly.load?view=net-6.0 