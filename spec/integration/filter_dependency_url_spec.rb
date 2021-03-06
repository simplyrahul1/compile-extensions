require 'spec_helper'

describe 'filtered_dependency_url' do
  def run_filter
    Open3.capture3("#{buildpack_dir}/compile-extensions/bin/filter_dependency_url #{original_url}")
  end

  let(:buildpack_dir) { Dir.mktmpdir }

  let(:manifest) {
    <<-MANIFEST
---
url_to_dependency_map:
  -
    match: \/(ruby)-(\\d+\\.\\d+\\.\\d+).tgz
    version: $2
    name: $1
  -
    match: !ruby/regexp /\/jruby_(\\d+\\.\\d+\\.\\d+)_jdk_(\\d+\\.\\d+\\.\\d+).tgz/
    version: $1::$2
    name: jruby
  -
    match: dotnet-dev-ubuntu-x64\.(.*)\.tar\.gz
    name: dotnet
    version: $1
  -
    match: python
    name: python
    version: 2.7.11
  -
    match: go
    name: go
    version: 9.1.1

dependencies:
  -
    name: ruby
    version: 1.9.3
    uri: http://thong.co.nz/file.tgz
    cf_stacks:
      - cflinuxfs2
  -
    name: ruby
    version: 2.1.1
    uri: http://some.other.repo/ruby-two-one-one.tgz
    cf_stacks:
      - cflinuxfs2
  -
    name: jruby
    version: 1.9.3::1.7.0
    uri: http://another.repo/jruby_1.9.3_jdk_1.7.0.tgz
    cf_stacks:
      - cflinuxfs2
  -
    name: dotnet
    version: 1.0.0-preview2-003121
    cf_stacks:
      - cflinuxfs2
    uri: https://some.cdn/with?parameters=true&secondParameter=present
  -
    name: python
    version: 2.7.11
    cf_stacks:
      - cflinuxfs2
    uri: https://login:password@python-downloads.com/python-2.7.11-linux-x64.tgz
  -
    name: go
    version: 9.1.1
    cf_stacks:
      - cflinuxfs2
    uri: https://login@go.com/9.1.1-go.tar.gz
    MANIFEST
  }

  before do
    File.open(File.join(buildpack_dir, 'manifest.yml'), 'w') do |file|
      file.puts manifest
    end
    base_dir = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
    `cd #{buildpack_dir} && cp -r #{base_dir} compile-extensions`
  end

  after do
    FileUtils.remove_entry buildpack_dir
  end

  context 'with a cache' do
    context 'when the url is defined in the manifest' do
      let(:original_url) { 'http://some.repo/ruby-1.9.3.tgz' }

      before do
        `mkdir #{buildpack_dir}/dependencies`
      end

      specify do
        filtered_url, stderr, _ = run_filter

        expect(filtered_url).to eq("file://#{buildpack_dir}/dependencies/http___thong.co.nz_file.tgz\n")
      end

      context 'python 2.7.11' do
        let(:original_url) { 'https://python.com/2.7.11.tgz' }

        specify do
          filtered_url, _, _ = run_filter

          expect(filtered_url).to eq "file://#{buildpack_dir}/dependencies/https___-redacted-_-redacted-@python-downloads.com_python-2.7.11-linux-x64.tgz\n"
        end
      end

      context 'go 9.1.1' do
        let(:original_url) { 'https://go-download.com/9.1.1.tar.gz' }

        specify do
          filtered_url, _, _ = run_filter

          expect(filtered_url).to eq "file://#{buildpack_dir}/dependencies/https___-redacted-@go.com_9.1.1-go.tar.gz\n"
        end
      end
    end

    context 'when a url with parameters is defined in the manifest' do
      let(:original_url) { 'https://some.url/dotnet-dev-ubuntu-x64.1.0.0-preview2-003121.tar.gz' }

      before do
        `mkdir #{buildpack_dir}/dependencies`
      end

      specify do
        filtered_url, stderr, _ = run_filter

        expect(filtered_url).to eq("file://#{buildpack_dir}/dependencies/https___some.cdn_with_parameters=true_secondParameter=present\n")
      end
    end
  end

  context 'the url does not have matcher in the manifest' do
    let(:original_url) { 'http://i_r.not/here' }

    specify do
      filtered_url, _, status = run_filter

      expect(filtered_url).to eq ""
      expect(status).to_not be_success
    end
  end

  context 'without a cache' do
    context 'the url has a matcher in the manifest' do
      context 'ruby 1.9.3' do
        let(:original_url) { 'http://some.repo/ruby-1.9.3.tgz' }

        specify do
          filtered_url, stderr, _ = run_filter

          expect(filtered_url).to eq "http://thong.co.nz/file.tgz\n"
        end
      end

      context 'ruby 2.1.1' do
        let(:original_url) { 'https://original.com/ruby-2.1.1.tgz' }

        specify do
          filtered_url, _, _ = run_filter

          expect(filtered_url).to eq "http://some.other.repo/ruby-two-one-one.tgz\n"
        end
      end

      context 'jruby 1.9.3::1.7.0' do
        let(:original_url) { 'https://original.com/jruby_1.9.3_jdk_1.7.0.tgz' }

        specify do
          filtered_url, _, _ = run_filter

          expect(filtered_url).to eq "http://another.repo/jruby_1.9.3_jdk_1.7.0.tgz\n"
        end

        context 'dotnet 1.0.0-preview2-003121' do
          let(:original_url) { 'https://original.com/dotnet-dev-ubuntu-x64.1.0.0-preview2-003121.tar.gz' }

          specify do
            filtered_url, _, _ = run_filter

            expect(filtered_url).to eq "https://some.cdn/with?parameters=true&secondParameter=present\n"
          end
        end

        context 'python 2.7.11' do
          let(:original_url) { 'https://python.com/2.7.11.tgz' }

          specify do
            filtered_url, _, _ = run_filter

            expect(filtered_url).to eq "https://-redacted-:-redacted-@python-downloads.com/python-2.7.11-linux-x64.tgz\n"
          end
        end

        context 'go 9.1.1' do
          let(:original_url) { 'https://go-download.com/9.1.1.tar.gz' }

          specify do
            filtered_url, _, _ = run_filter

            expect(filtered_url).to eq "https://-redacted-@go.com/9.1.1-go.tar.gz\n"
          end
        end
      end
    end
  end
end
