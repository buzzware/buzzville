# use "extend CapUtils" inside a task to use this
require 'buzzcore/misc_utils'
require 'buzzcore/string_utils'
require 'buzzcore/xml_utils'
require 'buzzcore/shell_extras'
require 'net/ssh'
require 'net/sftp'

module CapUtils

	# upload the given local file to the remote server and set the given mode.
	# 0644 is the default mode
	#
	# Unix file modes :
	# 4: read
	# 2: write
	# 1: execute
	# 0[owner][group][other]
	def upload_file(aLocalFilePath,aRemoteFilePath,aMode = 0644)
		puts "* uploading #{aLocalFilePath} to #{aRemoteFilePath}"
		s = nil
		File.open(aLocalFilePath, "rb") { |f| s = f.read }
		put(s,aRemoteFilePath,:mode => aMode)
	end
	
	def render_template_file(aTemplateFile,aXmlConfig,aOutputFile,aMoreConfig=nil)
		template = MiscUtils.string_from_file(aTemplateFile)
		values = XmlUtils.read_config_values(aXmlConfig)
		values = values ? values.merge(aMoreConfig || {}) : aMoreConfig
		result = StringUtils.render_template(template, values)
		MiscUtils.string_to_file(result, aOutputFile)
  end

	def get_ip
		run "ifconfig eth0 |grep \"inet addr\"" do |channel,stream,data|
			return data.scan(/inet addr:([0-9.]+)/).flatten.pop
		end
	end

	# check if file exists. Relies on remote ruby
	def remote_file_exists?(aPath)
		remote_ruby("puts File.exists?('#{aPath}').to_s")=="true\n"
	end

	def remote_ruby(aRubyString)
		run 'ruby -e "'+aRubyString+'"' do |channel,stream,data|
			return data
		end
	end

	def sudo_run(aString)
# 		as = fetch(:runner, "app")
# 		via = fetch(:run_method, :sudo)
# 		invoke_command(aString, :via => via, :as => as)
# 		if aUseSudo
# 			run "sudo "+aString
# 		else
			run aString
