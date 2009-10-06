# Generated by jeweler
# DO NOT EDIT THIS FILE
# Instead, edit Jeweler::Tasks in Rakefile, and run `rake gemspec`
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{buzzville}
  s.version = "0.1.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["buzzware"]
  s.date = %q{2009-10-06}
  s.description = %q{Capistrano recipes and ruby code relating to deployment}
  s.email = %q{contact@buzzware.com.au}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "buzzville.vpj",
     "buzzville.vpw",
     "lib/buzzville.rb",
     "lib/buzzville/cap_utils.rb",
     "lib/buzzville/ftp_extra.rb",
     "lib/buzzville/recipes.rb",
     "lib/buzzville/recipes/data.rb",
     "lib/buzzville/recipes/files.rb",
     "lib/buzzville/recipes/ssl.rb",
     "lib/buzzville/recipes/user.rb",
     "lib/buzzville_dev.rb",
     "test/buzzville_test.rb",
     "test/test_helper.rb"
  ]
  s.homepage = %q{http://github.com/buzzware/buzzville}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{buzzware}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Capistrano recipes and ruby code relating to deployment}
  s.test_files = [
    "test/buzzville_test.rb",
     "test/test_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<buzzcore>, [">= 0.2.5"])
      s.add_runtime_dependency(%q<yore>, [">= 0.0.5"])
      s.add_runtime_dependency(%q<cmdparse>, [">= 2.0.2"])
      s.add_development_dependency(%q<thoughtbot-shoulda>, [">= 0"])
    else
      s.add_dependency(%q<buzzcore>, [">= 0.2.5"])
      s.add_dependency(%q<yore>, [">= 0.0.5"])
      s.add_dependency(%q<cmdparse>, [">= 2.0.2"])
      s.add_dependency(%q<thoughtbot-shoulda>, [">= 0"])
    end
  else
    s.add_dependency(%q<buzzcore>, [">= 0.2.5"])
    s.add_dependency(%q<yore>, [">= 0.0.5"])
    s.add_dependency(%q<cmdparse>, [">= 2.0.2"])
    s.add_dependency(%q<thoughtbot-shoulda>, [">= 0"])
  end
end
