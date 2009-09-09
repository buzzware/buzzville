@@cap_config.load do

  namespace :bv do
		namespace :user do
			extend CapUtils
	
			def cap
				@@cap_config
			end
	
			#sudo adduser ffff
			#sudo passwd ffff
			#sudo usermod -a -G www-data ffff
			#cd /home/ffff/
			#sudo ln -s /var/www/ffff/public public
			#sudo chown -h ffff:www-data public
			#sudo /etc/init.d/pure-ftpd restart
	
			task :create do
				set :new_user, Capistrano::CLI.ui.ask("Enter a name for the new user:") unless (self.new_user rescue false)
				password = Capistrano::CLI.password_prompt("Enter a password for the new user:") unless (self.new_password rescue false)
				set :user,admin_user				
				
				adduser(new_user,password)				
				add_user_to_group(new_user,apache_user)

				Capistrano::CLI.ui.say "please run \"sudo sudoedit /etc/sudoers\" add the following line :"
				Capistrano::CLI.ui.say "#{new_user} ALL=(ALL) ALL"
			end
	
			task :new_key do
				set :new_user, Capistrano::CLI.ui.ask("Enter the user name:") unless (self.new_user rescue false)
				set :user,admin_user
				bv.ssl.new_key
				bv.ssl.install_key	
			end
			
			task :delete do 
				set :new_user, Capistrano::CLI.ui.ask("Enter the user name:") unless (self.new_user rescue false)
				set :user,admin_user
				run "#{sudo} userdel -rf #{new_user}"
			end	
			
		end
	end
end
