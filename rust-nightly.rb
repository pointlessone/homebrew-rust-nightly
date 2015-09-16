require 'formula'
require 'date'

class RustNightly < Formula
  def self.latest_rust_nightly_revision
    @latest_rust_nightly_revision ||= begin
      Date.parse(`curl --silent --HEAD 'https://static.rust-lang.org/dist/rust-nightly-x86_64-apple-darwin.tar.gz' | grep 'Last-Modified:'`.split(' ', 2).last.strip).to_s
    end
  end

  def self.sha256_checksum
    `curl --silent 'https://static.rust-lang.org/dist/rust-nightly-x86_64-apple-darwin.tar.gz.sha256'`.split.first
  end

  homepage 'http://www.rust-lang.org/'
  url "https://static.rust-lang.org/dist/rust-nightly-x86_64-apple-darwin.tar.gz"
  sha256 sha256_checksum
  head 'https://github.com/rust-lang/rust.git'
  version "1.0-#{latest_rust_nightly_revision}"

  conflicts_with 'rust', :because => 'multiple version'

  def install
    lib_path_update("rustc/bin/rustc")
    lib_path_update("rustc/bin/rustdoc")

    install_component "rustc"
    install_component "rust-docs"
    install_component "cargo"
  end

  test do
    system "#{bin}/rustc"
    system "#{bin}/rustdoc", "-h"
  end

  private

  ##
  # `prefix.install` uses mv. It doesn't mix well with pre-existing paths.
  # We have to recreate directory structure carefully first and only then
  # install files.
  def install_component(component)
    Dir.chdir component do
      dirs, files = Dir["**/*"].partition { |path| File.directory? path }

      dirs.sort.each do |path|
        unless (prefix + path).exist?
          Dir.mkdir(prefix + path, File.stat(path).mode)
        end
      end

      files.each do |file|
        dest = prefix + file
        unless dest.exist?
          # Use FileUtils.mv over File.rename to handle filesystem boundaries. If src
          # is a symlink, and its target is moved first, FileUtils.mv will fail:
          #   https://bugs.ruby-lang.org/issues/7707
          # In that case, use the system "mv" command.
          if File.symlink? file
            raise unless Kernel.system 'mv', file, dest
          else
            FileUtils.mv file, dest
          end
        end
      end
    end
  end

  def otool(path)
    lines = %x[otool -L #{path}].split(/\n/)
    lines[1..-1].map do |line|
      line.strip.gsub(/ \(compatibility version.*$/, '')
    end
  end

  def install_name_tool(path, old)
    pattern = %r(x86_64-apple-darwin/stage\d+/lib/rustlib/x86_64-apple-darwin)
    if path.match(pattern)
      new = old.gsub(pattern, prefix)
      system("install_name_tool -change '#{old}' '#{new}' '#{path}'")
    end
  end

  def lib_path_update(binary)
    otool(binary).each do |current_lib_path|
      install_name_tool(binary, current_lib_path)
    end
  end
end
