require 'net/ftp'

this_path = File.dirname(__FILE__)
require this_path+'/misc_utils'

String.class_eval do    
  def bite!(aValue=$/,aString=self)
    if aString[0,aValue.length] == aValue
      aString[0,aValue.length] = ''
      return aString
    else
      return aString
    end
  end

  def bite(aValue=$/)
    bite!(aValue,self.clone)
  end  
end


module Net
  class FTP
		def FTP.with_connect(aHost,aUsername,aPassword,aDir=nil)
			open(aHost,aUsername,aPassword) do |f|
				f.passive = true
				f.chdir(aDir) if aDir
				yield f
			end
		end

		def self.crack_file_line(aString)
			values = aString.scan(/(.{10}).{28}(.{13})(.*)$/).flatten
			{
				:bits => values[0],
				:date => values[1],
				:name => values[2]
			}
		end

		# BEGIN BUGFIXES

    #
    # Returns the size of the given (remote) filename.
    #
    def size(filename)
      voidcmd("TYPE I")
      resp = sendcmd("SIZE " + filename)
			code = resp[0, 3]
      if code != "213" && code != "220"
	raise FTPReplyError, resp
      end
      return resp[3..-1].strip.to_i
    end

		# END BUGFIXES

		def subdirs(aPath)
			list.delete_if {|line| line[0,1]=='d'}
			return list
		end

		def files(aPath)
			list.delete_if {|line| line[0,1]!='d'}
			return list
		end

		def expand_dir(aPath,aBase=nil)
			return aPath if aPath=='/'
			return MiscUtils::path_relative?(aPath) ? File.expand_path(aPath,aBase || pwd()) : File.expand_path(aPath)
		end

		def dir_exists?(aPath)
			aPath = expand_dir(aPath)
			return true if aPath=='/'
			dirname = File.basename(aPath)
			parent = MiscUtils.path_parent(aPath)
			dirname!='' && nlst(parent).include?(dirname)
		end

		def file_exists?(aPath)
			aPath = expand_dir(aPath)
			filename = File.basename(aPath)
			parent = File.dirname(aPath)
			filename!='' && nlst(parent).include?(filename)
		end

		def filelist_recurse(aPath=nil,aResult=nil,&block)
			#puts "filelist_recurse: #{aPath.to_s}  #{aResult.inspect}"
			orig_dir = !aResult ? pwd : nil	# assigned if called at top with aResult=nil
			aResult ||= []
			aPath ||= ''
			chdir(aPath)
			list('*').each do |f| 
				is_dir = f[0,1]=='d'
				details = FTP::crack_file_line(f)
				full = File.join(aPath,details[:name])
				if !block_given? || yield(full)
					if is_dir
						filelist_recurse(full,aResult)
					else
						aResult << full
					end
				end
			end
			chdir(orig_dir) if orig_dir
			return aResult
		end

		def get_files(aRemoteDir,aLocalDir,aFiles,aOptions=nil)
			aOptions = {:overwrite => true}.merge(aOptions || {})
			aFiles.each do |r|
				relative = r.bite(MiscUtils::append_slash(aRemoteDir))
				d = File.join(aLocalDir,relative)
				puts "getting #{relative}"
				getbinaryfile(r, d) unless !aOptions[:overwrite] && File.exists?(d)
			end
		end

		def get_dir(aRemoteDir,aLocalDir,aOptions=nil,&block)
			remote_files = block_given? ? filelist_recurse(aRemoteDir,nil,&block) : filelist_recurse(aRemoteDir)
			get_files(aRemoteDir,aLocalDir,remote_files,aOptions)
		end

		def highest_existing(aPath)
			sep = MiscUtils::sniff_seperator(aPath)
			path = MiscUtils::path_parts(File.expand_path(aPath)) if aPath.is_a?(String)
			# now assume path is an Array
			depth = path.length-1
			depth.downto(0) do |i|	# from full path up to root
				curr = (path[0]=='' && i==0) ? '/' : path[0..i].join(sep)
				return curr if dir_exists?(curr)
			end
			return sep	# root
		end

		def ensure_dir(aPath,aThorough=false)
			if !aThorough
				mkdir(aPath) unless dir_exists?(aPath)
			else
				return if dir_exists?(aPath)
				path = expand_dir(aPath)
				hi_existing = highest_existing(path)
				# path to create under hi_existing
				to_create = MiscUtils::path_debase(path,hi_existing)
				parts = MiscUtils::path_parts(to_create)
				curr_path = hi_existing
				
				parts.each do |part|
					curr_path = File.join(curr_path,part)
					mkdir(curr_path)
				end
			end
		end

		def put_files(aLocalDir,aRemoteDir,aFiles,aOptions=nil)
			aOptions = {:overwrite => true}.merge(aOptions || {})

			# convert all files to relative to aLocalDir
			aFiles = aFiles.map { |f| f.bite(MiscUtils::append_slash(aLocalDir)) }.sort
			
			filelist = nil
			this_dir = last_dir = nil
			aFiles.each do |r|
				d = File.expand_path(r,aRemoteDir)
				this_dir = File.dirname(d)
				if this_dir!=last_dir
					ensure_dir(this_dir,true)
					filelist = files(this_dir) - ['.','..','.svn']
				end
				if aOptions[:overwrite] || !filelist.member?(File.basename(r))
					puts "Putting #{r}"
					putbinaryfile(File.expand_path(r,aLocalDir), d)
				else
					puts "Skipping #{relative}"
				end
				last_dir = this_dir
			end
		end

		def put_dir(aLocalDir,aRemoteDir,&block)
			local_files = block_given? ? MiscUtils::recursive_file_list(aLocalDir,true,&block) : MiscUtils::recursive_file_list(aLocalDir) 
			put_files(aLocalDir,aRemoteDir,local_files)
		end

	end
end

