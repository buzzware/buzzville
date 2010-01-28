@@cap_config.load do

  namespace :bv do
		namespace :ssl do
			extend CapUtils
	
			def cap
				@@cap_config
			end
	
			#task :check_key do
			#	#sudo openssl rsa -check -noout -in ~/.ssh/iarts.ppk
			#end	
	
			# should set key_dir
			task :new_key do	
				set :local_key_dir,File.expand_path('~/.ssh') unless (local_key_dir rescue false)
				if !(key_name rescue false)				
					default_key_name = (new_user rescue nil) || 'new_key'
					key_name_response = Capistrano::CLI.ui.ask("Enter a name for the key without extension (default: #{default_key_name}):").strip
					set :key_name, (key_name_response.nil? || key_name_response.empty?) ? default_key_name : key_name_response
				end
				pub = File.join(local_key_dir,key_name+'.pub')
				ppk = File.join(local_key_dir,key_name+'.ppk')
				raise StandardError.new("#{pub} or #{ppk} already exists") if File.exists?(pub) || File.exists?(ppk)
				passphrase = Capistrano::CLI.password_prompt("Enter a passphrase (>= 5 characters):")
				# create key - asks for name & passphrase and stores in ~/.ssh
				shell "ssh-keygen #{passphrase.to_s.empty? ? '' : '-N '+passphrase} -f #{File.join(local_key_dir,key_name)}"
				shell "#{sudo} mv #{File.join(local_key_dir,key_name)} #{ppk}"
				shell "#{sudo} sed -i -e 's/== .*$/== #{key_name}.pub/' #{pub}"
				shell "#{sudo} chown $USER #{pub}"
				shell "#{sudo} chown $USER #{ppk}"
				Capistrano::CLI.ui.say "created #{pub}"
				Capistrano::CLI.ui.say "created #{ppk}"
				Capistrano::CLI.ui.say "Recommended: ssh-add -k #{ppk}"
			end	
			
			task :install_key do
				set :new_user,Capistrano::CLI.ui.ask("Enter a username for installing the key :") unless (new_user rescue false)
				set :key_name,Capistrano::CLI.ui.ask("Enter a name for the key eg. user name (without extension):") unless (key_name rescue false)
				set :key_dir,"/home/#{new_user}/.ssh" unless (key_dir rescue false)
				set :local_key_dir,File.expand_path("~/.ssh") unless (local_key_dir rescue false)

				# prepare key dir for new_user
				auth_keys = File.join(key_dir,'authorized_keys')
				run "#{sudo} mkdir -p #{key_dir}"
				run "#{sudo} touch #{auth_keys}"
				run "#{sudo} chown #{new_user}:#{new_user} #{key_dir}"
				run "#{sudo} chown #{new_user}:#{new_user} #{auth_keys}"
				run "#{sudo} chmod 700 #{key_dir}"
				run "#{sudo} chmod 600 #{auth_keys}"
			
				# upload and install in authorized_keys			
				if capture("#{sudo} grep -q #{key_name}.pub #{auth_keys};echo $?")=='0'
					puts "Key already installed. Not installing"
				else
					admin_dir = "/home/#{cap.user}"
					
					run "#{sudo} rm -f #{File.join(admin_dir,key_name+'.pub')}"
					upload(File.join(local_key_dir,key_name+'.pub'),File.join(admin_dir,key_name+'.pub'),:via => :scp,:mode => 600)
					run "#{sudo} echo '' | #{sudo} tee -a #{auth_keys}"				# new line 
					run "#{sudo} cat #{File.join(admin_dir,key_name+'.pub')} | #{sudo} tee -a #{auth_keys}"
					run "#{sudo} rm #{File.join(admin_dir,key_name+'.pub')}"
					run "#{sudo} /etc/init.d/ssh restart"
				end
				
				# add to sshd_config AllowUsers if not already
				allow_users = []
				allow_str = capture("#{sudo} grep AllowUsers /etc/ssh/sshd_config")
				allow_str.each_line do |line|
					next unless line =~ /^AllowUsers /
					allow_users += line.bite('AllowUsers').split(' ')
				end
				if !allow_users.include?(new_user)
					run "#{sudo} sed -i -e 's/^AllowUsers /AllowUsers #{new_user} /' /etc/ssh/sshd_config"
				end
				
				s = <<EOS

You probably need to append :

Host #{new_user}
        IdentityFile #{File.join(local_key_dir,key_name+'.ppk')}
        User #{new_user}
        Hostname #{host}
        Port #{sessions.values.first.transport.peer[:port]}				
        TCPKeepAlive yes
        IdentitiesOnly yes
        PreferredAuthentications publickey				

to your ~/.ssh/config file

and run locally :

        ssh-add -K #{File.join(local_key_dir,key_name+'.ppk')}

and then you should be able to  :

        ssh #{new_user}
				
without entering a password and the passphrase will be in your keychain.

EOS
				Capistrano::CLI.ui.say(s)				
			end
	
		end
	end
end
