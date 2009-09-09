require 'yore/yore_core'

@@cap_config.load do

  namespace :bv do
		namespace :files do
	
			def cap
				@@cap_config
			end
			
			def internal_permissions
				case kind
					when 'spree' then
					
						#puts "set permissions for dirs and files"
						#run_for_all("chmod 750",app_dir,:dirs)
						#run_for_all("chmod 640",app_dir,:files)
            #
						#puts "set permissions for image dirs and files"
						#run_for_all("chmod 770","#{public_dir}/images",:dirs)
						#run_for_all("chmod 660","#{public_dir}/images",:files)

						run "#{sudo} chgrp -h #{cap.apache_user} #{cap.current_path}"  # this is to change owner of link, not target
						run "#{sudo} chown -R #{cap.user}:#{cap.apache_user} #{cap.current_path}/"	# the # is reqd to work for symlinks
						run "#{sudo} chmod -R g+w #{cap.current_path}/"									# unfortunately necessary as capistrano forgets to do this later with sudo
						run "#{sudo} chown #{cap.apache_user}:#{cap.apache_user} #{cap.current_path}/config/environment.rb"	# very important for passenger, which uses the owner of this file to run as
						run "#{sudo} touch #{cap.current_path}/log/production.log"				
						run "#{sudo} chmod 666 #{cap.current_path}/log/production.log"
					when 'rails' then
						# dfdsf
				end
			end

			task :apply_permissions do
				internal_permissions
			end

		end
	end
end
