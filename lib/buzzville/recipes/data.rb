require 'yore/yore_core'

@@cap_config.load do
	# cap stage -Dapp=spree yore:pull:p_to_d
	# cap stage -Dapp=spree yore:push:d_to_p
	# cap stage -Dapp=spree yore:save:p
	# cap stage -Dapp=spree -Darchive=spree.tgz yore:load:p
	#desc <<-DESC
	#	Save
	#DESC

  namespace :bv do
		namespace :data do
	
			def cap
				@@cap_config
			end
	
			def pull_internal(aRemoteEnv,aLocalEnv)
				remote_app_path = ''
				local_app_path = ''
				remote_file = 'blah'
				local_file = 'something'
				# assume yore installed remotely
				cmd = "cd #{remote_app_path}; yore save"
				cmd += " --kind=#{kind}" if kind
				cmd += " --RAILS_ENV=#{aRemoteEnv} #{remote_file}"
				run cmd
				download(remote_file,local_file,:via => :scp)			
				local_yore = YoreCore::Yore.launch(nil,{:kind => kind,:RAILS_ENV => aLocalEnv,:basepath=>ENV['PWD']})
				local_yore.load(local_file)
			end
			
			def push_internal(aLocalEnv,aRemoteEnv)
				local_yore = YoreCore::Yore.launch(nil,{:kind => kind,:RAILS_ENV => aLocalEnv,:basepath=>ENV['PWD']})
				remote_app_path = File.join(cap.deploy_to,'current')
				local_app_path = local_yore.config[:basepath]
				filename = cap.unique_app_name+"-"+Time.now.strftime('%Y%m%d-%H%M%S')
				remote_file = File.join("/tmp",filename)
				local_file = File.join("/tmp",filename) 
				local_yore.save(local_file)
				upload(local_file,remote_file,:via => :scp)
	
				run "echo $PATH"
				# assume yore installed remotely
				cmd = "cd #{remote_app_path}; yore load"
				cmd += " --kind=#{kind}" if kind
				cmd += " --RAILS_ENV=#{aRemoteEnv} #{remote_file}"
				run cmd
			end
	
			namespace :pull do
				task :p2d  do
					pull_internal('production','development')
				end
				task :p2p  do
				end
			end
			namespace :push do
				task :d2p  do
					push_internal('development','production')
					files.apply_permissions
					deploy.restart
				end
				task :p2p  do
				end
			end
			#namespace :load do
			#	task :p  do
			#	end
			#end
			#namespace :save do
			#	task :p  do
			#	end
			#end
		end
	end
end
