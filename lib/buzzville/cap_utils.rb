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
	
	def ensure_link(aTo,aFrom,aDir=nil,aUserGroup=nil)
		cmd = []
		cmd << "cd #{aDir}" if aDir
		cmd << "#{sudo} rm -f #{aFrom}"
		cmd << "#{sudo} ln -sf #{aTo} #{aFrom}"
		cmd << "#{sudo} chown -h #{aUserGroup} #{aFrom}" if aUserGroup
		run cmd.join(' && ')
	end
	

	def file_exists?(path)
		begin
			run "ls #{path}"
			return true
		rescue Exception => e
			return false
		end
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
	
	# if aGroup is given, that will be the users only group
	def adduser(aNewUser,aPassword,aGroup=nil)
		run "#{sudo} adduser --gecos '' #{aGroup ? '--ingroup '+aGroup : ''} #{aNewUser}" do |ch, stream, out|
			ch.send_data aPassword+"\n" if out =~ /UNIX password:/
		end
	end
	
	def add_user_to_group(aUser,aGroup)
		run "#{sudo} usermod -a -G #{aGroup} #{aUser}"
	end

end

class CapUtilsClass
	self.extend CapUtils
end
