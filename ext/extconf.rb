#  Copyright 2020-2021 Couchbase, Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

require "mkmf"
require "tempfile"

lib = File.expand_path("../lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "couchbase/version"

SDK_VERSION = Couchbase::VERSION[:sdk]

cmake = find_executable("cmake")
cmake = find_executable("cmake3") if `#{cmake} --version`[/cmake version (\d+\.\d+)/, 1].to_f < 3.15
abort "ERROR: CMake is required to build couchbase extension." unless cmake
puts "-- #{`#{cmake} --version`.split("\n").first}"

def sys(*cmd)
  puts "-- #{Dir.pwd}"
  puts "-- #{cmd.join(' ')}"
  system(*cmd)
end

build_type = ENV["DEBUG"] ? "Debug" : "RelWithDebInfo"
cmake_flags = %W[
  -DCMAKE_BUILD_TYPE=#{build_type}
  -DRUBY_HDR_DIR=#{RbConfig::CONFIG['rubyhdrdir']}
  -DRUBY_ARCH_HDR_DIR=#{RbConfig::CONFIG['rubyarchhdrdir']}
  -DCOUCHBASE_CXX_CLIENT_BUILD_TESTS=OFF
]

revisions_path = File.join(__dir__, "revisions.rb")
eval(File.read(revisions_path)) if File.exist?(revisions_path) # rubocop:disable Security/Eval

cmake_flags << "-DCMAKE_C_COMPILER=#{ENV['CB_CC']}" if ENV["CB_CC"]
cmake_flags << "-DCMAKE_CXX_COMPILER=#{ENV['CB_CXX']}" if ENV["CB_CXX"]
cmake_flags << "-DCOUCHBASE_CXX_CLIENT_STATIC_STDLIB=ON" << "-DCOUCHBASE_CXX_CLIENT_STATIC_OPENSSL=ON" if ENV["CB_STATIC"]
cmake_flags << "-DENABLE_SANITIZER_ADDRESS=ON" if ENV["CB_ASAN"]
cmake_flags << "-DENABLE_SANITIZER_LEAK=ON" if ENV["CB_LSAN"]
cmake_flags << "-DENABLE_SANITIZER_MEMORY=ON" if ENV["CB_MSAN"]
cmake_flags << "-DENABLE_SANITIZER_THREAD=ON" if ENV["CB_TSAN"]
cmake_flags << "-DENABLE_SANITIZER_UNDEFINED_BEHAVIOUR=ON" if ENV["CB_UBSAN"]

case RbConfig::CONFIG["target_os"]
when /darwin/
  openssl_root = `brew --prefix openssl@1.1 2> /dev/null`.strip
  openssl_root = `brew --prefix openssl@3 2> /dev/null`.strip if openssl_root.empty?
  cmake_flags << "-DOPENSSL_ROOT_DIR=#{openssl_root}" unless openssl_root.empty?
when /linux/
  openssl_root = ["/usr/lib64/openssl11", "/usr/include/openssl11"]
  cmake_flags << "-DOPENSSL_ROOT_DIR=#{openssl_root.join(';')}" if openssl_root.all? { |path| File.directory?(path) }
end

project_path = File.expand_path(File.join(__dir__))
build_dir = ENV['CB_EXT_BUILD_DIR'] ||
            File.join(Dir.tmpdir, "cb-#{build_type}-#{RUBY_VERSION}-#{RUBY_PATCHLEVEL}-#{RUBY_PLATFORM}-#{SDK_VERSION}")
FileUtils.rm_rf(build_dir, verbose: true) unless ENV['CB_PRESERVE_BUILD_DIR']
FileUtils.mkdir_p(build_dir, verbose: true)
Dir.chdir(build_dir) do
  puts "-- build #{build_type} extension #{SDK_VERSION} for ruby #{RUBY_VERSION}-#{RUBY_PATCHLEVEL}-#{RUBY_PLATFORM}"
  sys(cmake, *cmake_flags, "-B#{build_dir}", "-S#{project_path}")
  number_of_jobs = (ENV["CB_NUMBER_OF_JOBS"] || 4).to_s
  sys(cmake, "--build", build_dir, "--parallel", number_of_jobs,  "--verbose")
end
extension_name = "libcouchbase.#{RbConfig::CONFIG['SOEXT'] || RbConfig::CONFIG['DLEXT']}"
extension_path = File.expand_path(File.join(build_dir, extension_name))
abort "ERROR: failed to build extension in #{extension_path}" unless File.file?(extension_path)
extension_name.gsub!(/\.dylib/, '.bundle')
install_path = File.expand_path(File.join(__dir__, "..", "lib", "couchbase", extension_name))
puts "-- copy extension to #{install_path}"
FileUtils.cp(extension_path, install_path, verbose: true)
ext_directory = File.expand_path(__dir__)
create_makefile("libcouchbase")
if ENV["CB_REMOVE_EXT_DIRECTORY"]
  puts "-- CB_REMOVE_EXT_DIRECTORY is set, remove #{ext_directory}"
  exceptions = %w[. .. extconf.rb]
  Dir
    .glob("#{ext_directory}/*", File::FNM_DOTMATCH)
    .reject { |path| exceptions.include?(File.basename(path)) || File.basename(path).start_with?(".gem") }
    .each do |entry|
    puts "-- remove #{entry}"
    FileUtils.rm_rf(entry, verbose: true)
  end
  File.truncate("#{ext_directory}/extconf.rb", 0)
  puts "-- truncate #{ext_directory}/extconf.rb"
end

File.write("#{ext_directory}/Makefile", <<~MAKEFILE)
  .PHONY: all clean install
  all:
  clean:
  install:
MAKEFILE
