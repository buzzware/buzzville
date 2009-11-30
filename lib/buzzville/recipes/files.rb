require 'yore/yore_core'

@@cap_config.load do

  namespace :bv do
		namespace :files do
	
			def cap
				@@cap_config
			end
			
			def internal_apply_deploy_permissions(aKind)
				cap.extend CapUtils
				case aKind
					when 'rails' then
						permissions_for_deploy(cap.user,cap.apache_user,cap.current_path)
						uploads = cap.shared_path+'/uploads'
						if remote_file_exists?(uploads)
							permissions_for_web(uploads,cap.user,cap.apache_user,true)
							permissions_for_web_writable(uploads) 
						end
						#uploads_path = File.expand_path('../shared/uploads',current_path)
						#mkdir_permissions(uploads_path,user,apache_user,770,true)
					when 'spree' then
						internal_apply_deploy_permissions('rails')					
					when 'browsercms' then
						internal_apply_deploy_permissions('rails')
				end
			end

			task :apply_deploy_permissions do
				internal_apply_deploy_permissions(cap.kind)
			end			
			
			def internal_permissions(aKind)
				cap.extend CapUtils
				case aKind
					when 'rails' then
						#puts "set permissions for dirs and files"
						#run_for_all("chmod 750",app_dir,:dirs)
						#run_for_all("chmod 640",app_dir,:files)
            #
						#puts "set permissions for image dirs and files"
						#run_for_all("chmod 770","#{public_dir}/images",:dirs)
						#run_for_all("chmod 660","#{public_dir}/images",:files)


						run "#{sudo} chgrp -h #{cap.apache_user} #{cap.current_path}"  # this is to change owner of link, not target

						cap.permissions_for_web(cap.current_path,cap.user,cap.apache_user,true)

						#run "#{sudo} chown -R #{cap.user}:#{cap.apache_user} #{cap.current_path}/"	# the # is reqd to work for symlinks
						#run "#{sudo} chmod -R g+w #{cap.current_path}/"									# unfortunately necessary as capistrano forgets to do this later with sudo

						uploads = cap.shared_path+'/uploads'
						if remote_file_exists?(uploads)
							permissions_for_web(uploads,cap.user,cap.apache_user,true)
							permissions_for_web_writable(uploads) 
						end
						#uploads_path = File.expand_path('../shared/uploads',current_path)
						#mkdir_permissions(uploads_path,user,apache_user,770,true)

						run "#{sudo} chown #{cap.user}:#{cap.user} #{cap.current_path}/config/environment.rb"	# very important for passenger, which uses the owner of this file to run as
						run "#{sudo} touch #{cap.current_path}/log/production.log"				
						run "#{sudo} chmod 666 #{cap.current_path}/log/production.log"

					when 'spree' then
						internal_permissions('rails')					
					when 'browsercms' then
						internal_permissions('rails')
				end
			end

			task :apply_permissions do
				internal_permissions(cap.kind)
			end

		end
	end
end