# 		end
	end

	def upload_file_anywhere(aSourceFile,aDestHost,aDestUser,aDestPassword,aDestFile,aDestPort=22)
		Net::SSH.start(aDestHost, aDestUser, {:port => aDestPort, :password => aDestPassword, :verbose =>Logger::DEBUG}) do |ssh|
			File.open(aSourceFile, "rb") { |f| ssh.sftp.upload!(f, aDestFile) }
		end
	end

	def branch_name_from_svn_url(aURL)
		prot_domain = (aURL.scan(/[^:]+:\/\/[^\/]+\//)).first
		without_domain = aURL[prot_domain.length..-1]
		return 'trunk' if without_domain =~ /^trunk\//
		return (without_domain.scan(/branches\/(.+?)(\/|$)/)).flatten.first
	end
	
	# give block with |aText,aStream,aState| that returns response or nil
	def run_respond(aCommand)
		run(aCommand) do |ch,stream,text|
			ch[:state] ||= { :channel => ch }
			output = yield(text,stream,ch[:state])
			ch.send_data(output) if output
		end
	end

	# pass prompt to user, and return their response
	def run_prompt(aCommand)
		run_respond aCommand do |text,stream,state|
			Capistrano::CLI.password_prompt(text)+"\n"
		end
	end
	
	def ensure_link(aTo,aFrom,aDir=nil,aUserGroup=nil,aSudo='')
		cmd = []
		cmd << "cd #{aDir}" if aDir
		cmd << "#{sudo} rm -rf #{aFrom}"
		cmd << "#{sudo} ln -sf #{aTo} #{aFrom}"
		cmd << "#{sudo} chown -h #{aUserGroup} #{aFrom}" if aUserGroup
		run cmd.join(' && ')
	end
	

	def file_exists?(path)
		result = nil
		run "if [[ -e #{path} ]]; then echo 'true'; else echo 'false'; fi", :shell => false do |ch,stream,text|
			result = (text.strip! == 'true')
		end
		result
	end
	
	# Used in deployment to maintain folder contents between deployments.
	# Normally the shared path exists and will be linked into the release.
	# If it doesn't exist and the release path does, it will be moved into the shared path
	# aFolder eg. "vendor/extensions/design"
	# aSharedFolder eg. "design" 
	def preserve_folder(aReleaseFolder,aSharedFolder)	
		aReleaseFolder = File.join(release_path,aReleaseFolder)
		aSharedFolder = File.join(shared_path,aSharedFolder)
		release_exists = file_exists?(aReleaseFolder)
		shared_exists = file_exists?(aSharedFolder)
		if shared_exists
			run "rm -rf #{aReleaseFolder}" if release_exists
		else
			run "mv #{aReleaseFolder} #{aSharedFolder}" if release_exists
		end
		ensure_link("#{aSharedFolder}","#{aReleaseFolder}",nil,"#{user}:#{apache_user}")
	end

	def select_target_file(aFile)
		ext = MiscUtils.file_extension(aFile,false)
		no_ext = MiscUtils.file_no_extension(aFile,false)
		dir = File.dirname(aFile)
		run "#{sudo} mv -f #{no_ext}.#{target}.#{ext} #{aFile}"
		run "#{sudo} rm -f #{no_ext}.*.#{ext}"
	end
	
	def shell(aCommandline,&aBlock)
		result = block_given? ? POpen4::shell(aCommandline,nil,nil,&aBlock) : POpen4::shell(aCommandline)
		return result[:stdout]
	end

	def run_local(aString)
		`#{aString}`
	end


	def run_for_all(aCommand,aPath,aFilesOrDirs,aPattern=nil,aInvertPattern=false,aSudo=true)
		#run "#{sudo} find . -wholename '*/.svn' -prune -o -type d -print0 |xargs -0 #{sudo} chmod 750"
		#sudo find . -type f -exec echo {} \;
		cmd = []
		cmd << "sudo" if aSudo
		cmd << "find #{aPath}"
		cmd << "-wholename '#{aPattern}'" if aPattern
		cmd << "-prune -o" if aInvertPattern
		cmd << case aFilesOrDirs.to_s[0,1]
			when 'f' then '-type f'
			when 'd' then '-type d'
			else ''
		end
		cmd << "-exec"		
		cmd << aCommand
		cmd << '{} \;'		
		cmd = cmd.join(' ')
		run cmd
	end
	
	#run_for_all("chmod g+s #{File.expand_path(dir,public_dir)}",public_dir,:dirs)
	
	def set_dir_permissions_r(aStartPath,aUser=nil,aGroup=nil,aMode=nil,aSetGroupId=false)
		cmd = []
		if aGroup
			cmd << (aUser ? "chown #{aUser}:#{aGroup}" : "chgrp #{aGroup}")
		else	
			cmd << "chown #{aUser}" if aUser
		end
		cmd << "chmod #{aMode.to_s}" if aMode
		cmd << "chmod g+s" if aSetGroupId
		cmd.each do |c|
			run_for_all(c,aStartPath,:dirs)
		end
	end

	def set_permissions_cmd(aFilepath,aUser=nil,aGroup=nil,aMode=nil,aSetGroupId=false,aSudo=true)
		cmd = []
		if aGroup
			cmd << (aUser ? "#{aSudo ? sudo : ''} chown #{aUser}:#{aGroup}" : "#{aSudo ? sudo : ''} chgrp #{aGroup}") + " #{aFilepath}"
		else	
			cmd << "#{aSudo ? sudo : ''} chown #{aUser} #{aFilepath}" if aUser
		end
		cmd << "#{aSudo ? sudo : ''} chmod #{aMode.to_s} #{aFilepath}" if aMode
		cmd << "#{aSudo ? sudo : ''} chmod g+s #{aFilepath}" if aSetGroupId
		cmd.join(' && ')
	end
	
	def set_permissions(aFilepath,aUser=nil,aGroup=nil,aMode=nil,aSetGroupId=false,aSudo=true)
		cmd = set_permissions_cmd(aFilepath,aUser,aGroup,aMode,aSetGroupId,aSudo)
		run cmd
	end

	def mkdir_permissions(aStartPath,aUser=nil,aGroup=nil,aMode=nil,aSetGroupId=false,aSudo=true)
		run "#{sudo} mkdir -p #{aStartPath}"
		set_permissions(aStartPath,aUser,aGroup,aMode,aSetGroupId,aSudo)
	end

	# if aGroup is given, that will be the users only group
	def adduser(aNewUser,aPassword,aGroup=nil)
		run "#{sudo} adduser --gecos '' #{aGroup ? '--ingroup '+aGroup : ''} #{aNewUser}" do |ch, stream, out|
			ch.send_data aPassword+"\n" if out =~ /UNIX password:/
		end
	end
	
	def add_user_to_group(aUser,aGroup)
		run "#{sudo} usermod -a -G #{aGroup} #{aUser}"
	end

	# returns 'buzzware-logikal' from 'git@git.assembla.com:buzzware/logikal.git'
	def project_name_from_git_commit_url(aGitUrl)
		parts = aGitUrl.split(/[@:\/]/)	# eg ["git", "git.assembla.com", "buzzware", "logikal.git"]
		return File.basename(parts[2..-1].join('-'),'.git')
	end
	
	# returns from git://github.com/buzzware/spree.git
	def project_name_from_git_public_url(aGitUrl)
		prot,url = aGitUrl.split(/\:\/\//)
		url_parts = url.split('/')
		host = url_parts.shift
		File.basename(url_parts.join('-'),'.git')
	end

	def update_remote_git_cache(aGitUrl,aBranchOrTag=nil)
		proj = project_name_from_git_public_url(aGitUrl)
		cache_path = File.join(shared_path,'extra_cache')
		run "mkdir -p #{cache_path}"
		dest = File.join(cache_path,proj)
		revision = ''
		sub_mods = false

		run "git clone #{aGitUrl} #{dest}" if !file_exists?(dest)
		run "cd #{dest} && git checkout -f #{aBranchOrTag ? aBranchOrTag : ''} #{revision} && git reset --hard && git clean -dfqx"
		if sub_mods
			run "cd #{dest} && git submodule init && git submodule update"
		end
		return dest
	end
	
	def force_copy_mode_cmd(aFrom,aTo,aChmod=nil)
		cmd = []
		cmd << "rm -rf #{aTo}"
		cmd << "cp -f #{aFrom} #{aTo}"
		cmd << "chmod #{aChmod.to_s} #{aTo}" if aChmod
		cmd.join(' && ')
	end
	
	def ensure_link_cmd(aTo,aFrom,aDir=nil,aUserGroup=nil,aSudo=nil)
		aSudo ||= ''
		cmd = []
		cmd << "cd #{aDir}" if aDir
		cmd << "#{aSudo} rm -rf #{aFrom}"
		cmd << "#{aSudo} ln -sf #{aTo} #{aFrom}"
		cmd << "#{aSudo} chown -h #{aUserGroup} #{aFrom}" if aUserGroup
		cmd.join(' && ')
	end
	
	# This means :
	# * designers can ftp in to the server and upload/edit templates
	# * templates are Rails-style eg. erb but can be whatever you have Rails handlers for
	# * templates created in the database or deployed in the app/views/layouts/templates are read only to designers, and will be replaced on restart
	# * designers can upload assets into a design folder that will be available publicly under /design
	# * designers templates and assets are not affected by redeploys

	def setup_designer_filesystem_cmd(aBrowserCmsRoot,aSharedDesignPath,aFtpPath,aUser,aApacheUser)
		
		cmd = []
		
		cmd << "mkdir -p #{aSharedDesignPath}"
		cmd << "chown #{aUser}:#{aApacheUser} #{aSharedDesignPath}"
		cmd << "chmod 750 #{aSharedDesignPath}"
		cmd << "mkdir -p #{aSharedDesignPath}/design"
		cmd << "mkdir -p #{aSharedDesignPath}/templates"
	
		# copy files from database to shared/design and make readonly
		cmd << "cp #{aBrowserCmsRoot}/tmp/views/layouts/templates/* #{aSharedDesignPath}/templates/"
		#Dir[aBrowserCmsRoot+'/tmp/views/layouts/templates/*'].each do |from|
		#	cmd << force_copy_mode_cmd(from,aSharedDesignPath+'/templates/'+File.basename(from),640)
		#end
		#convert tmp templates folder into a link to shared/design
		cmd << ensure_link_cmd(aSharedDesignPath+'/templates','templates',aBrowserCmsRoot+'/tmp/views/layouts',"#{aUser}:#{aApacheUser}")
	
		# copy files from aBrowserCmsRoot to shared/design and make readonly
		cmd << "cp #{aBrowserCmsRoot}/app/views/layouts/templates/* #{aSharedDesignPath}/templates/"
		#Dir[aBrowserCmsRoot+'/app/views/layouts/templates/*'].each do |from|
		#	cmd << force_copy_mode_cmd(from,aSharedDesignPath+'/templates/'+File.basename(from),440)
		#end
	
		# link design/public into public folder
		cmd << ensure_link_cmd(aSharedDesignPath+'/design','design',aBrowserCmsRoot+'/public',"#{aUser}:#{aApacheUser}")
	
		## link shared/design/design into ftp folder
		cmd << ensure_link_cmd(aSharedDesignPath+'/design','design',aFtpPath,"#{aUser}:#{aApacheUser}")
		## link templates into ftp folder
		cmd << ensure_link_cmd(aSharedDesignPath+'/design','templates',aFtpPath,"#{aUser}:#{aApacheUser}")
		#run "#{sudo} chgrp -h www-data #{deploy_to}/current"  # this is to change owner of link, not target
		cmd_s = cmd.join(" && ")
	end
	# actual output
	# mkdir -p /var/www/logikal.stage/shared/design && chown logikal:www-data /var/www/logikal.stage/shared/design && chmod 750 /var/www/logikal.stage/shared/design && mkdir -p /var/www/logikal.stage/shared/design/design && mkdir -p /var/www/logikal.stage/shared/design/templates && rm -rf /var/www/logikal.stage/shared/design/templates/default.html.erb && cp /var/www/logikal.stage/current/cms/tmp/views/layouts/templates/default.html.erb /var/www/logikal.stage/shared/design/templates/default.html.erb && chmod 440 /var/www/logikal.stage/shared/design/templates/default.html.erb && cd /var/www/logikal.stage/current/cms/tmp/views/layouts &&  rm -rf templates &&  ln -sf /var/www/logikal.stage/shared/design/templates templates &&  chown -h logikal:www-data templates && rm -rf /var/www/logikal.stage/shared/design/templates/experimental.html.erb && cp /var/www/logikal.stage/current/cms/app/views/layouts/templates/experimental.html.erb /var/www/logikal.stage/shared/design/templates/experimental.html.erb && chmod 440 /var/www/logikal.stage/shared/design/templates/experimental.html.erb && cd /var/www/logikal.stage/current/cms/public &&  rm -rf design &&  ln -sf /var/www/logikal.stage/shared/design/design design &&  chown -h logikal:www-data design && cd /home/logikal &&  rm -rf design &&  ln -sf /var/www/logikal.stage/shared/design/design design &&  chown -h logikal:www-data design && cd /home/logikal &&  rm -rf templates &&  ln -sf /var/www/logikal.stage/current/cms/app/views/layouts/templates templates &&  chown -h logikal:www-data templates

	def install_script_from_string(aScriptString,aFilepath)
		temp_path = File.join(deploy_to,File.basename(aFilepath))
		put(aScriptString,temp_path)
		run "#{sudo} mv #{temp_path} #{aFilepath}"
		set_permissions(aFilepath,'root',user,750,false,true)
	end

end

class CapUtilsClass
	self.extend CapUtils
end
